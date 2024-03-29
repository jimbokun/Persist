import XCTest
import SQLite
@testable import Persist

final class PersistTests: XCTestCase {
    var persister: Persister!
    let formatter = DateFormatter()
    
    override func setUp() {
        super.setUp()
        persister = try? buildPersister()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
    }
    
    func buildPersister() throws -> Persister {
        let db: Connection = try Connection()
        let sqlitePersister = SQLitePersister(db: db)
        try sqlitePersister.createTables()
        return sqlitePersister
    }

    func testSaveBudgetItems() throws {
        var item1 = BudgetItem(label: "budget item test", budgeted: 1.5)
        var item2 = BudgetItem(label: "budget item test2", budgeted: 2.1)
        
        try persister.save(object: &item1)
        try persister.save(object: &item2)

        let retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 2)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test2" && item.budgeted == 2.1}))
    }
    
    func testUpdateBudgetItem() throws {
        var item1 = BudgetItem(label: "budget item test", budgeted: 1.5)
        
        try persister.save(object: &item1)

        var retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 1)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        
        item1 = retrievedItems[0]
        item1.budgeted = 1.6
        try persister.save(object: &item1)
        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        
        XCTAssertEqual(retrievedItems.count, 1)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.6}))
        
        let retrievedItem = try persister.retrieveById(type: BudgetItem.self, itemId: item1.id)

        XCTAssertNotNil(retrievedItem)
        XCTAssertTrue(retrievedItem?.label == "budget item test" && retrievedItem?.budgeted == 1.6)
    }
    
    func testSaveRelatedItems() throws {
        var item1 = BudgetItem(label: "budget item test", budgeted: 1.5)
        var item2 = BudgetItem(label: "budget item test2", budgeted: 2.1)
        let formatter = DateFormatter()
        
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"

        let budgetDate: Date? = formatter.date(from: "2020-04-14 01:40:59 +0000")
        var budget = Budget(date: budgetDate!, amount: 3.6)
        
        try persister.save(object: &item1)
        try persister.save(object: &item2)
        try persister.save(object: &budget)
        budget.items = [item1, item2]
        try persister.save(object: &budget)
        
        let retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 2)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test2" && item.budgeted == 2.1}))

        var budgets: [Budget] = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 1)
        XCTAssertTrue(budgets.contains(where: { b in
            b.amount == 3.6 && b.date == budgetDate && b.items.count == 2 }))
        
        let undoOp = persister.undo()
        XCTAssert(undoOp != nil)
        if let op = undoOp {
            XCTAssertEqual(op.opType, .update)
        }
        budgets = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 1)
        XCTAssertTrue(budgets.contains(where: { b in
            b.amount == 3.6 && b.date == budgetDate && b.items.count == 0 }))
        
        let redoOp = persister.redo()
        XCTAssert(redoOp != nil)
        if let op = redoOp {
            XCTAssertEqual(op.opType, .update)
        }
        budgets = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 1)
        XCTAssertTrue(budgets.contains(where: { b in
            b.amount == 3.6 && b.date == budgetDate && b.items.count == 2 }))
    }
    
    func testSaveAll() throws {
        let item1 = BudgetItem(label: "budget item test", budgeted: 1.5)
        let item2 = BudgetItem(label: "budget item test2", budgeted: 2.1)

        let budgetDate: Date? = formatter.date(from: "2020-04-14 01:40:59 +0000")
        var budget = Budget(date: budgetDate!, amount: 3.6)
        
        budget.items = [item1, item2]
        try persister.saveAll(object: &budget)
        
        var retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 2)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test2" && item.budgeted == 2.1}))

        var budgets: [Budget] = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 1)
        XCTAssertTrue(budgets.contains(where: { b in
            b.amount == 3.6 && b.date == budgetDate && b.items.count == 2 }))
        
        _ = persister.undo()
        
        retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 0)
        budgets = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 0)
        
        _ = persister.redo()
        
        retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 2)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test2" && item.budgeted == 2.1}))

        budgets = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 1)
        XCTAssertTrue(budgets.contains(where: { b in
            b.amount == 3.6 && b.date == budgetDate && b.items.count == 2 }))
        
        try persister.deleteAll(object: budgets[0])

        retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 0)
        budgets = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 0)
        
        _ = persister.undo()
        
        retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 2)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test2" && item.budgeted == 2.1}))

        budgets = try persister.retrieve(type: Budget.self)
        
        XCTAssertEqual(budgets.count, 1)
        XCTAssertTrue(budgets.contains(where: { b in
            b.amount == 3.6 && b.date == budgetDate && b.items.count == 2 }))

    }

    func testDeleteItem() throws {
        var item1 = BudgetItem(label: "budget item test", budgeted: 1.5)
        var item2 = BudgetItem(label: "budget item test2", budgeted: 2.1)

        try persister.save(object: &item1)
        try persister.save(object: &item2)

        var retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 2)

        let labels = persister.completions(type: BudgetItem.self, property: "label", prefix: "budget i")
        
        XCTAssertEqual(labels.count, 2)

        let emtpyLabels = persister.completions(type: BudgetItem.self, property: "label", prefix: "budget in")
        
        XCTAssertTrue(emtpyLabels.isEmpty)

        try persister.delete(object: item1)
        retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 1)
        
        let undoOp = persister.undo()
        
        XCTAssert(undoOp != nil)
        if let op = undoOp {
            XCTAssertEqual(op.opType, .create)
        }

        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        XCTAssertEqual(retrievedItems.count, 2)
        
        let redoOp = persister.redo()
        
        XCTAssert(redoOp != nil)
        if let op = redoOp {
            XCTAssertEqual(op.opType, .delete)
        }

        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        XCTAssertEqual(retrievedItems.count, 1)
    }
    
    func testToOne() throws {
        let txDate: Date = formatter.date(from: "2020-04-14 01:40:59 +0000")!
        var parent = Transaction(amount: 100, memo: "socks", checkno: "2", timestamp: txDate)
        let split1 = Transaction(amount: 60, memo: "socks", checkno: "2", timestamp: txDate)
        var split2 = Transaction(amount: 40, memo: "socks", checkno: "2", timestamp: txDate)
        let actual = ActualItem(amount: 40, memo: "socks", checkno: "2", date: txDate)
        
        split2.actual_item = actual
        parent.splits = [split1, split2]
        
        try persister.saveAll(object: &parent)
        
        let txs = try persister.retrieve(type: Transaction.self)
        
        XCTAssertEqual(txs.count, 3)
        XCTAssertTrue(txs.contains(where: { tx in
            tx.splits.count == 2 && tx.splits.contains(where: { split in
                split.actual_item != nil
            })
        }))
    }
    
    func testUndo() throws {
        var item1 = BudgetItem(label: "budget item test", budgeted: 1.5)
        
        try persister.save(object: &item1)

        var retrievedItems = try persister.retrieve(type: BudgetItem.self)

        XCTAssertEqual(retrievedItems.count, 1)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        
        item1 = retrievedItems[0]
        item1.budgeted = 1.6
        try persister.save(object: &item1)
        try persister.save(object: &item1)
        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        
        XCTAssertEqual(retrievedItems.count, 1)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.6}))
        
        let undoOp = persister.undo()
        XCTAssertTrue(undoOp != nil)
        if let op = undoOp {
            XCTAssertEqual(op.opType, .update)
        }
        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        XCTAssertEqual(retrievedItems.count, 1)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))
        
        let redoOp = persister.redo()
        XCTAssertTrue(redoOp != nil)
        if let op = redoOp {
            XCTAssertEqual(op.opType, .update)
        }
        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        XCTAssertEqual(retrievedItems.count, 1)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.6}))

        while (persister.undo() != nil) {}
        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        XCTAssert(retrievedItems.isEmpty)
        
        _ = persister.redo()
        retrievedItems = try persister.retrieve(type: BudgetItem.self)
        XCTAssertEqual(retrievedItems.count, 1)
        XCTAssertTrue(retrievedItems.contains(where: { item in
            item.label == "budget item test" && item.budgeted == 1.5}))

    }

    static var allTests = [
        ("testPersist", testSaveBudgetItems)
    ]
}
