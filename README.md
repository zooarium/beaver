# beaver

Scaffold tool for Go microservices in the zooarium ecosystem. Generates a full service skeleton or adds a new entity to an existing service.

## What it generates

**`new-service`** — creates a complete Go microservice with:
- Chi router, JWT auth (via `keeper`), CORS, rate limiting (100 req/min per IP)
- Ent ORM + SQLite + Atlas migrations
- Swagger docs (swag)
- Docker + docker-compose
- Structured logging via `log/slog`
- Viper config (YAML + env var override)

**`new-entity`** — adds a domain entity with full CRUD:
- `internal/<entity>/handler.go` — HTTP handler (chi routes, Swagger annotations)
- `internal/<entity>/service.go` — business logic + validation
- `internal/<entity>/repository.go` — Ent queries
- `internal/<entity>/model.go` — request/response types
- `ent/schema/<entity>.go` — Ent schema with table annotation

## Usage

```bash
# Create a new service
./scaffold.sh new-service <name> <prefix> <port>
./scaffold.sh new-service ferret frt 8082

# Add an entity to an existing service
./scaffold.sh new-entity <service-dir> <entity> <entity-plural>
./scaffold.sh new-entity ../ferret product products
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
cd <service-dir>
make vendor                          # download deps
./beaver/scaffold.sh new-entity . <entity> <entity-plural>
# add fields to ent/schema/<entity>.go
make generate                        # generate ent code
make migrate-gen name=initial_schema # create migration
make migrate-apply                   # apply migration
make swag                            # generate swagger docs
make build && make up                # build + start
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
| `make build`     | Build Docker image                   |
| `make up`        | Start containers                     |
| `make down`      | Stop containers                      |
| `make refresh`   | Rebuild and restart                  |
| `make vendor`    | Tidy + vendor dependencies           |
| `make generate`  | Run `go generate` (Ent codegen)      |
| `make fmt`       | Format with goimports (run after any change) |
| `make test`      | Run tests                            |
| `make swag`      | Regenerate Swagger docs              |
| `make migrate-gen name=<desc>` | Create migration      |
| `make migrate-apply` | Apply pending migrations         |
| `make lint`      | Run golangci-lint                    |
| `make coverage`  | Generate coverage report             |
| `make sql query="..."` | Run SQL against SQLite DB      |
| `make go-upgrade version=1.x` | Upgrade Go version      |

## Dependencies

Generated services depend on `keeper` (shared auth/JWT) via local `replace` directive in `go.mod`:

```
replace keeper => ../keeper
```

`keeper` must exist as a sibling directory.
