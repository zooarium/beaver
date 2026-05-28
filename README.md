# beaver

Scaffold tool for Go microservices in the zooarium ecosystem. Generates a full service skeleton or adds a new entity to an existing service.

## What it generates

**`service`** — creates a complete Go microservice with:
- Chi router, JWT auth (via `keeper`), CORS, rate limiting (100 req/min per IP)
- Ent ORM + SQLite + Atlas migrations
- Swagger docs (swag)
- Docker + docker-compose
- Structured logging via `log/slog`
- Viper config (YAML + env var override)

**`entity`** — adds a domain entity with full CRUD:
- `internal/<entity>/handler.go` — HTTP handler (chi routes, Swagger annotations)
- `internal/<entity>/service.go` — business logic + validation
- `internal/<entity>/repository.go` — Ent queries
- `internal/<entity>/model.go` — request/response types
- `ent/schema/<entity>.go` — Ent schema with table annotation

## Usage

```bash
# Create a new service
make service name=<name> prefix=<prefix> port=<port>
make service name=ferret prefix=frt port=8082

# Add an entity to an existing service (plural defaults to <entity>s)
make entity service=<service-dir> entity=<entity> [plural=<plural>]
make entity service=../ferret entity=product
make entity service=../ferret entity=category plural=categories
```

## Tokens

| Token              | Example      | Description                  |
|--------------------|--------------|------------------------------|
| `{{SERVICE}}`        | `ferret`     | service name, lowercase      |
| `{{SERVICE_PASCAL}}` | `Ferret`     | service name, PascalCase     |
| `{{SERVICE_UPPER}}`  | `FERRET`     | service name, UPPERCASE      |
| `{{SERVICE_PREFIX}}` | `frt`        | DB table prefix              |
| `{{SERVICE_PORT}}`   | `8082`       | HTTP port                    |
| `{{ENTITY}}`         | `product`    | entity name, lowercase       |
| `{{ENTITY_PASCAL}}`  | `Product`    | entity name, PascalCase      |
| `{{ENTITY_PLURAL}}`  | `products`   | entity name, plural          |

## New service workflow

```bash
# From beaver/
make service name=ferret prefix=frt port=8082

cd ../ferret && make vendor
cd ../beaver
make entity service=../ferret entity=product

# Back in the service dir:
cd ../ferret
# add fields to ent/schema/product.go
make generate
make migrate-gen name=initial_schema
make migrate-apply
make swag
make build && make up
```

## Generated service structure

```
cmd/api/main.go                 entry point
config/config.yaml              configuration
internal/<entity>/
    handler.go                  HTTP handlers + Swagger annotations
    service.go                  business logic + validation
    repository.go               Ent queries
    model.go                    request/response types
internal/platform/http/         router + middleware
internal/platform/render/       JSON response helpers
internal/db/                    SQLite client
ent/schema/                     Ent schema definitions
ent/migrate/migrations/         Atlas migration files
pkg/config/                     Viper config loader
```

## Architecture

```
Handler → Service → Repository
```

Each layer depends only on interfaces. Repository wraps Ent. Table names follow `<prefix>_<entity>` convention (e.g. `frt_product`).

## Make targets

| Target           | Description                          |
|------------------|--------------------------------------|
| `make service name=… prefix=… port=…` | Scaffold a new microservice |
| `make entity service=… entity=… [plural=…]` | Add entity to existing service |

## Dependencies

Generated services depend on `keeper` (shared auth/JWT) via local `replace` directive in `go.mod`:

```
replace keeper => ../keeper
```

`keeper` must exist as a sibling directory.
