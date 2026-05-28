SHELL       := bash
.SHELLFLAGS := -euo pipefail -c

BEAVER_DIR  := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TEMPLATES   := $(BEAVER_DIR)/templates

.PHONY: service entity help
.DEFAULT_GOAL := help

help:
	@echo "Usage:"
	@echo "  make service name=<name> prefix=<prefix> port=<port>"
	@echo "  make entity  service=<service-dir> entity=<entity> [plural=<entity>s]"
	@echo ""
	@echo "Examples:"
	@echo "  make service name=ferret prefix=frt port=8082"
	@echo "  make entity  service=../ferret entity=product"

service:
	@[ "$(name)" ]   || { echo "Error: name= required";   exit 1; }; \
	[ "$(prefix)" ] || { echo "Error: prefix= required"; exit 1; }; \
	[ "$(port)" ]   || { echo "Error: port= required";   exit 1; }; \
	SERVICE="$(name)"; \
	SERVICE_PREFIX="$(prefix)"; \
	SERVICE_PORT="$(port)"; \
	SERVICE_PASCAL="$${SERVICE^}"; \
	SERVICE_UPPER="$${SERVICE^^}"; \
	DEST="$(BEAVER_DIR)/../$(name)"; \
	TMPL="$(TEMPLATES)"; \
	if [ -d "$$DEST" ]; then echo "Error: $$DEST already exists"; exit 1; fi; \
	echo "Scaffolding: $$SERVICE (prefix=$${SERVICE_PREFIX}_, port=$$SERVICE_PORT)"; \
	mkdir -p "$$DEST"/{cmd/api,config,internal/{db,tools,platform/{http,render}},pkg/config,ent/{schema,migrate/migrations},data,log,bin,docs}; \
	apply() { \
	  sed -i \
	    -e "s|{{SERVICE_PASCAL}}|$$SERVICE_PASCAL|g" \
	    -e "s|{{SERVICE_UPPER}}|$$SERVICE_UPPER|g" \
	    -e "s|{{SERVICE_PREFIX}}|$$SERVICE_PREFIX|g" \
	    -e "s|{{SERVICE_PORT}}|$$SERVICE_PORT|g" \
	    -e "s|{{SERVICE}}|$$SERVICE|g" \
	    -e "s|{{ENTITY_PASCAL}}||g" \
	    -e "s|{{ENTITY_PLURAL}}||g" \
	    -e "s|{{ENTITY}}||g" \
	    "$$1"; \
	}; \
	while IFS= read -r -d '' tmpl; do \
	  rel="$${tmpl#$$TMPL/service/}"; \
	  dest_file="$$DEST/$${rel%.tmpl}"; \
	  mkdir -p "$$(dirname "$$dest_file")"; \
	  cp "$$tmpl" "$$dest_file"; \
	  apply "$$dest_file"; \
	done < <(find "$$TMPL/service" -name "*.tmpl" -print0); \
	[ -f "$$DEST/gitignore" ]    && mv "$$DEST/gitignore"    "$$DEST/.gitignore"    || true; \
	[ -f "$$DEST/dockerignore" ] && mv "$$DEST/dockerignore" "$$DEST/.dockerignore" || true; \
	echo "PREFIX=$$SERVICE_PREFIX" > "$$DEST/.scaffold"; \
	echo ""; \
	echo "Created: $$DEST"; \
	echo ""; \
	echo "Next:"; \
	echo "  cd $$DEST"; \
	echo "  1. make vendor"; \
	echo "  2. (from beaver) make entity service=$$DEST entity=<entity>"; \
	echo "  3. Add fields to ent/schema/<entity>.go"; \
	echo "  4. Wire entity in cmd/api/main.go + internal/platform/http/router.go"; \
	echo "  5. make generate"; \
	echo "  6. make migrate-gen name=initial_schema"; \
	echo "  7. make migrate-apply"; \
	echo "  8. make swag"; \
	echo "  9. make build && make up"

entity:
	@[ "$(service)" ] || { echo "Error: service= required"; exit 1; }; \
	[ "$(entity)" ]  || { echo "Error: entity= required";  exit 1; }; \
	SERVICE_DIR="$(service)"; \
	ENTITY="$(entity)"; \
	ENTITY_PLURAL="$(if $(plural),$(plural),$${ENTITY}s)"; \
	ENTITY_PASCAL="$${ENTITY^}"; \
	if [ ! -f "$$SERVICE_DIR/go.mod" ]; then echo "Error: $$SERVICE_DIR/go.mod not found"; exit 1; fi; \
	SERVICE="$$(grep '^module ' "$$SERVICE_DIR/go.mod" | awk '{print $$2}')"; \
	SERVICE_PASCAL="$${SERVICE^}"; \
	SERVICE_UPPER="$${SERVICE^^}"; \
	if [ -f "$$SERVICE_DIR/.scaffold" ]; then \
	  SERVICE_PREFIX="$$(grep '^PREFIX=' "$$SERVICE_DIR/.scaffold" | cut -d= -f2)"; \
	else \
	  SERVICE_PREFIX="$$(grep -r 'entsql.Annotation{Table:' "$$SERVICE_DIR/ent/schema/" 2>/dev/null \
	    | head -1 | sed 's/.*Table: "\([^_]*\)_.*/\1/' || true)"; \
	  SERVICE_PREFIX="$${SERVICE_PREFIX:-svc}"; \
	fi; \
	echo "Adding entity: $$ENTITY_PASCAL to $$SERVICE"; \
	ENTITY_DIR="$$SERVICE_DIR/internal/$$ENTITY"; \
	if [ -d "$$ENTITY_DIR" ]; then echo "Error: $$ENTITY_DIR already exists"; exit 1; fi; \
	mkdir -p "$$ENTITY_DIR"; \
	TMPL="$(TEMPLATES)"; \
	apply() { \
	  sed -i \
	    -e "s|{{SERVICE_PASCAL}}|$$SERVICE_PASCAL|g" \
	    -e "s|{{SERVICE_UPPER}}|$$SERVICE_UPPER|g" \
	    -e "s|{{SERVICE_PREFIX}}|$$SERVICE_PREFIX|g" \
	    -e "s|{{SERVICE_PORT}}||g" \
	    -e "s|{{SERVICE}}|$$SERVICE|g" \
	    -e "s|{{ENTITY_PASCAL}}|$$ENTITY_PASCAL|g" \
	    -e "s|{{ENTITY_PLURAL}}|$$ENTITY_PLURAL|g" \
	    -e "s|{{ENTITY}}|$$ENTITY|g" \
	    "$$1"; \
	}; \
	for tmpl in "$$TMPL/entity/"*.tmpl; do \
	  filename="$$(basename "$${tmpl%.tmpl}")"; \
	  if [ "$$filename" = "schema.go" ]; then \
	    cp "$$tmpl" "$$SERVICE_DIR/ent/schema/$$ENTITY.go"; \
	    apply "$$SERVICE_DIR/ent/schema/$$ENTITY.go"; \
	  else \
	    cp "$$tmpl" "$$ENTITY_DIR/$$filename"; \
	    apply "$$ENTITY_DIR/$$filename"; \
	  fi; \
	done; \
	echo ""; \
	echo "Created: $$ENTITY_DIR"; \
	echo "Schema:  $$SERVICE_DIR/ent/schema/$$ENTITY.go"; \
	echo ""; \
	echo "Next:"; \
	echo "  1. Add domain fields to ent/schema/$$ENTITY.go"; \
	echo "  2. make generate"; \
	echo "  3. make migrate-gen name=add_$$ENTITY"; \
	echo "  4. make migrate-apply"; \
	echo "  5. Wire in cmd/api/main.go:"; \
	echo "       import \"$$SERVICE/internal/$$ENTITY\""; \
	echo "       $${ENTITY}Repo    := $${ENTITY}.NewRepository(client)"; \
	echo "       $${ENTITY}Svc     := $${ENTITY}.NewService($${ENTITY}Repo)"; \
	echo "       $${ENTITY}Handler := $${ENTITY}.NewHandler($${ENTITY}Svc)"; \
	echo "  6. Wire in internal/platform/http/router.go:"; \
	echo "       - Add *$${ENTITY_PASCAL}.Handler param to NewRouter()"; \
	echo "       - Add: r.Mount(\"/$$ENTITY_PLURAL\", $${ENTITY}Handler.Routes())"; \
	echo "  7. make swag"
