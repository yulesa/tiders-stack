{{ config(materialized='table') }}

-- Per-token hourly price + volume aggregate over CLOB fills.
--
-- Sparse: one row per (token_id, hour) where at least one trade happened.
-- For a continuous time series (forward-filled across empty hours) build
-- a denser model on top, joining against helpers__hourly_spine.
--
-- Trades with price outside [0, 1] are dropped — those are MINT / MERGE
-- side-effects on the CLOB and aren't meaningful as outcome prices.

SELECT
    toStartOfHour(timestamp)                     AS hour,
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
GROUP BY hour, token_id
