{{ config(materialized='view') }}

SELECT
    orderHash AS order_hash,
    maker,
    taker,
    side,
    tokenId AS token_id,
    makerAmountFilled AS maker_amount_filled,
    takerAmountFilled AS taker_amount_filled,
    fee,
    builder,
    metadata,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__order_filled
