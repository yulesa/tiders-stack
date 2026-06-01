-- 5-row preview for the dataset explorer. The full table is sold via the x402
-- download button, so only a small sample needs to be cached for Evidence.
-- token_id is UInt256; DuckDB (Evidence's engine) can't hold int256, so cast it
-- to a string for the preview.
select * replace (toString(token_id) as token_id)
from tiders.mart__polymarket_v2__market_prices_hourly
limit 5
