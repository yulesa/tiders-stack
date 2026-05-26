FROM python:3.12-slim

RUN apt-get update -qq && apt-get install -y -qq curl > /dev/null && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    . $HOME/.local/bin/env && \
    uv pip install --system "tiders[datafusion,clickhouse]" "clickhouse-connect<1" python-dotenv eth_abi web3 && apt-get clean

WORKDIR /ingestion
