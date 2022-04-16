# Persist - Now with Infinite Undo!

A thin wrapper on top of the excellent SQLite.swift library for persisting Swift structs to SQLite.

## Usage

```
let db: Connection = try Connection()
let persister = SQLitePersister(db: db)

try persister.createTables()

let item1 = BudgetItem(label: "budget item test", budgeted: 1.5)
let item2 = BudgetItem(label: "budget item test2", budgeted: 2.1)
let formatter = DateFormatter()

formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"

let budgetDate: Date? = formatter.date(from: "2020-04-14 01:40:59 +0000")
var budget = Budget(date: budgetDate!, amount: 3.6)

budget.items = [item1, item2]
try persister.saveAll(object: &budget)

let retrievedItems = try persister.retrieve(type: BudgetItem.self)
// retrieves two budget items
let budgets: [Budget] = try persister.retrieve(type: Budget.self)
// retrieves one Budget, with two budget items
```

See PersistTests.swift for more examples.

To save and retrieve structs using Persist, each struct must

* implement the Saveable protocol,
* include CodingKey enum defining all of its Codable properties,
* implement initialize to retrieve all related Saveable objects,
* implement saveRelated to save all related Saveable objects.
* implement deleteRelated to recursively delete all related Saveable objects when calling deleteAll (this method is optional if you don't need cascading delete).

See BudgetModel.swift for examples.

Persist now also supports unlimited undo.  After saving or deleting a struct, you can undo that action by calling undo on the
persister.
        
```
_ = persister.undo()
        
retrievedItems = try persister.retrieve(type: BudgetItem.self)
// retrieves 0 items
budgets = try persister.retrieve(type: Budget.self)
// retrieves 0 items

_ = persister.redo()
        
retrievedItems = try persister.retrieve(type: BudgetItem.self)
// contains 2 items
budgets = try persister.retrieve(type: Budget.self)
// contains 1 item
```

Persist saves the undo history in SQLite tables.  So you can run your application, quit it, and then after restarting it undo operations performed the last time the application was open.

## History

This is a port of a persistence layer I wrote for a RubyMotion budgeting application.

In the Ruby version, more of the persistence logic was implemented using reflection.  I tried to achieve the same thing in Swift, but  there are limits to Swift's reflection capabilities relative to Ruby.  For example, the Mirror API allows for reflecting over properties and reading their values, but not writing them.

The solution I ended up with was the Saveable protocol described above, which requires explicit methods for retrieving and saving related objects.

## Database Design

The SQLite database contains two tables, modeling a graph of the persisted objects.  The tables are

### by_type

The vertexes of the graph.  Allows selecting objects by their type.

|Column|Description|
|---------|-------------|
|id|uniquely identifies the object|
|type_name|the struct type|
|json|codable properties coded as JSON|

### relations

The directed edges of the graph.  Models references from one object to another.

|Column|Description|
|---------|-------------|
|from_id|identifies the referencing object|
|to_id|identifies the referenced object|
|relation|name of the property|

The following tables all relate to undo/redo functionality.

### operations

The history of operations performed.
 
|Column|Description|
|---------|-------------|
|id|uniquely identifies the operation|
|operationType|create, update or delete|
|isCurrent|true only for operation that will be undone if undo() is called|
|nextOperation|id of next operation to perform|

### by_type_history

History of changes to by_type.

|Column|Description|
|---------|-------------|
|operationId|foreign key to operations|
|byTypeId|foreign key to by_type|
|typeName|the struct type|
|beforeJson|codable properties coded as JSON before the operation|
|afterJson|codable properties coded as JSON after the operation|

### relations_history_before

State of relations before the operation.

|Column|Description|
|---------|-------------|
|id|unique identifier|
|operationId|foreign key to operations|
|from|identifies the referencing object|
|to|identifies the referenced object|
|relation|name of the property|

### relations_history_after

State of relations after the operation.

|Column|Description|
|---------|-------------|
|id|unique identifier|
|operationId|foreign key to operations|
|from|identifies the referencing object|
|to|identifies the referenced object|
|relation|name of the property|

### undo_transactions

Groups operations into transactions for undo operations.

|Column|Description|
|---------|-------------|
|id|unique identifier|
|undoOperationStart|points to first operation in the transaction|
|undoOperationEnd|points to last operation in the transaction|
|isCurrent|true only for operation that will be undone if undo() is called|
|nextUndoTransaction|points to next transaction|

## Limitations

An advantage of this design is that it doesn't require explicitly modeling the data schema in SQLite.  A corresponding disadvantage is that querying, sorting, and filtering cannot be pushed to the SQLite database.  So all of that functionality must be implemented in memory at the application level.

In practice, this means Persist is best suited to applications where the entire application state can be loaded into memory.

