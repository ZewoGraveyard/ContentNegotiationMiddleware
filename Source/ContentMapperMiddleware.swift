// ContentMapperMiddleware.swift
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

extension StructuredDataInitializable {
    public static var key: String {
        return String(reflecting: self)
    }
}

public struct ContentMapperMiddleware: Middleware {
    let type: StructuredDataInitializable.Type

    public init(mappingTo type: StructuredDataInitializable.Type) {
        self.type = type
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard let content = request.content else {
            return try next.respond(to: request)
        }

        var request = request

        do {
            let target = try type.init(structuredData: content)
            request.storage[type.key] = target
        } catch StructuredDataError.incompatibleType {
            return Response(status: .badRequest)
        } catch {
            throw error
        }

        return try next.respond(to: request)
    }
}

