-- Up to 100 most recent trades per top-300 market, for the Market Explorer detail table.
with top as (
    select condition_id
    from tiders.mart__polymarket_v2__trades
    where question is not null
    group by condition_id
    order by sum(amount) desc
    limit 300
),
ranked as (
    select
        t.condition_id  as condition_id,
        t.timestamp     as timestamp,
        t.token_outcome as outcome,
        t.amount        as amount_usd,
        t.shares        as shares,
        t.price         as price,
        -- Show the real user (non-exchange side), not the raw taker.
        if(t.is_taker_side, t.maker, t.taker) as trader,
        row_number() over (partition by t.condition_id order by t.timestamp desc) as rn
    from tiders.mart__polymarket_v2__trades as t
    inner join top using (condition_id)
    where t.question is not null
)
select condition_id, timestamp, outcome, amount_usd, shares, price, trader
from ranked
where rn <= 100
order by condition_id, timestamp desc
