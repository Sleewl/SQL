SELECT
  hour :: int,
  successful_orders,
  canceled_orders,
  ROUND(canceled_orders :: numeric / general_orders, 3) AS cancel_rate
FROM(
    SELECT
      EXTRACT(
        hour
        FROM
          creation_time
      ) AS hour,
      COUNT(DISTINCT order_id) FILTER (
        WHERE
          order_id IN (
            SELECT
              order_id
            FROM
              courier_actions
            WHERE
              action = 'deliver_order'
          )
      ) AS successful_orders,
      COUNT(DISTINCT order_id) FILTER (
        WHERE
          order_id IN (
            SELECT
              order_id
            FROM
              user_actions
            WHERE
              action = 'cancel_order'
          )
      ) AS canceled_orders,
      COUNT(DISTINCT order_id) FILTER (
        WHERE
          order_id IN (
            SELECT
              order_id
            FROM
              user_actions
            WHERE
              action = 'create_order'
          )
      ) AS general_orders
    FROM
      orders
    GROUP BY
      hour
  ) t
ORDER BY
  hour ASC