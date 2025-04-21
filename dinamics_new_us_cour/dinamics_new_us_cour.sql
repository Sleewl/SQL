WITH users_first AS (
  SELECT
    MIN(time) :: date AS date,
    user_id
  FROM
    user_actions
  GROUP BY
    user_id
),
couriers_first AS (
  SELECT
    MIN(time) :: date AS date,
    courier_id
  FROM
    courier_actions
  GROUP BY
    courier_id
),
unioned AS (
  SELECT
    date,
    user_id,
    NULL AS courier_id
  FROM
    users_first
  UNION ALL
  SELECT
    date,
    NULL AS user_id,
    courier_id
  FROM
    couriers_first
),
running AS (
  SELECT
    date,
    COUNT(user_id) AS new_users,
    COUNT(courier_id) AS new_couriers
  FROM
    unioned
  GROUP BY
    date
  ORDER BY
    date
)
SELECT
  date,
  new_users,
  new_couriers,
  total_users :: INT,
  total_couriers :: INT,
  ROUND(new_users_change, 2) AS new_users_change,
  ROUND(new_couriers_change, 2) AS new_couriers_change,
  LAG(total_users_growth, 1) OVER(
    ORDER BY
      date
  ) AS total_users_growth,
  ROUND(
    LAG(total_couriers_growth, 1) OVER(
      ORDER BY
        date
    ),
    2
  ) AS total_couriers_growth
FROM(
    SELECT
      date,
      new_users,
      new_couriers,
      total_users,
      total_couriers,
      LAG(new_users_change, 1) OVER(
        ORDER BY
          date
      ) AS new_users_change,
      LAG(new_couriers_change) OVER(
        ORDER BY
          date
      ) AS new_couriers_change,
      (
        LEAD(total_users, 1) OVER(
          ORDER BY
            date
        ) - total_users
      ) * 100 / total_users AS total_users_growth,
      (
        LEAD(total_couriers, 1) OVER(
          ORDER BY
            date
        ) - total_couriers
      ) * 100 / total_couriers AS total_couriers_growth
    FROM(
        SELECT
          date,
          new_users,
          new_couriers,
          SUM(new_users) OVER(
            ORDER BY
              date
          ) AS total_users,
          SUM(new_couriers) OVER(
            ORDER BY
              date
          ) AS total_couriers,
          (
            LEAD(new_users, 1) OVER(
              ORDER BY
                date
            ) - new_users
          ) * 100.0 / new_users AS new_users_change,
          (
            LEAD(new_couriers, 1) OVER(
              ORDER BY
                date
            ) - new_couriers
          ) * 100.0 / new_couriers AS new_couriers_change
        FROM
          running
      ) t
  ) t1