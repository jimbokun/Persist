//
//  File.swift
//
// Examples of Saveable structs.  Originally modeled for a budgeting application.
//
//  Created by James Rankin on 4/12/20.
//

import Foundation

@available(macOS 10.15, *)
public struct Budget: Saveable, Hashable {
    
    public var id: Int {
        get { identifier ?? -1 }
    }
    
    public init(saveState: Persister? = nil, identifier: Int? = nil, date: Date, amount: Float, items: [BudgetItem] = []) {
        self.saveState = saveState
        self.identifier = identifier
        self.date = date
        self.amount = amount
        self.items = items
    }

    public var saveState: Persister?
    public var identifier: Int?
    
    public var date: Date
    public var amount: Float
    public var items: [BudgetItem] = []

    public static func == (lhs: Budget, rhs: Budget) -> Bool {
        lhs.date == rhs.date &&
            Money(amount: lhs.amount) == Money(amount: rhs.amount) &&
            lhs.items == rhs.items
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(Money(amount: amount))
        hasher.combine(date)
    }
    
    mutating public func initialize() {
        items = related(property: "items", toType: BudgetItem.self)
    }

    mutating public func saveRelated(recurse: Bool) throws {
        try saveRelations(property: "items", toType: BudgetItem.self, recurse: recurse)
    }
    
    public func deleteRelated() throws {
        try deleteRelated(related: items)
    }

    enum CodingKeys: CodingKey {
        case date
        case amount
    }
}


@available(macOS 10.15, *)
public struct BudgetItem : Saveable, Hashable {
    
    public var id: Int {
        get { identifier ?? -1 }
    }

    public init(saveState: Persister? = nil, identifier: Int? = nil, label: String, budgeted: Float, actual_items: [ActualItem] = []) {
        self.saveState = saveState
        self.identifier = identifier
        self.label = label
        self.budgeted = budgeted
        self.actual_items = actual_items
    }
    
    public var saveState: Persister?
    public var identifier: Int?

    public var label: String
    public var budgeted: Float
    public var actual_items: [ActualItem] = []

    public static func == (lhs: BudgetItem, rhs: BudgetItem) -> Bool {
        lhs.label == rhs.label &&
            Money(amount: lhs.budgeted) == Money(amount: rhs.budgeted) &&
            lhs.actual_items == rhs.actual_items
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(Money(amount: budgeted))
    }
    
    mutating public func initialize() {
        actual_items = related(property: "actual_items", toType: ActualItem.self)
    }

    mutating public func saveRelated(recurse: Bool) throws {
        try indexCompletion(property: "label")
        try saveRelations(property: "actual_items", toType: ActualItem.self, recurse: recurse)
    }

    public func deleteRelated() throws {
        try deleteRelated(related: actual_items)
    }

    enum CodingKeys: CodingKey {
        case label
        case budgeted
    }
}

@available(macOS 10.15, *)
public struct ActualItem : Saveable, Hashable {
    
    public var id: Int {
        get { identifier ?? -1 }
    }

    public init(saveState: Persister? = nil, identifier: Int? = nil, amount: Float, memo: String, checkno: String? = nil, date: Date) {
        self.saveState = saveState
        self.identifier = identifier
        self.amount = amount
        self.memo = memo
        self.checkno = checkno
        self.date = date
    }
    
    public var saveState: Persister?
    public var identifier: Int?

    public var amount: Float
    public var memo: String
    public var checkno: String?
    public var date: Date

    public static func == (lhs: ActualItem, rhs: ActualItem) -> Bool {
        lhs.date == rhs.date &&
            Money(amount: lhs.amount) == Money(amount: rhs.amount) &&
            lhs.memo == rhs.memo &&
            lhs.checkno == rhs.checkno
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(Money(amount: amount))
        hasher.combine(memo)
        hasher.combine(checkno)
    }
    
    public func initialize() {
    }

    enum CodingKeys: CodingKey {
        case amount
        case memo
        case checkno
        case date
    }
}

@available(macOS 10.15, *)
public struct Transaction : Saveable, Hashable {
    
    public var id: Int {
        get { identifier ?? -1 }
    }

    public init(saveState: Persister? = nil, identifier: Int? = nil, amount: Float, memo: String, checkno: String? = nil, timestamp: Date, actual_item: ActualItem? = nil, splits: [Transaction] = []) {
        self.saveState = saveState
        self.identifier = identifier
        self.amount = amount
        self.memo = memo
        self.checkno = checkno
        self.timestamp = timestamp
        self.actual_item = actual_item
        self.splits = splits
    }

    public var saveState: Persister?
    public var identifier: Int?

    public var amount: Float
    public var memo: String?
    public var name: String?
    public var checkno: String?
    public var timestamp: Date
    public var actual_item: ActualItem?
    public var splits: [Transaction] = []

    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        Money(amount: lhs.amount) == Money(amount: rhs.amount) &&
            lhs.memo == rhs.memo &&
            lhs.name == rhs.name &&
            lhs.timestamp == rhs.timestamp &&
            lhs.checkno == rhs.checkno
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(Money(amount: amount))
        hasher.combine(memo)
        hasher.combine(name)
        hasher.combine(timestamp)
        hasher.combine(checkno)
    }

    mutating public func initialize() {
        actual_item = relatedItem(property: "actual_item", toType: ActualItem.self)
        splits = related(property: "splits", toType: Transaction.self)
    }
    
    mutating public func saveRelated(recurse: Bool) throws {
        try saveRelation(property: "actual_item", toType: ActualItem.self, recurse: recurse)
        try saveRelations(property: "splits", toType: Transaction.self, recurse: recurse)
    }

    public func deleteRelated() throws {
        if let actual_item = actual_item {
            try deleteRelated(related: actual_item)
        }
        try deleteRelated(related: splits)
    }

    enum CodingKeys: CodingKey {
        case amount
        case memo
        case name
        case checkno
        case timestamp
    }
}

// make comparisons based on integer cents
struct Money : Hashable {
    let amount: Float

    public static func == (lhs: Money, rhs: Money) -> Bool {
        lhs.cents() == rhs.cents()
    }

    public static func == (lhs: Money, rhs: Float) -> Bool {
        lhs.cents() == Money(amount: rhs).cents()
    }

    public static func == (lhs: Float, rhs: Money) -> Bool {
        Money(amount: lhs).cents() == rhs.cents()
    }

    func cents() -> Int {
        Int(amount * 100)
    }
}
