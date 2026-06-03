{{ config(materialized='table') }}

-- Per-token market metadata exposed for joins from on-chain trade marts.
-- Fans out the parallel `outcomes` / `clob_token_ids` arrays from the
-- Gamma dump into one row per (market, outcome), keyed on token_id
-- (UInt256) to match the type used by the decoded CTFExchange marts.

WITH paired AS (
    SELECT
        *,
        arrayJoin(arrayZip(outcomes, clob_token_ids)) AS pair
    FROM {{ ref('stg__polymarket_v2__gamma__markets') }}
    WHERE length(outcomes) = length(clob_token_ids)
      AND length(clob_token_ids) > 0
)

SELECT
    pair.2                                            AS token_id,
    pair.1                                            AS token_outcome,
    concat(pair.1, ' - ', question)                   AS token_outcome_name,
    condition_id,
    question_id,
    question,
    description                                       AS market_description,
    slug,
    concat('https://polymarket.com/event/', slug)     AS polymarket_link,
    neg_risk,
    neg_risk_request_id,
    active,
    closed,
    archived,
    accepting_orders,
    enable_order_book,
    market_start_time,
    market_end_time,
    accepting_orders_timestamp,
    icon,
    image,
    last_updated_at
FROM paired
WHERE pair.2 != 0
