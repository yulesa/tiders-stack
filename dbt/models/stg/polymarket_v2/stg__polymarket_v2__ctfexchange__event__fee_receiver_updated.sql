{{ config(materialized='view') }}

SELECT
    feeReceiver AS fee_receiver,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__fee_receiver_updated
