-- Per-minute VWAP price and volume for each outcome of the top 300 markets.
-- Feeds the Market Explorer price chart (filtered client-side by condition_id).
with top as (
    select condition_id
    from tiders.mart__polymarket_v2__trades
    where question is not null
    group by condition_id
    order by sum(amount) desc
    limit 300
)
select
    t.condition_id                              as condition_id,
    t.token_outcome                             as outcome,
    toStartOfMinute(t.timestamp)                as minute,
    sum(t.amount) / nullIf(sum(t.shares), 0)    as price,
    sum(t.amount)                               as volume_usd,
    count()                                     as trades
from tiders.mart__polymarket_v2__trades as t
inner join top using (condition_id)
where t.question is not null
group by t.condition_id, t.token_outcome, minute
order by t.condition_id, outcome, minute
