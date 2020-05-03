//
//  File.swift
//
// Examples of Saveable structs.  Originally modeled for a budgeting application.
//
//  Created by James Rankin on 4/12/20.
//

import Foundation

struct Budget: Saveable {
    var saveState: Persister?
    var identifier: Int?
    
    var date: Date
    var amount: Float
    var items: [BudgetItem] = []
    
    mutating func initialize() {
        appendRelated(items: &items, property: "items", toType: BudgetItem.self)
    }

    mutating func saveRelated(recurse: Bool) throws {
        try saveRelations(items: &items, property: "items", toType: BudgetItem.self, recurse: recurse)
    }

    enum CodingKeys: CodingKey {
        case date
        case amount
    }
}


struct BudgetItem : Saveable {
    var saveState: Persister?
    var identifier: Int?

    var label: String
    var budgeted: Float
    var items: [ActualItem] = []
    
    mutating func initialize() {
        appendRelated(items: &items, property: "actual_items", toType: ActualItem.self)
    }

    mutating func saveRelated(recurse: Bool) throws {
        try saveRelations(items: &items, property: "actual_items", toType: ActualItem.self, recurse: recurse)
    }

    enum CodingKeys: CodingKey {
        case label
        case budgeted
    }
}

struct ActualItem : Saveable {
    var saveState: Persister?
    var identifier: Int?

    var amount: Float
    var memo: String
    var checkno: String?
    var date: Date

    func initialize() {
    }
    
    func saveRelated(recurse: Bool) {
    }

    enum CodingKeys: CodingKey {
        case amount
        case memo
        case checkno
        case date
    }
}

struct Transaction : Saveable {
    var saveState: Persister?
    var identifier: Int?

    var amount: Float
    var memo: String
    var checkno: Int
    var date: Date
    var actual: ActualItem?
    var splits: [Transaction] = []

    mutating func initialize() {
        actual = relatedItem(property: "actual_item", toType: ActualItem.self)
        appendRelated(items: &splits, property: "splits", toType: Transaction.self)
    }
    
    mutating func saveRelated(recurse: Bool) throws {
        try saveRelation(item: &actual, property: "actual_item", toType: ActualItem.self, recurse: recurse)
        try saveRelations(items: &splits, property: "splits", toType: Transaction.self, recurse: recurse)
    }

    enum CodingKeys: CodingKey {
        case amount
        case memo
        case checkno
        case date
    }
}
