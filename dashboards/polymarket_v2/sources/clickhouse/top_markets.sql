-- Top markets by traded volume (used for overview ranking + explorer dropdown).
select
    condition_id,
    any(question)        as question,
    any(slug)            as slug,
    any(polymarket_link) as polymarket_link,
    sum(amount)              as volume_usd,
    toUInt32(count())        as trades,
    -- Real user = non-exchange side of the fill (maker when taker is the exchange).
    toUInt32(uniqExact(if(is_taker_side, maker, taker))) as traders,
    avg(price)               as avg_price
from tiders.mart__polymarket_v2__trades as t
where t.question is not null
group by condition_id
order by volume_usd desc
limit 300
