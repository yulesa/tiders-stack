{{ config(materialized='table') }}

SELECT
    t.timestamp AS timestamp,
    if(t.side = 0, 'BUY', 'SELL') || '-' || t.transaction_hash || '-' || t.log_index AS id,
    'CLOB trade' AS action,
    t.token_id AS asset_id,
    if(t.side = 0, toFloat64(t.maker_amount_filled), toFloat64(t.taker_amount_filled)) / 1e6 AS amount,
    if(t.side = 0, toFloat64(t.taker_amount_filled), toFloat64(t.maker_amount_filled)) / 1e6 AS shares,
    if(
        t.side = 0,
        (toFloat64(t.maker_amount_filled) / 1e6) / (toFloat64(t.taker_amount_filled) / 1e6),
        (toFloat64(t.taker_amount_filled) / 1e6) / (toFloat64(t.maker_amount_filled) / 1e6)
    ) AS price,
    toFloat64(t.fee) / 1e6 AS fee,
    t.maker,
    t.taker,
    t.taker IN (
        '0xe111180000d2663c0091e4f400237545b87b996b',
        '0xe2222d279d744050d28e00520010520000310f59'
    ) AS is_taker_side,
    t.maker_amount_filled AS maker_amount_raw,
    t.taker_amount_filled AS taker_amount_raw,
    t.builder,
    t.metadata,
    t.block_number,
    t.address AS contract_address,
    t.log_index AS evt_index,
    t.transaction_hash AS tx_hash
FROM {{ ref('stg__polymarket_v2__ctfexchange__event__order_filled') }} AS t
