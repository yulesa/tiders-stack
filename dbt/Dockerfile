# =============================================================================
# dbt — ClickHouse transformation runner
# =============================================================================
# Minimal image with dbt-core + dbt-clickhouse. The container stays idle
# (tail -f /dev/null in compose) so you can trigger runs on demand:
#
#   docker compose exec dbt dbt build
#
#   Run specific models in the dev environment:
#   docker compose exec dbt dbt run --select my_model
#
#   Run specific models in the prod environment:
#   docker compose exec dbt dbt run --select my_model --target prod
#
FROM python:3.12-slim

WORKDIR /dbt

RUN pip install --no-cache-dir \
    "dbt-core~=1.8.0" \
    "dbt-clickhouse~=1.8.0"

ENV DBT_PROFILES_DIR=/dbt
