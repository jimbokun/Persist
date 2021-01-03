//
//  File.swift
//
// Examples of Saveable structs.  Originally modeled for a budgeting application.
//
//  Created by James Rankin on 4/12/20.
//

import Foundation

public struct Budget: Saveable {    
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

public struct ActualItem : Saveable {
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

    public func initialize() {
    }
    
    public func saveRelated(recurse: Bool) {
    }

    enum CodingKeys: CodingKey {
        case amount
        case memo
        case checkno
        case date
    }
}

public struct Transaction : Saveable {
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
        case name
        case checkno
        case timestamp
    }
}
