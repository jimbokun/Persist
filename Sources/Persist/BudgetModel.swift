//
//  File.swift
//
// Examples of Saveable structs.  Originally modeled for a budgeting application.
//
//  Created by James Rankin on 4/12/20.
//

import Foundation

public struct Budget: Saveable {
    public var saveState: Persister?
    public var identifier: Int?
    
    var date: Date
    var amount: Float
    var items: [BudgetItem] = []
    
    mutating public func initialize() {
        items = related(property: "items", toType: BudgetItem.self)
    }

    mutating public func saveRelated(recurse: Bool) throws {
        try saveRelations(property: "items", toType: BudgetItem.self, recurse: recurse)
    }

    enum CodingKeys: CodingKey {
        case date
        case amount
    }
}


public struct BudgetItem : Saveable {
    public var saveState: Persister?
    public var identifier: Int?

    var label: String
    var budgeted: Float
    var actual_items: [ActualItem] = []
    
    mutating public func initialize() {
        actual_items = related(property: "actual_items", toType: ActualItem.self)
    }

    mutating public func saveRelated(recurse: Bool) throws {
        try saveRelations(property: "actual_items", toType: ActualItem.self, recurse: recurse)
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

public struct Transaction : Saveable {
    public var saveState: Persister?
    public var identifier: Int?

    var amount: Float
    var memo: String
    var checkno: Int
    var date: Date
    var actual_item: ActualItem?
    var splits: [Transaction] = []

    mutating public func initialize() {
        actual_item = relatedItem(property: "actual_item", toType: ActualItem.self)
        splits = related(property: "splits", toType: Transaction.self)
    }
    
    mutating public func saveRelated(recurse: Bool) throws {
        try saveRelation(property: "actual_item", toType: ActualItem.self, recurse: recurse)
        try saveRelations(property: "splits", toType: Transaction.self, recurse: recurse)
    }

    enum CodingKeys: CodingKey {
        case amount
        case memo
        case checkno
        case date
    }
}
