-- Intraday trading activity, one row per minute.
select
    toStartOfMinute(timestamp) as minute,
    toUInt32(count())          as trades,
    sum(amount)                as volume_usd,
    -- Real user = non-exchange side of the fill (maker when taker is the exchange).
    toUInt32(uniqExact(if(is_taker_side, maker, taker))) as traders,
    avg(price)                 as avg_price
from tiders.mart__polymarket_v2__trades
group by minute
order by minute
