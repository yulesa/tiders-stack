# =============================================================================
# Polymarket Gamma API — markets metadata scraper
# =============================================================================
#
# Pulls market metadata (question text, slug, outcomes, clob token ids,
# neg_risk flags, timestamps, …) from Polymarket's public Gamma API and
# writes it to ClickHouse table `raw__polymarket__gamma__markets`.
#
# The Gamma API is the only place where token_id -> human-readable
# outcome name and market question are exposed; on-chain v2 contracts
# no longer emit TokenRegistered, so this is the canonical mapping
# source.
#
# Usage:
#   docker compose exec tiders-ingestion python polymarket/polymarket_gamma_markets.py
#   docker compose exec tiders-ingestion python polymarket/polymarket_gamma_markets.py --target prod

import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import clickhouse_connect
import requests
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env")

GAMMA_URL = "https://gamma-api.polymarket.com/markets"
PAGE_LIMIT = 500
# Empirically the Gamma API rejects URLs over ~8.2 KB with 414. Each
# clob_token_ids value adds ~92 bytes; 75 ids ≈ 7 KB request URL, leaving
# headroom for any extra query params.
TOKEN_BATCH_SIZE = 25
TABLE = "raw__polymarket__gamma__markets"
ORDER_FILLED_TABLE = "raw__polymarket__exchange__event__order_filled"

CREATE_TABLE_SQL = f"""
CREATE TABLE IF NOT EXISTS {{db}}.{TABLE} (
    id                          UInt64,
    condition_id                String,
    question_id                 String,
    question                    String,
    description                 String,
    slug                        String,
    active                      UInt8,
    closed                      UInt8,
    archived                    UInt8,
    accepting_orders            UInt8,
    enable_order_book           UInt8,
    neg_risk                    UInt8,
    neg_risk_request_id         String,
    outcomes                    Array(String),
    clob_token_ids              Array(UInt256),
    outcome_prices              Array(Float64),
    icon                        String,
    image                       String,
    market_start_time           Nullable(DateTime64(3, 'UTC')),
    market_end_time             Nullable(DateTime64(3, 'UTC')),
    accepting_orders_timestamp  Nullable(DateTime64(3, 'UTC')),
    last_updated_at             Nullable(DateTime64(3, 'UTC')),
    fetched_at                  DateTime64(3, 'UTC')
)
ENGINE = ReplacingMergeTree(fetched_at)
ORDER BY (id)
"""


def _parse_dt(value):
    if not value:
        return None
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=timezone.utc)
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _parse_array(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    try:
        parsed = json.loads(value)
        return parsed if isinstance(parsed, list) else []
    except (TypeError, ValueError):
        return []


def _to_float_array(value):
    return [float(x) for x in _parse_array(value) if x not in (None, "")]


def _to_str_array(value):
    return [str(x) for x in _parse_array(value) if x is not None]


def _to_uint_token_ids(value):
    """Parse Gamma's decimal-string CLOB token ids into Python ints.

    Stored as ClickHouse `Array(UInt256)` so downstream joins against the
    on-chain `tokenId` (decoded to UInt256 in dbt) are direct numeric
    comparisons with no per-row hex/string conversion.
    """
    out: list[int] = []
    for x in _parse_array(value):
        if x in (None, ""):
            continue
        try:
            out.append(int(x))
        except (TypeError, ValueError):
            continue
    return out


def normalize(market: dict, fetched_at: datetime) -> tuple:
    return (
        int(market.get("id") or 0),
        str(market.get("conditionId") or ""),
        str(market.get("questionID") or ""),
        str(market.get("question") or ""),
        str(market.get("description") or ""),
        str(market.get("slug") or ""),
        1 if market.get("active") else 0,
        1 if market.get("closed") else 0,
        1 if market.get("archived") else 0,
        1 if market.get("acceptingOrders") else 0,
        1 if market.get("enableOrderBook") else 0,
        1 if market.get("negRisk") else 0,
        str(market.get("negRiskRequestID") or ""),
        _to_str_array(market.get("outcomes")),
        _to_uint_token_ids(market.get("clobTokenIds")),
        _to_float_array(market.get("outcomePrices")),
        str(market.get("icon") or ""),
        str(market.get("image") or ""),
        _parse_dt(market.get("startDateIso") or market.get("startDate")),
        _parse_dt(market.get("endDateIso") or market.get("endDate")),
        _parse_dt(market.get("acceptingOrdersTimestamp")),
        _parse_dt(market.get("updatedAt")),
        fetched_at,
    )


COLUMN_NAMES = [
    "id", "condition_id", "question_id", "question", "description", "slug",
    "active", "closed", "archived", "accepting_orders", "enable_order_book",
    "neg_risk", "neg_risk_request_id",
    "outcomes", "clob_token_ids", "outcome_prices",
    "icon", "image",
    "market_start_time", "market_end_time", "accepting_orders_timestamp",
    "last_updated_at", "fetched_at",
]


def fetch_all() -> list[dict]:
    """Cold-start path: paginate the entire markets catalog.

    The default /markets endpoint is implicitly `closed=false`. Closed
    (resolved) markets are silently excluded unless `closed=true` is
    passed, so we paginate both halves and dedupe by market id.
    """
    session = requests.Session()
    seen: dict[str, dict] = {}
    for closed in ("false", "true"):
        offset = 0
        while True:
            resp = session.get(
                GAMMA_URL,
                params={"limit": PAGE_LIMIT, "offset": offset, "closed": closed},
                timeout=30,
            )
            resp.raise_for_status()
            page = resp.json()
            if not page:
                break
            for market in page:
                mid = market.get("id")
                if mid is not None:
                    seen[str(mid)] = market
            print(
                f"[gamma] closed={closed} offset={offset} count={len(page)} "
                f"unique_total={len(seen)}"
            )
            if len(page) < PAGE_LIMIT:
                break
            offset += PAGE_LIMIT
            time.sleep(0.2)
    return list(seen.values())


def missing_token_ids(client) -> list[str]:
    """Distinct token ids from OrderFilled that we haven't fetched metadata for yet.

    On-chain `tokenId` is a `0x…` hex string; the gamma side stores
    `clob_token_ids` as `Array(UInt256)`. Convert the on-chain side to
    UInt256 in-query and return decimal strings so the Gamma API call can
    use them verbatim.
    """
    query = f"""
        WITH
            known_ids AS (
                SELECT arrayJoin(clob_token_ids) AS token_id
                FROM {TABLE} FINAL
                WHERE length(clob_token_ids) > 0
            ),
            chain_ids AS (
                SELECT DISTINCT
                    reinterpretAsUInt256(reverse(unhex(substring(tokenId, 3)))) AS token_id
                FROM {ORDER_FILLED_TABLE}
                WHERE tokenId != ''
            )
        SELECT toString(token_id)
        FROM chain_ids
        WHERE token_id NOT IN (SELECT token_id FROM known_ids)
    """
    rows = client.query(query).result_rows
    return [r[0] for r in rows]


def fetch_for_token_ids(token_ids: list[str]) -> list[dict]:
    """Targeted path: ask Gamma only for the markets that own these CLOB token ids.

    The /markets endpoint defaults to `closed=false` and silently drops
    resolved markets, so each batch is queried twice — once for open
    markets and once for closed — and the union is deduped by market id.
    """
    session = requests.Session()
    seen: dict[str, dict] = {}
    total_batches = (len(token_ids) + TOKEN_BATCH_SIZE - 1) // TOKEN_BATCH_SIZE
    for i in range(0, len(token_ids), TOKEN_BATCH_SIZE):
        batch = token_ids[i : i + TOKEN_BATCH_SIZE]
        batch_params = [("limit", PAGE_LIMIT)] + [
            ("clob_token_ids", tid) for tid in batch
        ]
        got_open = got_closed = 0
        for closed, counter_name in (("false", "open"), ("true", "closed")):
            resp = session.get(
                GAMMA_URL,
                params=batch_params + [("closed", closed)],
                timeout=30,
            )
            resp.raise_for_status()
            page = resp.json() or []
            for market in page:
                mid = market.get("id")
                if mid is not None:
                    seen[str(mid)] = market
            if counter_name == "open":
                got_open = len(page)
            else:
                got_closed = len(page)
            time.sleep(0.2)
        batch_num = i // TOKEN_BATCH_SIZE + 1
        print(
            f"[gamma] batch {batch_num}/{total_batches} tokens={len(batch)} "
            f"open={got_open} closed={got_closed} unique_total={len(seen)}"
        )
    return list(seen.values())


def main(target: str, full: bool):
    db_env_var = "CLICKHOUSE_DB" if target == "prod" else "CLICKHOUSE_DEV_DB"
    db = os.environ.get(db_env_var, "default")

    client = clickhouse_connect.get_client(
        host=os.environ.get("CLICKHOUSE_HOST", "localhost"),
        port=int(os.environ.get("CLICKHOUSE_PORT", "8123")),
        username=os.environ.get("CLICKHOUSE_USER", "default"),
        password=os.environ.get("CLICKHOUSE_PASSWORD", "default"),
        database=db,
        secure=os.environ.get("CLICKHOUSE_SECURE", "false").lower() == "true",
    )

    client.command(CREATE_TABLE_SQL.format(db=db))

    if full:
        print("[gamma] --full: paginating entire markets catalog")
        markets = fetch_all()
    else:
        token_ids = missing_token_ids(client)
        print(f"[gamma] {len(token_ids)} token ids in trades but not yet in {TABLE}")
        if not token_ids:
            print("[gamma] nothing to fetch, exiting")
            return
        markets = fetch_for_token_ids(token_ids)

    if not markets:
        print("[gamma] no markets returned, exiting")
        return

    fetched_at = datetime.now(tz=timezone.utc)
    rows = [normalize(m, fetched_at) for m in markets]

    client.insert(TABLE, rows, column_names=COLUMN_NAMES)
    print(f"[gamma] inserted {len(rows)} rows into {db}.{TABLE}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", type=str, default="dev")
    parser.add_argument(
        "--full",
        action="store_true",
        help="Paginate the entire markets catalog instead of "
        "only fetching ids found in OrderFilled.",
    )
    args = parser.parse_args()
    main(args.target, args.full)
