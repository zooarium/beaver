# Beaver Project Guide

## Core Mandates

## Project Overview
Beaver is a scaffold tool for Go microservices in the zooarium ecosystem. Generates a full service skeleton or adds a new entity to an existing service.

## Usage

```bash
# Create a new service
make service name=<name> prefix=<prefix> port=<port>

# Add an entity to an existing service
make entity service=<service-dir> entity=<entity> [plural=<plural>]
```

## Make Targets
- `make service name=… prefix=… port=…` — scaffold a new microservice
- `make entity service=… entity=… [plural=…]` — add entity to existing service

## Architecture
Handler → Service → Repository. Generated services depend on `keeper` via local `replace` directive in `go.mod`.

## Engineering Constraints in Templates
The templates bake in engineering constraints that generated services must keep intact:
- **Pagination**: list endpoints accept `limit` (default 50, max 500) / `offset` (default 0) via `ParsePagination`, applied at the query level (`.Limit()/.Offset()`).
- **Indexes**: every entity schema declares `Indexes()` with at least `index.Fields("app_id")`.
- **Postgres-ready DB**: `internal/db` exposes `NewClient(driver, path, dsn)` switching between sqlite3 and postgres (`DATABASE.DRIVER`/`DATABASE.DSN` config).
- **Prometheus metrics**: the router registers `MetricsMiddleware` and mounts `GET /metrics` (outside JWT auth).
- **Log-level config**: `LOG.LEVEL` maps to the slog level in `cmd/api/main.go`.
- **Locking / race safety**: generated guidance (`templates/service/CLAUDE.md.tmpl`) requires race-free access to shared mutable state — `sync.RWMutex` for in-memory state, transactions/unique constraints for check-then-write DB flows — without coarse global locks or locks held across I/O.

When editing templates, preserve these constraints (and the matching guidance in `templates/service/CLAUDE.md.tmpl`).
