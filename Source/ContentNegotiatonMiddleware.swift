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
@_exported import Mapper

public enum ContentNegotiationMiddlewareError: ErrorProtocol {
    case noSuitableParser
    case noSuitableSerializer
}

public struct ContentNegotiationMiddleware: Middleware {
    public let types: [MediaTypeRepresentor.Type]
    public let mode: Mode

    public var mediaTypes: [MediaType] {
        return types.map({$0.mediaType})
    }

    public enum Mode {
        case server
        case client
    }

    public init(mediaTypes: [MediaTypeRepresentor.Type], mode: Mode = .server) {
        self.types = mediaTypes
        self.mode = mode
    }

    public init(mediaTypes: MediaTypeRepresentor.Type..., mode: Mode = .server) {
        self.init(mediaTypes: mediaTypes, mode: mode)
    }

    public func parsersFor(_ mediaType: MediaType) -> [(MediaType, StructuredDataParser)] {
        var parsers: [(MediaType, StructuredDataParser)] = []

        for type in types {
            if type.mediaType.matches(other: mediaType) {
                parsers.append(type.mediaType, type.parser)
            }
        }

        return parsers
    }

    public func parse(_ data: Data, mediaType: MediaType) throws -> (MediaType, StructuredData) {
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
            throw ContentNegotiationMiddlewareError.noSuitableParser
        }
    }

    func serializersFor(_ mediaType: MediaType) -> [(MediaType, StructuredDataSerializer)] {
        var serializers: [(MediaType, StructuredDataSerializer)] = []

        for type in types {
            if type.mediaType.matches(other: mediaType) {
                serializers.append(type.mediaType, type.serializer)
            }
        }

        return serializers
    }

    public func serialize(_ content: StructuredData) throws -> (MediaType, Data) {
        return try serialize(content, mediaTypes: mediaTypes)
    }

    func serialize(_ content: StructuredData, mediaTypes: [MediaType]) throws -> (MediaType, Data) {
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
            throw ContentNegotiationMiddlewareError.noSuitableSerializer
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

    public func respondServer(_ request: Request, chain: Responder) throws -> Response {
        var request = request

        let body = try request.body.becomeBuffer()

        if let contentType = request.contentType where !body.isEmpty {
            do {
                let (_, content) = try parse(body, mediaType: contentType)
                request.content = content
            } catch ContentNegotiationMiddlewareError.noSuitableParser {
                throw ClientError.unsupportedMediaType
            }
        }

        var response = try chain.respond(to: request)

        if let content = response.content {
            do {
                let mediaTypes = request.accept.count > 0 ? request.accept : self.mediaTypes
                let (mediaType, body) = try serialize(content, mediaTypes: mediaTypes)
                response.content = nil
                response.contentType = mediaType
                response.body = .buffer(body)
                response.contentLength = body.count
            } catch ContentNegotiationMiddlewareError.noSuitableSerializer {
                throw ClientError.notAcceptable
            }
        }

        return response
    }

    public func respondClient(_ request: Request, chain: Responder) throws -> Response {
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

extension Body {
    mutating func becomeBuffer(timingOut deadline: Double = .never) throws -> Data {
        switch self {
        case .buffer(let data):
            return data
        case .receiver(let receiver):
            let data = Drain(for: receiver, timingOut: deadline).data
            self = .buffer(data)
            return data
        case .sender(let sender):
            let drain = Drain()
            try sender(drain)
            let data = drain.data

            self = .buffer(data)
            return data
        default:
            throw BodyError.inconvertibleType
        }
    }
}
