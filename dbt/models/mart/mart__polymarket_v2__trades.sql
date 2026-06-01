{{ config(materialized='table') }}

-- Polymarket v2 CTFExchange trades enriched with off-chain market metadata
-- (question text, outcome names, slug-derived link, neg_risk flag, …).
--
-- Built on top of the per-event `order_filled` mart and joined against the
-- Gamma API-sourced market_details for token_id -> market context.

SELECT
    t.*,
    md.condition_id,
    md.question_id,
    md.question,
    md.market_description,
    md.token_outcome,
    md.token_outcome_name,
    md.slug,
    md.polymarket_link,
    md.neg_risk,
    md.neg_risk_request_id,
    md.active        AS market_active,
    md.closed        AS market_closed,
    md.archived      AS market_archived,
    md.market_start_time,
    md.market_end_time
FROM {{ ref('mart__polymarket_v2__order_filled') }} AS t
LEFT JOIN {{ ref('mart__polymarket_v2__market_details') }} AS md
    ON t.token_id = md.token_id
