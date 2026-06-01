{{ config(materialized='view') }}

-- Slim projection of market_details exposing the (token_id, condition_id)
-- mapping plus the human-readable outcome. Substitute for spellbook's
-- `polymarket_polygon_base_ctf_tokens`, which derived the same mapping
-- from the on-chain `TokenRegistered` event; that event was removed in
-- the v2 CTFExchange contracts, so we synthesize it from the Gamma dump.

SELECT
    token_id,
    condition_id,
    question_id,
    question,
    token_outcome              AS outcome,
    token_outcome_name         AS outcome_name,
    neg_risk
FROM {{ ref('mart__polymarket_v2__market_details') }}
