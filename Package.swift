import PackageDescription

let package = Package(
    name: "ContentNegotiationMiddleware",
    dependencies: [
        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 7),
        .Package(url: "https://github.com/Zewo/Mapper.git", majorVersion: 0, minor: 7),
    ]
)
