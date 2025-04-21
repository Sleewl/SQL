WITH user_first_action AS (
  SELECT
    MIN(time) :: date AS first_action_date,
    user_id
  FROM
    user_actions
  GROUP BY
    user_id
),
general_count_orders AS (
  SELECT
    time :: DATE AS date,
    COUNT(DISTINCT order_id) FILTER(
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
    ) AS orders
  FROM
    user_actions
  GROUP BY
    date
),
user_first_order AS (
  SELECT
    user_id,
    MIN(time) :: DATE AS first_order_date
  FROM
    user_actions
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
  GROUP BY
    user_id
),
first_order_count AS (
  SELECT
    first_order_date AS date,
    COUNT(*) AS first_orders
  FROM
    user_first_order
  GROUP BY
    first_order_date
),
new_users_orders_per_day AS (
  SELECT
    ua.time :: DATE AS date,
    COUNT(*) AS new_users_orders
  FROM
    user_actions ua
    JOIN user_first_action ufa ON ua.user_id = ufa.user_id
  WHERE
    ua.action = 'create_order'
    AND ua.order_id NOT IN (
      SELECT
        order_id
      FROM
        user_actions
      WHERE
        action = 'cancel_order'
    )
    AND ua.time :: DATE = ufa.first_action_date
  GROUP BY
    ua.time :: DATE
)
SELECT
  date,
  orders,
  first_orders,
  new_users_orders,
  ROUND((first_orders :: numeric / orders) * 100, 2) AS first_orders_share,
  ROUND((new_users_orders :: numeric / orders) * 100, 2) AS new_users_orders_share
FROM(
    SELECT
      gc.date AS date,
      gc.orders AS orders,
      first_orders,
      new_users_orders
    FROM
      general_count_orders AS gc
      LEFT JOIN first_order_count AS fc using(date)
      LEFT JOIN new_users_orders_per_day AS per_d using(date)
    ORDER BY
      date ASC
  ) t