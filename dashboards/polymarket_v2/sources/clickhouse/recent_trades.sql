-- Most recent trades across all markets.
select
    timestamp,
    question,
    token_outcome      as outcome,
    amount             as amount_usd,
    shares,
    price,
    taker,
    polymarket_link
from tiders.mart__polymarket_v2__trades
where question is not null
order by timestamp desc
limit 500
