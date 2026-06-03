{{ config(materialized='table') }}

-- Per-token daily price + volume aggregate over CLOB fills.
--
-- Sparse: one row per (token_id, day) where at least one trade happened.
-- See market_prices_hourly for finer-grained granularity. The same
-- price-range filter applies — trades outside [0, 1] are MINT / MERGE
-- artefacts, not outcome prices.

SELECT
    toDate(timestamp)                            AS day,
    token_id,
    any(condition_id)                             AS condition_id,
    any(question)                                 AS question,
    any(token_outcome_name)                       AS token_outcome_name,
    argMin(price, timestamp)                     AS open_price,
    max(price)                                    AS high_price,
    min(price)                                    AS low_price,
    argMax(price, timestamp)                     AS close_price,
    sum(price * shares) / nullIf(sum(shares), 0)  AS vwap,
    sum(amount)                                   AS volume_usd,
    sum(shares)                                   AS volume_contracts,
    count()                                       AS trade_count
FROM {{ ref('mart__polymarket_v2__trades') }}
WHERE price BETWEEN 0 AND 1
GROUP BY day, token_id
