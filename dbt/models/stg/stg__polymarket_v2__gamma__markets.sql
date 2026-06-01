{{ config(materialized='view') }}

-- 1:1 view of the Gamma API dump, collapsed to the latest snapshot
-- per market via FINAL. No un-nesting or business logic — that
-- happens in mart__polymarket_v2__market_details.

SELECT
    id                          AS market_id,
    condition_id,
    question_id,
    question,
    description,
    slug,
    active,
    closed,
    archived,
    accepting_orders,
    enable_order_book,
    neg_risk,
    neg_risk_request_id,
    outcomes,
    clob_token_ids,
    outcome_prices,
    icon,
    image,
    market_start_time,
    market_end_time,
    accepting_orders_timestamp,
    last_updated_at,
    fetched_at
FROM raw__polymarket__gamma__markets
FINAL
