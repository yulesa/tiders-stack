DROP DATABASE tiders_dev;
CREATE DATABASE tiders_dev;
DROP TABLE IF EXISTS tiders_dev.;
SHOW tables from tiders_dev;


SELECT * FROM tiders_dev.raw__polygon__blocks LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__fee_charged LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__fee_receiver_updated LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__max_fee_rate_updated LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__new_admin LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__new_operator LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__order_filled LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__order_preapproval_invalidated LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__order_preapproved LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__orders_matched LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__removed_admin LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__removed_operator LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__trading_paused LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__trading_unpaused LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__user_pause_block_interval_updated LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__user_paused LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__event__user_unpaused LIMIT 10;
SELECT * FROM tiders_dev.raw__polymarket__exchange__raw_logs LIMIT 10;

SELECT * FROM tiders_dev.raw__polymarket__gamma__markets LIMIT 10;

SELECT * FROM tiders_dev.mart__polymarket_v2__market_details LIMIT 10;
SELECT * FROM tiders_dev.mart__polymarket_v2__order_filled LIMIT 10;
SELECT * FROM tiders_dev.mart__polymarket_v2__trades LIMIT 1000;


SELECT COUNT(*) FROM tiders_dev.raw__polymarket__gamma__markets;

SELECT * FROM tiders_dev.mart__polymarket_v2__trades where question is null;


SELECT
    concat(database, '.', table) AS table_name,
    any(engine) AS engine,
    sum(rows) AS total_rows,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size,
    sum(data_compressed_bytes) / sum(data_uncompressed_bytes) AS compression_ratio
FROM system.parts
WHERE active = 1
GROUP BY database, table
ORDER BY sum(data_compressed_bytes) DESC;