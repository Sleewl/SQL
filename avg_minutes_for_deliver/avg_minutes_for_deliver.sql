SELECT
  date,
  AVG(
    EXTRACT(
      epoch
      FROM
        (deliver - accept)
    ) / 60.0
  ) :: INT AS minutes_to_deliver
FROM
  (
    SELECT
      order_id,
      (
        MIN(time) FILTER (
          WHERE
            action = 'accept_order'
        )
      ) :: DATE AS date,
      MIN(time) FILTER (
        WHERE
          action = 'accept_order'
      ) AS accept,
      MAX(time) FILTER (
        WHERE
          action = 'deliver_order'
      ) AS deliver
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
      order_id
  ) t
GROUP BY
  date
ORDER BY
  date ASC