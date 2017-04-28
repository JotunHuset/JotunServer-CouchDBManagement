# JotunServer-CouchDBManagement

Little framework that allows to simplify CouchDB connector usage.

## Example
Actually this framework only hides some code boilplate of database initialization.
Usual usage is like this:
```swift
import JotunServerCouchDBManagement
import CouchDB

struct SomeTestPersistor {
    private let designName = "sometest_design"
    private let storeManager: CouchDbStoreManager
    
    private let allDocuments = CouchDbStoreManager.View(
        name: "all_documents", mapFunction: "function(doc.id) { emit(doc.id, [doc]) }")

    public init(connectionProperties: ConnectionProperties) {
        let parameters = CouchDbStoreManager.Parameters(databaseName: "sometest", designName: self.designName,
                                                        views: [self.allDocuments], connectionProperties: connectionProperties)
        self.storeManager = CouchDbStoreManager(parameters: parameters)
    }
    
    public func fetchAllDocuments() {
        let database = self.storeManager.database()
        database.queryByView(self.allDocuments.name, ofDesign: self.designName, usingParameters: []) {
            (document, error) in
            // Results are here.
        }
    }
}
```


# License

This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE).
