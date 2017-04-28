
import PackageDescription

let package = Package(
    name: "JotunServer-CouchDBManagement",
    targets: [
    ],
    dependencies: [
        .Package(url: "https://github.com/davidungar/miniPromiseKit",           majorVersion: 4),
        .Package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git",        majorVersion: 1),
    ]
)
