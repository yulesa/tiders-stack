-- Most active users by traded volume.
-- The real user is the non-exchange side of the fill: when the taker is the
-- exchange contract (is_taker_side = 1) the user is the maker, else the taker.
-- This also keeps the exchange contracts themselves out of the ranking.
select
    if(is_taker_side, maker, taker) as trader,
    sum(amount)             as volume_usd,
    toUInt32(count())       as trades,
    toUInt32(uniqExact(condition_id)) as markets_traded,
    avg(price)              as avg_price
from tiders.mart__polymarket_v2__trades
group by trader
order by volume_usd desc
limit 50
