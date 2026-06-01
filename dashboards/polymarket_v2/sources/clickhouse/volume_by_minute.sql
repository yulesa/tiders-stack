-- Intraday trading activity, one row per minute.
select
    toStartOfMinute(timestamp) as minute,
    toUInt32(count())          as trades,
    sum(amount)                as volume_usd,
    toUInt32(uniqExact(taker)) as traders,
    avg(price)                 as avg_price
from tiders.mart__polymarket_v2__trades
group by minute
order by minute
