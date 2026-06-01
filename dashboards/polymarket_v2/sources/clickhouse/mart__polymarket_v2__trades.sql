-- 5-row preview for the dataset explorer. The full table is sold via the x402
-- download button, so only a small sample needs to be cached for Evidence.
-- token_id (UInt256) and the *_amount_raw (Decimal(76,0)) columns exceed what
-- DuckDB (Evidence's engine) can represent, so cast them to strings for the preview.
select * replace (
    toString(token_id)         as token_id,
    toString(maker_amount_raw) as maker_amount_raw,
    toString(taker_amount_raw) as taker_amount_raw
)
from tiders.mart__polymarket_v2__trades
limit 5
