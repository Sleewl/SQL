WITH
  users_first AS (
    SELECT MIN(time)::date AS date, user_id
    FROM user_actions
    GROUP BY user_id
  ),
  couriers_first AS (
    SELECT MIN(time)::date AS date, courier_id
    FROM courier_actions
    GROUP BY courier_id
  ),
  unioned AS (
    SELECT date, user_id, NULL    AS courier_id FROM users_first
    UNION ALL
    SELECT date, NULL    AS user_id, courier_id FROM couriers_first
  ),
  running AS (
    SELECT
      date,
      COUNT(user_id)    AS new_users,
      COUNT(courier_id) AS new_couriers
    FROM unioned
    GROUP BY date
  ),
  total AS (
    SELECT
      date,
      SUM(new_users)    OVER (ORDER BY date) AS total_users,
      SUM(new_couriers) OVER (ORDER BY date) AS total_couriers
    FROM running
  ),
  daily_paying AS (
    SELECT
      time::date AS date,
      COUNT(DISTINCT user_id)
        FILTER (
          WHERE action = 'create_order'
            AND order_id NOT IN (
              SELECT order_id
              FROM user_actions
              WHERE action = 'cancel_order'
            )
        ) AS paying_users
    FROM user_actions
    GROUP BY time::date
  ),

  daily_couriers AS (
    SELECT
      time::date AS date,
      COUNT(DISTINCT courier_id)
        FILTER (
          WHERE action = 'deliver_order'
             OR (
                  action = 'accept_order'
                  AND order_id IN (
                    SELECT order_id
                    FROM courier_actions
                    WHERE action = 'deliver_order'
                  )
                )
        ) AS active_couriers
    FROM courier_actions
    GROUP BY time::date
  ),

  daily_metrics AS (
    SELECT
      t.date,
      COALESCE(dp.paying_users,    0) AS paying_users,
      COALESCE(dc.active_couriers, 0) AS active_couriers
    FROM total t
    LEFT JOIN daily_paying    dp ON dp.date = t.date
    LEFT JOIN daily_couriers dc ON dc.date = t.date
  )

SELECT
  dm.date,
  dm.paying_users,
  dm.active_couriers,
  ROUND((dm.paying_users::numeric   / tot.total_users)    * 100, 2) AS paying_users_share,
  ROUND((dm.active_couriers::numeric / tot.total_couriers) * 100, 2) AS active_couriers_share
FROM daily_metrics dm
JOIN total tot ON dm.date = tot.date
ORDER BY dm.date;
