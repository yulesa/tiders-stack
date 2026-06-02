# Polymarket v2 pipeline — runs ingestion scripts inside the tiders-ingestion container,
# then dbt models matching polymarket_v2 inside the dbt container.
#
# Optional vars (pass on the command line, no leading dashes):
#   TO_BLOCK=12345     forwarded as --to-block to each ingestion script
#   TARGET=prod        forwarded as --target to ingestion scripts and dbt
#
# Examples:
#   make polymarket_v2
#   make polymarket_v2-ingest TO_BLOCK=22000000
#   make polymarket_v2-dbt TARGET=prod
#   make polymarket_v2 TO_BLOCK=22000000 TARGET=prod

# Build optional flag fragments; empty when the var is unset
TO_BLOCK_FLAG := $(if $(TO_BLOCK),--to-block $(TO_BLOCK))
TARGET_FLAG   := $(if $(TARGET),--target $(TARGET))
INGEST_FLAGS  := $(TO_BLOCK_FLAG) $(TARGET_FLAG)
DBT_FLAGS     := $(TARGET_FLAG)

.PHONY: polymarket_v2-ingest polymarket_v2-dbt polymarket_v2-dashboard

polymarket_v2-ingest:
	docker compose exec -T tiders-ingestion python polymarket/polymarket_exchange.py $(INGEST_FLAGS)
	docker compose exec -T tiders-ingestion python polymarket/polymarket_gamma_markets.py $(INGEST_FLAGS)

polymarket_v2-dbt:
	docker compose exec -T dbt dbt run --select "*polymarket_v2*" $(DBT_FLAGS)

polymarket_v2-dashboard:
	docker compose exec -T dashboard-builder sh -c "cd /dashboards/polymarket_v2 && [ -d node_modules ] || npm install; npm run build"
