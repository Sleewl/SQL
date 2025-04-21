WITH pay_users AS (
  SELECT
    time :: DATE AS date,
    COUNT(DISTINCT user_id) FILTER (
      WHERE
        action = 'create_order'
        AND order_id NOT IN (
          SELECT
            order_id
          FROM
            user_actions
          WHERE
            action = 'cancel_order'
        )
    ) AS paying_users
  FROM
    user_actions
  GROUP BY
    date
),
active_couriers AS (
  SELECT
    time :: DATE AS date,
    COUNT(DISTINCT courier_id) FILTER (
      WHERE
        action = 'deliver_order'
        OR (
          action = 'accept_order'
          AND order_id IN (
            SELECT
              order_id
            FROM
              courier_actions
            WHERE
              action = 'deliver_order'
          )
        )
    ) AS active_couriers
  FROM
    courier_actions
  WHERE
    order_id NOT IN (
      SELECT
        order_id
      FROM
        user_actions
      WHERE
        action = 'cancel_order'
    )
  GROUP BY
    date
),
count_orders AS (
  SELECT
    creation_time :: DATE AS date,
    COUNT(DISTINCT order_id) AS orders
  FROM
    orders
  WHERE
    order_id NOT IN (
      SELECT
        order_id
      FROM
        user_actions
      WHERE
        action = 'cancel_order'
    )
  GROUP BY
    date
)
SELECT
  date,
  ROUND((paying_users :: numeric / active_couriers), 2) AS users_per_courier,
  ROUND((orders :: numeric / active_couriers), 2) AS orders_per_courier
FROM
  pay_users AS pu
  LEFT JOIN active_couriers AS ac using(date)
  LEFT JOIN count_orders AS co using(date)
ORDER BY
  date ASC