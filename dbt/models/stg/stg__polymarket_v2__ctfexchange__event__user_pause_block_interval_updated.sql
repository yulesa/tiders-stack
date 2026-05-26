{{ config(materialized='view') }}

SELECT
    oldInterval AS old_interval,
    newInterval AS new_interval,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__user_pause_block_interval_updated
