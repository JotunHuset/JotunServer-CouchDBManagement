//
//  CouchDbStoreManager.swift
//  JotunServerCouchDBManagement
//
//  Created by Sergey Krasnozhon on 4/11/17.
//  Copyright © 2017 Sergey Krasnozhon. All rights reserved.
//

import Foundation
import CouchDB
import SwiftyJSON
import LoggerAPI
import MiniPromiseKit

#if os(Linux)
    public typealias Valuetype = Any
#else
    public typealias Valuetype = AnyObject
#endif

private enum StorManagerError: Error {
    case unexpectedError
}

public struct CouchDbStoreManager {
    public struct View {
        public let name: String
        public let mapFunction: String
        public let reduceFunction: String?
        
        public init(name: String, mapFunction: String, reduceFunction: String? = nil) {
            self.name = name
            self.mapFunction = mapFunction
            self.reduceFunction = reduceFunction
        }
    }
    
    public struct Parameters {
        public let databaseName: String
        public let designName: String
        public let views: [View]
        public let connectionProperties: ConnectionProperties
        
        public init(databaseName: String, designName: String, views: [View],
                    connectionProperties: ConnectionProperties) {
            self.databaseName = databaseName
            self.designName = designName
            self.views = views
            self.connectionProperties = connectionProperties
        }
    }
    
    private let parameters: Parameters
    private let queue = DispatchQueue(label: "CouchDbStoreManager")
    
    public init(parameters: Parameters) {
        self.parameters = parameters
        self.setupDB()
    }
    
    public func database() -> Database {
        let couchDBClient = CouchDBClient(connectionProperties: self.parameters.connectionProperties)
        let database = couchDBClient.database(self.parameters.databaseName)
        return database
    }
    
    // MARK:
    private func setupDB() {
        let couchDBClient = CouchDBClient(connectionProperties: self.parameters.connectionProperties)
        firstly {
            return Promise<Void> { (fulfill, _) in self.queue.sync { fulfill() } }
            }
            .then(on: self.queue) {
                return self.promiseToCheckDatabase(forClient: couchDBClient)
            }
            .then(on: self.queue) {
                return self.promiseToCreateDatabase(forClient: couchDBClient)
            }
            .then(on: self.queue) { (database) in
                return self.promiseToInitialiseDatabase(database, withDesign: self.databaseDesign())
            }
            .catch(on: self.queue) { (error) in
                Log.error("Error: \(error)")
                fatalError()
        }
    }
    
    // MARK: Promises
    private func promiseToCheckDatabase(forClient couchDBClient: CouchDBClient) -> Promise<Void> {
        return Promise<NSError?>
            { (fulfill, _)in
                couchDBClient.dbExists(self.parameters.databaseName, callback: { (exists, error) in
                    if exists { return }
                    fulfill(error)
                })
            }
            .then(on: self.queue) { (error) -> Void in
                try self.tryError(error, withMessage: "Bad news! CouchDB not reachable")
                return
        }
    }
    
    private func promiseToCreateDatabase(forClient couchDBClient: CouchDBClient) -> Promise<Database> {
        return Promise<(NSError?, Database?)>
            { (fulfill, _) in
                couchDBClient.createDB(self.parameters.databaseName, callback: { (database, error) in
                    let result = (error, database)
                    fulfill(result)
                })
            }
            .then(on: self.queue) { (error, database) -> Database in
                try self.tryError(error, withMessage: "Bad news!  We were not able to create the database")
                guard let database = database else {
                    Log.warning("Silent DB creating occured")
                    throw StorManagerError.unexpectedError
                }
                return database
        }
    }
    
    private func promiseToInitialiseDatabase(_ database: Database, withDesign: JSON) -> Promise<Void> {
        return Promise<(JSON?, NSError?)>
            { (fulfill, reject) in
                let design = self.databaseDesign()
                database.createDesign(self.parameters.designName, document: JSON(design), callback: { (json, error) in
                    let result = (json, error)
                    fulfill(result)
                })
            }
            .then(on: self.queue) { (json, error) -> Void in
                try self.tryError(error, withMessage: "Bad news! Creating design caused a failure")
                guard let json = json else {
                    Log.warning("Silent design creating occured")
                    throw StorManagerError.unexpectedError
                }
                Log.info("Design created: \(json as JSON?)")
                return
        }
    }
    
    // MARK: Service
    private func tryError(_ error: NSError?, withMessage message: String) throws -> Void {
        Log.warning(message)
        if let error = error {
            throw error
        }
    }
    
    private func databaseDesign() -> JSON {
        let result: [String: Any]  = [
            "_id": "_design/" + self.parameters.designName,
            "views" : self.parameters.views.reduce([String: String](), { (functions, view) -> [String: Any] in
                var functions = functions
                functions[view.name] = ["map": view.mapFunction]
                if let reduceFunction = view.reduceFunction {
                    functions["reduce"] = reduceFunction
                }
                return functions
            })
        ]
        return JSON(result)
    }
}
