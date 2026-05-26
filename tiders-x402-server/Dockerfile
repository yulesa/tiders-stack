# ── Tiders x402 API server image ─────────────────────────────────
# The server ships as a Python package on PyPI. We install it with
# `uv pip install` on top of a slim Python base.
FROM python:3.12-slim-bookworm

# TLS roots for HTTPS calls to the x402 facilitator / ClickHouse.
# `uv` is the installer we use to fetch the package; we pull it
# from its own distroless image so we don't need a separate step
# to bootstrap it with pip.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Pin the version here for reproducible builds. Leave unset (or "*")
# to always grab the latest published release.
ARG TIDERS_VERSION=

RUN if [ -n "${TIDERS_VERSION}" ] && [ "${TIDERS_VERSION}" != "*" ]; then \
        uv pip install --system --no-cache "tiders-x402-server==${TIDERS_VERSION}"; \
    else \
        uv pip install --system --no-cache "tiders-x402-server"; \
    fi

EXPOSE 4021

# The config path is passed in via the compose command: field so the
# same image can be reused with different configs.
ENTRYPOINT ["tiders-x402-server"]
