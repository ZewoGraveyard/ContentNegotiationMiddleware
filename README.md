# ContentNegotiationMiddleware

```
let contentNegotiation = ContentNegotiationMiddleware(mediaTypes: [JSONMediaType()])

let router = Router(middleware: contentNegotiation) { route in

    route.post("/") { request in

```
