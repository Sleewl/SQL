WITH all_users AS(
  SELECT
    time :: DATE AS date,
    COUNT(DISTINCT user_id) AS users
  FROM
    user_actions
  GROUP BY
    date
),
paying_users AS (
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
    ) AS pay_users
  FROM
    user_actions
  GROUP BY
    date
),
avg_order_value AS (
  SELECT
    time :: DATE AS date,
    COUNT(DISTINCT order_id) FILTER (
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
    ) AS all_orders
  FROM
    user_actions
  GROUP BY
    date
),
revenue_per_day AS (
  SELECT
    creation_time :: DATE AS date,
    SUM(p.price) FILTER (
      WHERE
        order_id IN (
          SELECT
            order_id
          FROM
            user_actions
          WHERE
            action = 'create_order'
        )
    ) AS revenue
  FROM
    orders
    CROSS JOIN UNNEST(product_ids) AS pr_id
    LEFT JOIN products AS p ON pr_id = p.product_id
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
  rpd.date,
  ROUND(revenue :: numeric / au.users, 2) AS arpu,
  ROUND(revenue :: numeric / pu.pay_users, 2) AS arppu,
  ROUND(revenue :: numeric / aov.all_orders, 2) AS aov
FROM
  revenue_per_day AS rpd
  LEFT JOIN all_users AS au USING(date)
  LEFT JOIN paying_users AS pu USING(date)
  LEFT JOIN avg_order_value AS aov USING(date)
ORDER BY
  date ASC