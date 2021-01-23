import SQLite
import Foundation

/**
 Defines methods required for a struct to be persisted.
 All "scalar" (non-Saveable) values will be automatically encoded and decoded through the Codable protocol.
 Other related objects must implement Saveable.
 */
public protocol Saveable : Codable {
    var saveState: Persister? { get set }
    /**
     Uniquely identifies this object.
     */
    var identifier: Int? { get set }
    
    /**
     Retrieve and set related Saveable objects.
     */
    mutating func initialize()
    
    /**
     Save related Saveable objects.
     */
    mutating func saveRelated(recurse: Bool) throws
}

extension Saveable {
    func related<To>(property: String, toType: To.Type) -> [To] where To: Saveable {
        (try? saveState?.related(object: self, property: property, toType: toType)) ?? []
    }
    
    func relatedItem<To>(property: String, toType: To.Type) -> To? where To: Saveable {
        return saveState?.relatedItem(object: self, property: property, toType: toType)
    }
    
    private func childWithLabel(_ property: String) -> Mirror.Child? {
        return Mirror(reflecting: self).children
            .filter({ $0.label == property })
            .first
    }
    
    func saveRelations<To>(property: String, toType: To.Type, recurse: Bool) throws where To: Saveable {
        if let child = childWithLabel(property) {
            if var items = child.value as? [To] {
                try saveState?.saveRelations(object: self, items: &items, property: property, toType: toType, recurse: recurse)
            }
        }
    }
    
    func saveRelation<To>(property: String, toType: To.Type, recurse: Bool) throws where To: Saveable {
        if let child = childWithLabel(property) {
            if let item = child.value as? To {
                var items = [item]
                try saveState?.saveRelations(object: self, items: &items, property: property, toType: toType, recurse: recurse)
            }
        }
    }
}

public enum OperationType: Value {
    public typealias Datatype = String
    
    public static let declaredDatatype = "TEXT"
    
    public static func fromDatatypeValue(_ datatypeValue: String) -> OperationType {
        switch datatypeValue {
        case "create":
            return create
        case "update":
            return update
        case "delete":
            return delete
        default:
            return create
        }
    }
    
    public var datatypeValue: String {
        String(describing: self)
    }
    
    case create
    case update
    case delete
}

public struct Operation {
    var opType: OperationType
    var id: Int
    var typeName: String
}

/**
 Defines methods for persisting and retrieving objects.
 */
public protocol Persister {
    /**
     Retrieve all objects of type T.
     */
    func retrieve<T>(type: T.Type) throws -> [T] where T: Saveable
    
    /**
     Retrieve at most limit objects of type T, starting at start.
     */
    func retrieve<T>(type: T.Type, start: Int, limit: Int) throws -> [T] where T: Saveable
    
    /**
     Retrieve objects related to object of type To, via property.
     */
    func related<From, To>(object: From, property: String, toType: To.Type) throws -> [To] where From: Saveable, To: Saveable
    
    /**
     Retrieve object related to object of type To, via property.
     */
    func relatedItem<From, To>(object: From, property: String, toType: To.Type) -> To? where From: Saveable, To: Saveable
    
    /**
     Retrieve objects related to object of type To, via property, and append to items.
     */
    func appendRelated<From, To>(object: From, items: inout [To], property: String, toType: To.Type) where From: Saveable, To: Saveable
    
    /**
     Persist object and its relationships.
     Will create and set identifier on object, if it doesn't exist.
     */
    func save<T>(object: inout T) throws where T: Saveable
    
    /**
     Persist object and its relationships, and recursively save all related Saveable objects.
     Will create and set identifier on object, if it doesn't exist.
     */
    func saveAll<T>(object: inout T) throws where T: Saveable
    
    /**
     Persist relationships between object and items via property.  If recurse is true, recursively save each item in items and all of its related objects.
     */
    func saveRelations<From, To>(object: From, items: inout [To], property: String, toType: To.Type, recurse: Bool) throws where From: Saveable, To: Saveable
    
    /**
     Delete object and its relationships to other objects.
     */
    func delete<T>(object: T) throws where T: Saveable
    
    func undo() -> Operation?
    func redo() -> Operation?
}

/**
 Implementation of Persister backed by a SQLite database.
 */
public struct SQLitePersister : Persister {
    let db: Connection
    
    let byType: Table
    let relations: Table
    let id: Expression<Int>
    let from: Expression<Int>
    let to: Expression<Int>
    let typeName: Expression<String>
    let json: Expression<String>
    let relation: Expression<String>
    
    let operations: Table
    let operationId: Expression<Int>
    let operationType: Expression<OperationType>
    let nextOperation: Expression<Int>
    let isCurrent: Expression<Bool>
    
    let byTypeHistory: Table
    let byTypeId: Expression<Int>
    let beforeJson: Expression<String>
    let afterJson: Expression<String>
    
    let relationsHistoryBefore: Table
    let relationsHistoryAfter: Table
    
    let decoder: JSONDecoder
    let encoder: JSONEncoder
    
    public init(db: Connection) {
        self.byType = Table("by_type")
        self.typeName = Expression<String>("type_name")
        self.json = Expression<String>("json")
        self.id = Expression<Int>("id")
        
        self.relations = Table("relations")
        self.from = Expression<Int>("from_id")
        self.to = Expression<Int>("to_id")
        self.relation = Expression<String>("relation")
        
        self.operations = Table("operations")
        self.operationId = Expression<Int>("operation_id")
        self.operationType = Expression<OperationType>("operation_type")
        self.nextOperation = Expression<Int>("next_operation")
        self.isCurrent = Expression<Bool>("current")
        
        self.byTypeHistory = Table("by_type_history")
        self.byTypeId = Expression<Int>("by_type_id")
        self.beforeJson = Expression<String>("before_json")
        self.afterJson = Expression<String>("after_json")
        
        self.relationsHistoryBefore = Table("relations_history_before")
        self.relationsHistoryAfter = Table("relations_history_after")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        self.encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        self.db = db
    }
    
    public init?(path dbPath: String) {
        guard let db = try? Connection(dbPath) else {
            return nil
        }
        self.init(db: db)
    }
    
    private func decodeRow<T>(_ type: T.Type, from row: Row) throws -> T where T : Saveable {
        var decoded = try decoder.decode(type, from: Data(row[json].utf8))
        decoded.identifier = row[id]
        decoded.saveState = self
        decoded.initialize()
        return decoded
    }
    
    private func retrieve<T>(query: QueryType, type: T.Type) throws -> [T] where T: Saveable {
        return try db.prepare(query).map { row in try decodeRow(type, from: row) }
    }
    
    public func retrieve<T>(type: T.Type, start: Int, limit: Int) throws -> [T] where T: Saveable {
        let query = byType.select(id, json)
            .filter(typeName == String(describing: type))
            .limit(limit, offset: start)
        return try retrieve(query: query, type: type)
    }
    
    public func retrieve<T>(type: T.Type) throws -> [T] where T: Saveable {
        let query = byType.select(id, json).filter(typeName == String(describing: type))
        return try retrieve(query: query, type: type)
    }
    
    public func related<From, To>(object: From, property: String, toType: To.Type) throws -> [To] where From: Saveable, To: Saveable {
        let query = relations
            .select(id, json)
            .join(byType, on: to == id)
            .filter(from == object.identifier! && relation == property)
        return try retrieve(query: query, type: toType)
    }
    
    public func relatedItem<From, To>(object: From, property: String, toType: To.Type) -> To? where From: Saveable, To: Saveable {
        if let items = try? related(object: object, property: property, toType: toType) {
            if items.count == 1 {
                return items[0]
            }
        }
        return nil
    }
    
    public func appendRelated<From, To>(object: From, items: inout [To], property: String, toType: To.Type) where From: Saveable, To: Saveable {
        if let relatedItems = try? related(object: object, property: property, toType: toType) {
            items.append(contentsOf: relatedItems)
        }
    }
    
    func insertUndoOperation(opType: OperationType, buildOp: (Int) throws -> ()) throws {
        let opId = try db.run(operations.insert(operationType <- opType, isCurrent <- false, nextOperation <- -1))
        let newOpId: Int = Int(truncatingIfNeeded: opId)
        try db.run(operations.filter(isCurrent).update(isCurrent <- false, nextOperation <- newOpId))
        try db.run(operations.filter(id == newOpId).update(isCurrent <- true))
        try buildOp(newOpId)
    }
    
    func saveProperties<T>(object: inout T) throws where T: Saveable {
        let encodedJson = try String(data: encoder.encode(object), encoding: .utf8)
        let objectType = String(describing: type(of: object))
        if let identifier = object.identifier {
            try insertUndoOperation(opType: .update, buildOp: { opId in
                for old in try db.prepare(byType.select(json).filter(id == identifier)) {
                    try db.run(byTypeHistory.insert(operationId <- opId,
                                                    byTypeId <- identifier,
                                                    typeName <- objectType,
                                                    beforeJson <- old[json],
                                                    afterJson <- encodedJson!))
                }
            })
            
            try db.run(byType
                        .filter(id == identifier)
                        .update(json <- encodedJson!, typeName <- objectType))
        } else {
            let lastId = try db.run(byType.insert(json <- encodedJson!, typeName <- objectType))
            object.identifier = Int(lastId)
            try insertUndoOperation(opType: .create, buildOp: { opId in
                try db.run(byTypeHistory.insert(operationId <- opId,
                                                byTypeId <- Int(lastId),
                                                typeName <- objectType,
                                                beforeJson <- "",
                                                afterJson <- encodedJson!))
            })
        }
        object.saveState = self
    }
    
    fileprivate func save<T>(object: inout T, recurse: Bool) throws where T: Saveable {
        try saveProperties(object: &object)
        try insertRelationsHistory(object, relationsHistoryBefore)
        try object.saveRelated(recurse: recurse)
        try insertRelationsHistory(object, relationsHistoryAfter)
    }
    
    public func save<T>(object: inout T) throws where T: Saveable {
        try save(object: &object, recurse: false)
    }
    
    public func saveAll<T>(object: inout T) throws where T: Saveable {
        try save(object: &object, recurse: true)
    }
    
    fileprivate func insertRelationsHistory<T>(_ object: T, _ relationsHistory: Table) throws where T: Saveable {
        let opId = try db.scalar(operations.select(id).filter(isCurrent))
        if let identifier = object.identifier {
            for row in try db.prepare(relations.filter(from == identifier || to == identifier)) {
                try db.run(relationsHistory.insert(operationId <- opId, from <- row[from], to <- row[to], relation <- row[relation]))
            }
        }
    }
    
    public func saveRelations<From, To>(object: From, items: inout [To], property: String, toType: To.Type, recurse: Bool) throws where From: Saveable, To: Saveable {
        if let identifier = object.identifier {
            try db.run(relations
                        .filter(from == identifier && relation == property)
                        .delete())
            for var item in items {
                if recurse {
                    try saveAll(object: &item)
                }
                if let toIdentifier = item.identifier {
                    try db.run(relations.insert(from <- identifier,
                                                to <- toIdentifier,
                                                relation <- property))
                }
            }
        }
    }
    
    public func delete<T>(object: T) throws where T: Saveable {
        if let identifier = object.identifier {
            try insertUndoOperation(opType: .delete, buildOp: { opId in
                for old in try db.prepare(byType.select(json, typeName).filter(id == identifier)) {
                    try db.run(byTypeHistory.insert(operationId <- opId,
                                                    typeName <- old[typeName],
                                                    byTypeId <- identifier,
                                                    afterJson <- "",
                                                    beforeJson <- old[json]))
                }
            })
            try db.run(byType.filter(id == identifier).delete())
            try db.run(relations.filter(from == identifier).delete())
            try db.run(relations.filter(to == identifier).delete())
        }
    }
    
    fileprivate func performOperation(_ opType: OperationType, _ row: Row, _ updateJson: String, _ relationsHistory: Table) throws -> Operation {
        let relationsQuery = relationsHistory
            .select(from, to, relation)
            .filter(row[operationId] == relationsHistory[operationId])
        switch opType {
        case .create:
            try db.run(byType.insert(id <- row[byTypeId], json <- updateJson, typeName <- row[typeName]))
            for row in try db.prepare(relationsQuery) {
                try db.run(relations.insert(from <- row[from], to <- row[to], relation <- row[relation]))
            }
        case .update:
            try db.run(byType.filter(id == row[byTypeId]).update(json <- updateJson))
            try db.run(relations
                        .filter(from == row[byTypeId] || to == row[byTypeId])
                        .delete())
            for row in try db.prepare(relationsQuery) {
                try db.run(relations.insert(from <- row[from], to <- row[to], relation <- row[relation]))
            }
        case .delete:
            try db.run(byType.filter(id == row[byTypeId]).delete())
            try db.run(relations.filter(from == row[byTypeId]).delete())
            try db.run(relations.filter(to == row[byTypeId]).delete())
        }
        return Operation(opType: opType, id: row[operationId], typeName: row[typeName])
    }
    
    fileprivate func toggleIsCurrent(isCurrentFilter: Expression<Bool>) throws {
        try db.run(operations
                    .filter(isCurrent)
                    .update(isCurrent <- false))
        try db.run(operations
                    .filter(isCurrentFilter)
                    .update(isCurrent <- true))
    }
    
    public func undo() -> Operation? {
        var operation: Operation?
        let byTypeQuery = operations
            .select(operationId, operationType, byTypeId, typeName, beforeJson, afterJson)
            .filter(isCurrent)
            .join(byTypeHistory, on: operations[id] == byTypeHistory[operationId])
        do {
            for row in try db.prepare(byTypeQuery) {
                let opType: OperationType
                switch row[operationType] {
                case .create:
                    opType = .delete
                case .delete:
                    opType = .create
                default:
                    opType = .update
                }
                operation = try performOperation(opType, row, row[beforeJson], relationsHistoryBefore)
                try toggleIsCurrent(isCurrentFilter: nextOperation == row[operationId])
            }
        } catch {
            return nil
        }
        return operation
    }
    
    public func redo() -> Operation? {
        var operation: Operation?
        do {
            let opId = (try db.scalar(operations.filter(isCurrent).count) > 0) ? try db.scalar(operations.select(nextOperation).filter(isCurrent)) : try db.scalar(operations.select(id).order(id).limit(1))
            let byTypeQuery = byTypeHistory
                .select(operationId, operationType, byTypeId, typeName, beforeJson, afterJson)
                .filter(operationId == opId)
                .join(operations, on: operations[id] == byTypeHistory[operationId])
            for row in try db.prepare(byTypeQuery) {
                operation = try performOperation(row[operationType], row, row[afterJson], relationsHistoryAfter)
                try toggleIsCurrent(isCurrentFilter: id == row[operationId])
            }
        } catch {
            return nil
        }
        return operation
    }
    
    func createTables() throws {
        try db.run(byType.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(typeName)
            t.column(json)
        })
        try db.run(relations.create(ifNotExists: true) { t in
            t.column(from)
            t.column(to)
            t.column(relation)
        })
        try db.run(operations.create(ifNotExists:true) { t in
            t.column(id, primaryKey: true)
            t.column(operationType)
            t.column(isCurrent)
            t.column(nextOperation)
        })
        try db.run(byTypeHistory.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(operationId)
            t.column(byTypeId)
            t.column(typeName)
            t.column(beforeJson)
            t.column(afterJson)
        })
        try db.run(relationsHistoryBefore.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(operationId)
            t.column(from)
            t.column(to)
            t.column(relation)
        })
        try db.run(relationsHistoryAfter.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(operationId)
            t.column(from)
            t.column(to)
            t.column(relation)
        })
    }
}
