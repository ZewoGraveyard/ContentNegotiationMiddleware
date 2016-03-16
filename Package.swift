import PackageDescription

let package = Package(
    name: "ContentNegotiationMiddleware",
    dependencies: [
        .Package(url: "https://github.com/Zewo/MediaType.git", majorVersion: 0, minor: 4),
        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 4),
    ]
)
