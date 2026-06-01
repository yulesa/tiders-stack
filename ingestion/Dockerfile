FROM python:3.12-slim

# Unbuffer stdout/stderr so print() output streams live to `docker logs`
# instead of block-buffering until the process exits (stdout is a pipe,
# not a TTY, under `docker compose exec -T`).
ENV PYTHONUNBUFFERED=1

RUN apt-get update -qq && apt-get install -y -qq curl > /dev/null && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    . $HOME/.local/bin/env && \
    uv pip install --system "tiders[datafusion,clickhouse]==0.1.6" "clickhouse-connect" python-dotenv eth_abi web3 && apt-get clean

WORKDIR /ingestion
