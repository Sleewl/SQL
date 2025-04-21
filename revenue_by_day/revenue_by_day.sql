SELECT
  date,
  revenue,
  total_revenue,
  ROUND(
    LAG(revenue_change) OVER(
      ORDER BY
        date
    ),
    2
  ) AS revenue_change
FROM(
    SELECT
      date,
      revenue,
      SUM(revenue) OVER(
        ORDER BY
          date
      ) AS total_revenue,
      (
        (
          (
            LEAD(revenue) OVER(
              ORDER BY
                date
            )
          ) - revenue
        ) * 100.0
      ) :: numeric / revenue AS revenue_change
    FROM(
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
      ) t
  ) t1