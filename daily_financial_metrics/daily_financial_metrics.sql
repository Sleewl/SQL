WITH 
valid_order_items AS (
  SELECT
    o.order_id,
    o.creation_time::date AS date,
    pid.product_id
  FROM orders o
  CROSS JOIN LATERAL unnest(o.product_ids) AS pid(product_id)
  WHERE NOT EXISTS (
    SELECT 1
      FROM user_actions ua
     WHERE ua.order_id = o.order_id
       AND ua.action = 'cancel_order'
  )
),

order_products AS (
  SELECT
    voi.date,
    p.product_id,
    p.name,
    p.price
  FROM valid_order_items voi
  JOIN products p ON p.product_id = voi.product_id
),

revenue_per_day AS (
  SELECT
    date,
    SUM(price) AS revenue
  FROM order_products
  GROUP BY date
),

tax_per_day AS (
  SELECT
    date,
    SUM(
      ROUND(
        price
        * CASE
            WHEN LOWER(name) = ANY(ARRAY[
              'сахар','сухарики','сушки','семечки','масло льняное','виноград',
              'масло оливковое','арбуз','батон','йогурт','сливки','гречка',
              'овсянка','макароны','баранина','апельсины','бублики','хлеб',
              'горох','сметана','рыба копченая','мука','шпроты','сосиски',
              'свинина','рис','масло кунжутное','сгущенка','ананас','говядина',
              'соль','рыба вяленая','масло подсолнечное','яблоки','груши',
              'лепешка','молоко','курица','лаваш','вафли','мандарины'
            ])
            THEN 0.10 / 1.10
            ELSE 0.20 / 1.20
          END
      , 2)
    ) AS tax
  FROM order_products
  GROUP BY date
),

assembled_orders AS (
  SELECT
    creation_time::date AS date,
    COUNT(*) AS assembled_count
  FROM orders o
  WHERE NOT EXISTS (
    SELECT 1
      FROM user_actions ua
     WHERE ua.order_id = o.order_id
       AND ua.action = 'cancel_order'
  )
  GROUP BY 1
),

delivered_orders AS (
  SELECT
    time::date AS date,
    COUNT(*) AS delivered_count
  FROM courier_actions
  WHERE action = 'deliver_order'
  GROUP BY 1
),

bonus_couriers AS (
  SELECT
    date,
    COUNT(*) AS courier_with_bonus
  FROM (
    SELECT
      courier_id,
      time::date AS date,
      COUNT(*) AS cnt
    FROM courier_actions
    WHERE action = 'deliver_order'
    GROUP BY courier_id, time::date
    HAVING COUNT(*) >= 5
  ) t
  GROUP BY 1
),

costs_per_day AS (
  SELECT
    a.date,
    1.0 * (
      CASE WHEN a.date < '2022-09-01' THEN 120000 ELSE 150000 END
      + (CASE WHEN a.date < '2022-09-01' THEN 140 ELSE 115 END) * a.assembled_count
      + 150 * COALESCE(d.delivered_count, 0)
      + (CASE WHEN a.date < '2022-09-01' THEN 400 ELSE 500 END)
        * COALESCE(b.courier_with_bonus, 0)
    ) AS costs
  FROM assembled_orders a
  LEFT JOIN delivered_orders d ON d.date = a.date
  LEFT JOIN bonus_couriers   b ON b.date = a.date
),

daily AS (
  SELECT
    r.date,
    r.revenue,
    c.costs,
    t.tax,
    r.revenue - c.costs - t.tax AS gross_profit
  FROM revenue_per_day r
  JOIN costs_per_day    c USING (date)
  JOIN tax_per_day      t USING (date)
),

cum AS (
  SELECT
    date,
    revenue,
    costs,
    tax,
    gross_profit,
    SUM(revenue)      OVER (ORDER BY date) AS total_revenue,
    SUM(costs)        OVER (ORDER BY date) AS total_costs,
    SUM(tax)          OVER (ORDER BY date) AS total_tax,
    SUM(gross_profit) OVER (ORDER BY date) AS total_gross_profit
  FROM daily
)

SELECT
  date,
  revenue,
  costs,
  tax,
  gross_profit,
  total_revenue,
  total_costs,
  total_tax,
  total_gross_profit,
  ROUND(gross_profit * 100.0 / NULLIF(revenue,      0), 2) AS gross_profit_ratio,
  ROUND(total_gross_profit * 100.0 / NULLIF(total_revenue, 0), 2) AS total_gross_profit_ratio
FROM cum
ORDER BY date;
