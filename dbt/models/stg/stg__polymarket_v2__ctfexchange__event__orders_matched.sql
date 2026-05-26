{{ config(materialized='view') }}

SELECT
    takerOrderHash AS taker_order_hash,
    takerOrderMaker AS taker_order_maker,
    side,
    tokenId AS token_id,
    makerAmountFilled AS maker_amount_filled,
    takerAmountFilled AS taker_amount_filled,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__orders_matched
