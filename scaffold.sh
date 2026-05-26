#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Tokens:
#   {{SERVICE}}        - service name, lowercase   (e.g. ferret)
#   {{SERVICE_PASCAL}} - service name, PascalCase  (e.g. Ferret)
#   {{SERVICE_UPPER}}  - service name, UPPERCASE   (e.g. FERRET)
#   {{SERVICE_PREFIX}} - table prefix              (e.g. frt)
#   {{SERVICE_PORT}}   - HTTP port                 (e.g. 8082)
#   {{ENTITY}}         - entity name, lowercase    (e.g. product)
#   {{ENTITY_PASCAL}}  - entity name, PascalCase   (e.g. Product)
#   {{ENTITY_PLURAL}}  - entity plural, lowercase  (e.g. products)

usage() {
    cat <<EOF
Usage:
  $0 new-service <name> <prefix> <port>
  $0 new-entity  <service-dir> <entity> <entity-plural>

Examples:
  $0 new-service ferret frt 8082
  $0 new-entity ../ferret product products
EOF
    exit 1
}

pascal_case() {
    local s="$1"
    echo "${s^}"
}

SERVICE=""
SERVICE_PASCAL=""
SERVICE_UPPER=""
SERVICE_PREFIX=""
SERVICE_PORT=""
ENTITY=""
ENTITY_PASCAL=""
ENTITY_PLURAL=""

apply_tokens() {
    local file="$1"
    sed -i \
        -e "s|{{SERVICE_PASCAL}}|$SERVICE_PASCAL|g" \
        -e "s|{{SERVICE_UPPER}}|$SERVICE_UPPER|g" \
        -e "s|{{SERVICE_PREFIX}}|$SERVICE_PREFIX|g" \
        -e "s|{{SERVICE_PORT}}|$SERVICE_PORT|g" \
        -e "s|{{SERVICE}}|$SERVICE|g" \
        -e "s|{{ENTITY_PASCAL}}|$ENTITY_PASCAL|g" \
        -e "s|{{ENTITY_PLURAL}}|$ENTITY_PLURAL|g" \
        -e "s|{{ENTITY}}|$ENTITY|g" \
        "$file"
}

copy_template() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    apply_tokens "$dest"
}

cmd_new_service() {
    [ $# -lt 3 ] && usage
    SERVICE="$1"
    SERVICE_PREFIX="$2"
    SERVICE_PORT="$3"
    SERVICE_PASCAL="$(pascal_case "$SERVICE")"
    SERVICE_UPPER="${SERVICE^^}"
    ENTITY=""
    ENTITY_PASCAL=""
    ENTITY_PLURAL=""

    local dest
    dest="$(dirname "$SCRIPT_DIR")/$SERVICE"

    if [ -d "$dest" ]; then
        echo "Error: $dest already exists"
        exit 1
    fi

    echo "Scaffolding: $SERVICE (prefix=${SERVICE_PREFIX}_, port=$SERVICE_PORT)"

    mkdir -p "$dest"/{cmd/api,config,internal/{db,tools,platform/{http,render}},pkg/config,ent/{schema,migrate/migrations},data,log,bin,docs}

    while IFS= read -r -d '' tmpl; do
        local rel dest_file
        rel="${tmpl#$TEMPLATES_DIR/service/}"
        dest_file="$dest/${rel%.tmpl}"
        copy_template "$tmpl" "$dest_file"
    done < <(find "$TEMPLATES_DIR/service" -name "*.tmpl" -print0)

    # Rename dotfiles (stored without leading dot to avoid git weirdness)
    [ -f "$dest/gitignore" ]    && mv "$dest/gitignore"    "$dest/.gitignore"
    [ -f "$dest/dockerignore" ] && mv "$dest/dockerignore" "$dest/.dockerignore"

    # Store metadata so new-entity can read prefix without args
    echo "PREFIX=$SERVICE_PREFIX" > "$dest/.scaffold"

    cat <<EOF

Created: $dest

Next:
  cd $dest
  1. make vendor
  2. $0 new-entity $dest <entity> <entity-plural>
  3. Add fields to ent/schema/<entity>.go
  4. Wire entity in cmd/api/main.go + internal/platform/http/router.go
  5. make generate
  6. make migrate-gen name=initial_schema
  7. make migrate-apply
  8. make swag
  9. make build && make up
EOF
}

cmd_new_entity() {
    [ $# -lt 3 ] && usage
    local service_dir="$1"
    ENTITY="$2"
    ENTITY_PLURAL="$3"
    ENTITY_PASCAL="$(pascal_case "$ENTITY")"

    if [ ! -f "$service_dir/go.mod" ]; then
        echo "Error: $service_dir/go.mod not found"
        exit 1
    fi

    SERVICE="$(grep '^module ' "$service_dir/go.mod" | awk '{print $2}')"
    SERVICE_PASCAL="$(pascal_case "$SERVICE")"
    SERVICE_UPPER="${SERVICE^^}"
    SERVICE_PORT=""

    # Read prefix from .scaffold metadata, fall back to schema grep, then "svc"
    if [ -f "$service_dir/.scaffold" ]; then
        SERVICE_PREFIX="$(grep '^PREFIX=' "$service_dir/.scaffold" | cut -d= -f2)"
    else
        SERVICE_PREFIX="$(grep -r 'entsql.Annotation{Table:' "$service_dir/ent/schema/" 2>/dev/null \
            | head -1 | sed 's/.*Table: "\([^_]*\)_.*/\1/' || true)"
        SERVICE_PREFIX="${SERVICE_PREFIX:-svc}"
    fi

    echo "Adding entity: $ENTITY_PASCAL to $SERVICE"

    local entity_dir="$service_dir/internal/$ENTITY"
    if [ -d "$entity_dir" ]; then
        echo "Error: $entity_dir already exists"
        exit 1
    fi
    mkdir -p "$entity_dir"

    for tmpl in "$TEMPLATES_DIR/entity/"*.tmpl; do
        local filename
        filename="$(basename "${tmpl%.tmpl}")"
        # schema.go goes to ent/schema/, not entity package
        if [ "$filename" = "schema.go" ]; then
            copy_template "$tmpl" "$service_dir/ent/schema/$ENTITY.go"
        else
            copy_template "$tmpl" "$entity_dir/$filename"
        fi
    done

    cat <<EOF

Created: $entity_dir
Schema:  $service_dir/ent/schema/$ENTITY.go

Next:
  1. Add domain fields to ent/schema/$ENTITY.go
  2. make generate
  3. make migrate-gen name=add_$ENTITY
  4. make migrate-apply
  5. Wire in cmd/api/main.go:
       import "${SERVICE}/internal/${ENTITY}"
       ${ENTITY}Repo    := ${ENTITY}.NewRepository(client)
       ${ENTITY}Svc     := ${ENTITY}.NewService(${ENTITY}Repo)
       ${ENTITY}Handler := ${ENTITY}.NewHandler(${ENTITY}Svc)
  6. Wire in internal/platform/http/router.go:
       - Add *${ENTITY}.Handler param to NewRouter()
       - Add: r.Mount("/${ENTITY_PLURAL}", ${ENTITY}Handler.Routes())
  7. make swag
EOF
}

case "${1:-}" in
    new-service)        shift; cmd_new_service "$@" ;;
    new-entity)         shift; cmd_new_entity  "$@" ;;
    --help|-h|help|"")  usage ;;
    *) echo "Unknown command: $1"; usage ;;
esac
