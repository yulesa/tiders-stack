-- Headline KPIs across all Polymarket CLOB trades.
select
    -- Cast 64-bit counts to UInt32 so JSONEachRow emits them as JSON numbers
    -- (UInt64 is quoted as a string, which Evidence would type as STRING).
    toUInt32(count())             as trades,
    sum(amount)                   as volume_usd,
    toUInt32(uniqExact(condition_id)) as markets,
    toUInt32(uniqExact(token_id)) as tokens,
    toUInt32(uniqExact(taker))    as traders,
    avg(price)                    as avg_price,
    sum(fee)                      as fees_usd,
    min(timestamp)                as first_trade,
    max(timestamp)                as last_trade
from tiders.mart__polymarket_v2__trades
