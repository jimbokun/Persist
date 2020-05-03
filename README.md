# Persist

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

See BudgetModel.swift for examples.

## History

This is a port of a persistence layer I wrote for a RubyMotion budgeting application.

In the Ruby version, much more of the persistence logic was implemented using reflection.  I tried to achieve the same thing in Swift, but found there were limits to Swift's reflection capabilities relative to Ruby.  The solution I ended up with was the Saveable protocol described above, which requires custom methods for retrieving and saving related objects.

I am curious if there is a better way to model these persistence relationships more declaratively, and eliminate the intialize and saveRelated methods.

## Database Design

The SQLite database contains two tables, modeling a graph of the persisted objects.  The tables are

### by_type

The vertexes of the graph.  Allows selecting objects by their type.  Columns:

* id: uniquely identifies the object.
* type_name: the struct type.
* json: codable properties coded as JSON

### relations

The directed edges of the graph.  Models references from one object to another.  Columns:

* from_id: identifies the referencing object
* to_id: identifies the referenced object
* relation: name of the property

## Limitations

An advantage of this model is that it doesn't require explicitly modeling the data schema in SQLite.  A corresponding disadvantage is that querying, sorting, and filtering cannot be pushed to the SQLite database.  So all of that functionality must be implemented in memory at the application level.

In practice, this means Persist is best suited to applications where the entire application state can be loaded into memory.

