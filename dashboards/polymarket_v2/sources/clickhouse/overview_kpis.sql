-- Headline KPIs across all Polymarket CLOB trades.
select
    -- Cast 64-bit counts to UInt32 so JSONEachRow emits them as JSON numbers
    -- (UInt64 is quoted as a string, which Evidence would type as STRING).
    toUInt32(count())             as trades,
    sum(amount)                   as volume_usd,
    toUInt32(uniqExact(condition_id)) as markets,
    toUInt32(uniqExact(token_id)) as tokens,
    -- The real user is the non-exchange side of the fill: when the taker is the
    -- exchange contract (is_taker_side = 1) the user is the maker, else the taker.
    toUInt32(uniqExact(if(is_taker_side, maker, taker))) as traders,
    avg(price)                    as avg_price,
    sum(fee)                      as fees_usd,
    min(timestamp)                as first_trade,
    max(timestamp)                as last_trade
from tiders.mart__polymarket_v2__trades
