-- Headline KPIs across all Polymarket CLOB trades.
select
    count()                       as trades,
    sum(amount)                   as volume_usd,
    uniqExact(condition_id)       as markets,
    uniqExact(token_id)           as tokens,
    uniqExact(taker)              as traders,
    avg(price)                    as avg_price,
    sum(fee)                      as fees_usd,
    min(timestamp)                as first_trade,
    max(timestamp)                as last_trade
from tiders.mart__polymarket_v2__trades
