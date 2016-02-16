import PackageDescription

let package = Package(
    name: "ContentNegotiationMiddleware",
    dependencies: [
        .Package(url: "https://github.com/Zewo/MediaTypeParserCollection.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/Zewo/MediaTypeSerializerCollection.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/Zewo/CURIParser.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/Zewo/CHTTPParser.git", majorVersion: 0, minor: 2)
    ]
)