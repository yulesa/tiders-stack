-- Market catalogue health from the market_details mart.
-- Counts cast to UInt32 so JSONEachRow emits JSON numbers (not quoted UInt64).
select
    toUInt32(uniqExact(condition_id))                            as total_markets,
    toUInt32(count())                                            as total_tokens,
    toUInt32(uniqExactIf(condition_id, active = 1 and closed = 0)) as active_markets,
    toUInt32(uniqExactIf(condition_id, closed = 1))              as closed_markets,
    toUInt32(countIf(neg_risk = 1))                              as neg_risk_tokens,
    toUInt32(countIf(accepting_orders = 1))                      as accepting_orders_tokens
from tiders.mart__polymarket_v2__market_details
