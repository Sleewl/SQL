WITH first_actions AS (
  SELECT
    user_id,
    MIN(time::date) AS start_date
  FROM user_actions
  GROUP BY user_id
),

cohort_activity AS (
  SELECT
    fa.user_id,
    fa.start_date,
    ua.time::date        AS event_date
  FROM user_actions ua
  JOIN first_actions fa USING(user_id)
),

cohort_sizes AS (
  SELECT
    start_date,
    COUNT(DISTINCT user_id) AS cohort_size
  FROM first_actions
  GROUP BY start_date
),

daily_active AS (
  SELECT
    start_date,
    event_date,
    COUNT(DISTINCT user_id) AS active_users
  FROM cohort_activity
  GROUP BY start_date, event_date
),

retention_calc AS (
  SELECT
    ds.start_date,
    ds.event_date,
    ds.active_users,
    cs.cohort_size,
    CAST(ds.active_users AS numeric) / cs.cohort_size AS retention_raw
  FROM daily_active ds
  JOIN cohort_sizes cs USING(start_date)
)

SELECT
  date_trunc('month', start_date)::date    AS start_month,
  start_date,
  (event_date - start_date)               AS day_number,
  ROUND(retention_raw, 2)                 AS retention
FROM retention_calc
ORDER BY start_date, day_number;
