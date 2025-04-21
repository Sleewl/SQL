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
),
new_users AS (
  SELECT
    MIN(time) :: date AS date,
    user_id
  FROM
    user_actions
  GROUP BY
    user_id
),
new_paying_users AS (
  SELECT
    MIN(time) :: date AS date,
    user_id
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
running AS (
  SELECT
    d.date,
    (
      SELECT
        COUNT(*)
      FROM
        new_users nu
      WHERE
        nu.date = d.date
    ) AS new_users,
    (
      SELECT
        COUNT(*)
      FROM
        new_paying_users pu
      WHERE
        pu.date = d.date
    ) AS new_paying_users
  FROM
    (
      SELECT
        date
      FROM
        new_users
      UNION
      SELECT
        date
      FROM
        new_paying_users
    ) AS d
  ORDER BY
    d.date
)
SELECT
  rpd.date AS date,
  round(
    sum(revenue) OVER (
      ORDER BY
        date
    ) :: decimal / sum(new_users) OVER (
      ORDER BY
        date
    ),
    2
  ) as running_arpu,
  round(
    sum(revenue) OVER (
      ORDER BY
        date
    ) :: decimal / sum(new_paying_users) OVER (
      ORDER BY
        date
    ),
    2
  ) as running_arppu,
  round(
    sum(revenue) OVER (
      ORDER BY
        date
    ) :: decimal / sum(all_orders) OVER (
      ORDER BY
        date
    ),
    2
  ) as running_aov
FROM
  revenue_per_day AS rpd
  LEFT JOIN all_users AS au USING(date)
  LEFT JOIN paying_users AS pu USING(date)
  LEFT JOIN avg_order_value AS aov USING(date)
  LEFT JOIN running AS r USING(date)
ORDER BY
  date ASC