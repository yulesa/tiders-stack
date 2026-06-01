-- Market catalogue health from the market_details mart.
select
    uniqExact(condition_id)                            as total_markets,
    count()                                            as total_tokens,
    uniqExactIf(condition_id, active = 1 and closed = 0) as active_markets,
    uniqExactIf(condition_id, closed = 1)              as closed_markets,
    countIf(neg_risk = 1)                              as neg_risk_tokens,
    countIf(accepting_orders = 1)                      as accepting_orders_tokens
from tiders.mart__polymarket_v2__market_details
