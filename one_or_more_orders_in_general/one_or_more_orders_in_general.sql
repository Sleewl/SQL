WITH user_one_order AS (
  SELECT
    date,
    COUNT(DISTINCT user_id) AS user_who_have_one_order
  FROM(
      SELECT
        time :: DATE AS date,
        user_id,
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
        ) AS orders
      FROM
        user_actions
      GROUP BY
        user_id,
        date
    ) t
  WHERE
    orders = 1
  GROUP BY
    date
),
user_who_have_more_one_order AS (
  SELECT
    date,
    COUNT(DISTINCT user_id) AS user_who_have_more_one_order
  FROM(
      SELECT
        time :: DATE AS date,
        user_id,
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
        ) AS orders
      FROM
        user_actions
      GROUP BY
        date,
        user_id
    ) t1
  WHERE
    orders > 1
  GROUP BY
    date
),
pay_users AS (
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
)
SELECT
  p.date,
  ROUND(
    (
      u_o.user_who_have_one_order :: numeric / p.paying_users
    ) * 100,
    2
  ) AS single_order_users_share,
  ROUND(
    (
      u_m.user_who_have_more_one_order :: numeric / p.paying_users
    ) * 100,
    2
  ) AS several_orders_users_share
FROM
  pay_users AS p
  LEFT JOIN user_one_order AS u_o USING(date)
  LEFT JOIN user_who_have_more_one_order AS u_m USING(date)
ORDER BY
  p.date ASC