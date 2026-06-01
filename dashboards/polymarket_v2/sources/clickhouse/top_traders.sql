-- Most active takers by traded volume.
select
    taker                   as trader,
    sum(amount)             as volume_usd,
    toUInt32(count())       as trades,
    toUInt32(uniqExact(condition_id)) as markets_traded,
    avg(price)              as avg_price
from tiders.mart__polymarket_v2__trades
where (taker != '0xe111180000d2663c0091e4f400d237545b87b996b'
    and taker != '0xe2222d279d744050d28e00520010520000310f59')
group by taker
order by volume_usd desc
limit 50
