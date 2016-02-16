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
@_exported import MediaTypeParserCollection
@_exported import MediaTypeSerializerCollection

public final class ServerContentNegotiationMiddleware: MiddlewareType {
    public let parsers: MediaTypeParserCollection
    public let serializers: MediaTypeSerializerCollection

    public init(parsers: MediaTypeParserCollection, serializers: MediaTypeSerializerCollection) {
        self.parsers = parsers
        self.serializers = serializers
    }

    public func respond(request: Request, chain: ChainType) throws -> Response {
        var request = request

        guard case .Buffer(let body) = request.body else {
            return try chain.proceed(request)
        }

        if let contentType = request.contentType {
            do {
                let (_, content) = try parsers.parse(body, mediaType: contentType)
                request.content = content
            } catch MediaTypeParserCollectionError.NoSuitableParser {
                return Response(status: .UnsupportedMediaType)
            } catch {
                return Response(status: .BadRequest)
            }
        }

        var response = try chain.proceed(request)

        if let content = response.content {
            do {
                let mediaTypes = request.accept.count > 0 ? request.accept : serializers.mediaTypes
                let (mediaType, body) = try serializers.serialize(content, mediaTypes: mediaTypes)
                response.contentType = mediaType
                response.body = .Buffer(body)
                response.contentLength = body.count
            } catch MediaTypeSerializerCollectionError.NoSuitableSerializer {
                return Response(status: .NotAcceptable)
            } catch {
                return Response(status: .InternalServerError)
            }
        }

        return response
    }
}

public final class ClientContentNegotiatonMiddleware: MiddlewareType {
    public let parsers: MediaTypeParserCollection
    public let serializers: MediaTypeSerializerCollection
    public let mediaTypes: [MediaType]

    public init(parsers: MediaTypeParserCollection, serializers: MediaTypeSerializerCollection, mediaTypes: MediaType...) {
        self.parsers = parsers
        self.serializers = serializers
        self.mediaTypes = mediaTypes
    }

    public func respond(request: Request, chain: ChainType) throws -> Response {
        var request = request

        request.accept = parsers.mediaTypes

        if let content = request.content {
            let (mediaType, body) = try serializers.serialize(content, mediaTypes: mediaTypes)
            request.contentType = mediaType
            request.body = .Buffer(body)
            request.contentLength = body.count
        }

        var response = try chain.proceed(request)

        guard case .Buffer(let body) = response.body else {
            return response
        }

        if let contentType = response.contentType {
            let (_, content) = try parsers.parse(body, mediaType: contentType)
            response.content = content
        }

        return response
    }
}

extension Request {
    public var content: InterchangeData? {
        set {
            storage["content"] = newValue
        }

        get {
            return storage["content"] as? InterchangeData ?? nil
        }
    }

    public init(method: Method, uri: URI, headers: Headers = [:], content: InterchangeData, upgrade: Upgrade? = nil) {
        self.init(
            method: method,
            uri: uri,
            headers: headers,
            body: nil,
            upgrade: upgrade
        )

        self.content = content
    }
}

extension Response {
    public var content: InterchangeData? {
        set {
            storage["content"] = newValue
        }

        get {
            return storage["content"] as? InterchangeData ?? nil
        }
    }

    public init(status: Status = .OK, headers: Headers = [:], content: InterchangeData, upgrade: Upgrade? = nil) {
        self.init(
            status: status,
            headers: headers,
            body: nil,
            upgrade: upgrade
        )

        self.content = content
    }
}