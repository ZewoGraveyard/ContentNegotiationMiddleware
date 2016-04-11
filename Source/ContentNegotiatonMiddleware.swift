// ContentNegotiatonMiddleware.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import HTTP

public typealias Content = InterchangeData
public typealias ContentParser = InterchangeDataParser
public typealias ContentSerializer = InterchangeDataSerializer

public struct ContentNegotiationMiddleware: Middleware {
    public let mediaTypes: [MediaType]
    public let mode: Mode

    public enum Mode {
        case server
        case client
    }

    public enum Error: ErrorProtocol {
        case noSuitableParser
        case noSuitableSerializer
        case mediaTypeNotFound
    }

    public init(mediaTypes: [MediaType], mode: Mode = .server) {
        self.mediaTypes = mediaTypes
        self.mode = mode
    }

    public func parsersFor(mediaType: MediaType) -> [(MediaType, ContentParser)] {
        return mediaTypes.reduce([]) {
            if let serializer = $1.parser where $1.matches(mediaType) {
                return $0 + [($1, serializer)]
            } else {
                return $0
            }
        }
    }

    public func parse(data: Data, mediaType: MediaType) throws -> (MediaType, Content) {
        var lastError: ErrorProtocol?

        for (mediaType, parser) in parsersFor(mediaType) {
            do {
                return try (mediaType, parser.parse(data))
            } catch {
                lastError = error
                continue
            }
        }

        if let lastError = lastError {
            throw lastError
        } else {
            throw Error.noSuitableParser
        }
    }

    func serializersFor(mediaType: MediaType) -> [(MediaType, ContentSerializer)] {
        return mediaTypes.reduce([]) {
            if let serializer = $1.serializer where $1.matches(mediaType) {
                return $0 + [($1, serializer)]
            } else {
                return $0
            }
        }
    }

    public func serialize(content: Content) throws -> (MediaType, Data) {
        return try serialize(content, mediaTypes: mediaTypes)
    }

    func serialize(content: Content, mediaTypes: [MediaType]) throws -> (MediaType, Data) {
        var lastError: ErrorProtocol?

        for acceptedType in mediaTypes {
            for (mediaType, serializer) in serializersFor(acceptedType) {
                do {
                    return try (mediaType, serializer.serialize(content))
                } catch {
                    lastError = error
                    continue
                }
            }
        }

        if let lastError = lastError {
            throw lastError
        } else {
            throw Error.noSuitableSerializer
        }
    }

    public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        switch mode {
        case .server:
            return try respondServer(request, chain: chain)
        case .client:
            return try respondClient(request, chain: chain)
        }
    }

    public func respondServer(request: Request, chain: Responder) throws -> Response {
        var request = request

        let body = try request.body.becomeBuffer()

        if let contentType = request.contentType {
            do {
                let (_, content) = try parse(body, mediaType: contentType)
                request.content = content
            } catch Error.noSuitableParser {
                return Response(status: .unsupportedMediaType)
            } catch {
                return Response(status: .badRequest)
            }
        }

        var response = try chain.respond(to: request)

        if let content = response.content {
            do {
                let mediaTypes = request.accept.count > 0 ? request.accept : self.mediaTypes
                let (mediaType, body) = try serialize(content, mediaTypes: mediaTypes)
                response.contentType = mediaType
                response.body = .buffer(body)
                response.contentLength = body.count
            } catch Error.noSuitableSerializer {
                return Response(status: .notAcceptable)
            } catch {
                return Response(status: .internalServerError)
            }
        }

        return response
    }

    public func respondClient(request: Request, chain: Responder) throws -> Response {
        var request = request

        request.accept = mediaTypes

        if let content = request.content {
            let (mediaType, body) = try serialize(content)
            request.contentType = mediaType
            request.body = .buffer(body)
            request.contentLength = body.count
        }

        var response = try chain.respond(to: request)

        let body = try response.body.becomeBuffer()

        if let contentType = response.contentType {
            let (_, content) = try parse(body, mediaType: contentType)
            response.content = content
        }

        return response
    }
}

public protocol ContentInitializable {
    init(content: Content) throws
}

public protocol ContentMappable: ContentInitializable {
    static var key: String { get }
}

extension ContentMappable {
    public static var key: String {
        return String(reflecting: self)
    }
}

public protocol ContentRepresentable {
    var content: Content { get }
}

extension ContentRepresentable {
    public static func toContent(convertible: Self) -> Content {
        return convertible.content
    }
}

extension Collection where Self.Iterator.Element: ContentRepresentable {
    public var contents: [Content] {
        return map(Self.Iterator.Element.toContent)
    }

    public var content: Content {
        return Content.from(contents)
    }
}

public struct ContentMapperMiddleware: Middleware {
    let type: ContentMappable.Type

    public init(mappingTo type: ContentMappable.Type) {
        self.type = type
    }

    public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        guard let content = request.content else {
            return try chain.respond(to: request)
        }

        var request = request

        do {
            let target = try type.init(content: content)
            request.storage[type.key] = target
        } catch Content.Error.incompatibleType {
            return Response(status: .badRequest)
        } catch {
            throw error
        }

        return try chain.respond(to: request)
    }
}

extension Request {
    public var content: Content? {
        get {
            return storage["content"] as? Content
        }

        set(content) {
            storage["content"] = content
        }
    }

    public init(method: Method = .get, uri: URI = URI(path: "/"), headers: Headers = [:], content: Content, upgrade: Upgrade? = nil) {
        self.init(
            method: method,
            uri: uri,
            headers: headers,
            body: [],
            upgrade: upgrade
        )

        self.content = content
    }

    public init(method: Method = .get, uri: URI = URI(path: "/"), headers: Headers = [:], content: ContentRepresentable, upgrade: Upgrade? = nil) {
        self.init(
            method: method,
            uri: uri,
            headers: headers,
            body: [],
            upgrade: upgrade
        )

        self.content = content.content
    }
}

extension Response {
    public var content: Content? {
        get {
            return storage["content"] as? Content
        }

        set(content) {
            storage["content"] = content
        }
    }

    public init(status: Status = .ok, headers: Headers = [:], content: Content, upgrade: Upgrade? = nil) {
        self.init(
            status: status,
            headers: headers,
            body: [],
            upgrade: upgrade
        )

        self.content = content
    }

    public init(status: Status = .ok, headers: Headers = [:], content: ContentRepresentable, upgrade: Upgrade? = nil) {
        self.init(
            status: status,
            headers: headers,
            body: [],
            upgrade: upgrade
        )

        self.content = content.content
    }
}