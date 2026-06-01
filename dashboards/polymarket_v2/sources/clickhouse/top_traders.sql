-- Most active takers by traded volume.
select
    taker                   as trader,
    sum(amount)             as volume_usd,
    count()                 as trades,
    uniqExact(condition_id) as markets_traded,
    avg(price)              as avg_price
from tiders.mart__polymarket_v2__trades
group by taker
order by volume_usd desc
limit 50
