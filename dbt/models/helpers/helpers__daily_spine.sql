{{
    config(
        materialized = 'view',
    )
}}

SELECT
    arrayJoin(
        arrayMap(
            x -> toDate('2008-01-01') + toIntervalDay(x),
            range(
                toUInt32(
                    dateDiff('day', toDate('2008-01-01'), toDate('2035-12-31')) + 1
                )
            )
        )
    ) AS day
