import SQLite
import Foundation

/**
 Defines methods required for a struct to be persisted.
 All "scalar" (non-Saveable) values will be automatically encoded and decoded through the Codable protocol.
 Other related objects must implement Saveable.
 */
protocol Saveable : Codable {
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

/**
 Defines methods for persisting and retrieving objects.
 */
protocol Persister {
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
     Retrieve objects related to object of type To, via property.
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
}

/**
 Implementation of Persister backed by a SQLite database.
 */
struct SQLitePersister : Persister {
    let db: Connection
    
    let byType: Table
    let relations: Table
    let id: Expression<Int>
    let from: Expression<Int>
    let to: Expression<Int>
    let typeName: Expression<String>
    let json: Expression<String>
    let relation: Expression<String>

    let decoder: JSONDecoder
    let encoder: JSONEncoder
    
    init(db: Connection) {
        self.byType = Table("by_type")
        self.typeName = Expression<String>("type_name")
        self.json = Expression<String>("json")
        self.id = Expression<Int>("id")

        self.relations = Table("relations")
        self.from = Expression<Int>("from_id")
        self.to = Expression<Int>("to_id")
        self.relation = Expression<String>("relation")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)

        self.encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .formatted(formatter)

        self.db = db
    }

    init?(path dbPath: String) {
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
    
    func retrieve<T>(type: T.Type, start: Int, limit: Int) throws -> [T] where T: Saveable {
        let query = byType.select(id, json)
            .filter(typeName == String(describing: type))
            .limit(limit, offset: start)
        return try retrieve(query: query, type: type)
    }

    func retrieve<T>(type: T.Type) throws -> [T] where T: Saveable {
        let query = byType.select(id, json).filter(typeName == String(describing: type))
        return try retrieve(query: query, type: type)
    }
    
    func related<From, To>(object: From, property: String, toType: To.Type) throws -> [To] where From: Saveable, To: Saveable {
        let query = relations
            .select(id, json)
            .join(byType, on: to == id)
            .filter(from == object.identifier! && relation == property)
        return try retrieve(query: query, type: toType)
    }
    
    func relatedItem<From, To>(object: From, property: String, toType: To.Type) -> To? where From: Saveable, To: Saveable {
        if let items = try? related(object: object, property: property, toType: toType) {
            if items.count == 1 {
                return items[0]
            }
        }
        return nil
    }

    func appendRelated<From, To>(object: From, items: inout [To], property: String, toType: To.Type) where From: Saveable, To: Saveable {
        if let relatedItems = try? related(object: object, property: property, toType: toType) {
            items.append(contentsOf: relatedItems)
        }
    }
    
    func saveProperties<T>(object: inout T) throws where T: Saveable {
        let encodedJson = try String(data: encoder.encode(object), encoding: .utf8)
        let objectType = String(describing: type(of: object))
        if let identifier = object.identifier {
            try db.run(byType
                .filter(id == identifier)
                .update(json <- encodedJson!, typeName <- objectType))
        } else {
            try db.run(byType.insert(json <- encodedJson!, typeName <- objectType))
            if let lastId = try db.scalar("select last_insert_rowid()") as? Int64 {
                object.identifier = Int(lastId)
            }
        }
        object.saveState = self
    }

    func save<T>(object: inout T) throws where T: Saveable {
        try saveProperties(object: &object)
        try object.saveRelated(recurse: false)
    }
    
    func saveAll<T>(object: inout T) throws where T: Saveable {
        try saveProperties(object: &object)
        try object.saveRelated(recurse: true)
    }

    func saveRelations<From, To>(object: From, items: inout [To], property: String, toType: To.Type, recurse: Bool) throws where From: Saveable, To: Saveable {
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

    func delete<T>(object: T) throws where T: Saveable {
        if let identifier = object.identifier {
            try db.run(byType.filter(id == identifier).delete())
            try db.run(relations.filter(from == identifier).delete())
            try db.run(relations.filter(to == identifier).delete())
        }
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
    }
}
