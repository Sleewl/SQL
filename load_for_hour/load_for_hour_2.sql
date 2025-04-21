SELECT hour,
       successful_orders,
       canceled_orders,
       round(canceled_orders::decimal / (successful_orders + canceled_orders),
             3) as cancel_rate
FROM   (SELECT date_part('hour', creation_time)::int as hour,
               count(order_id) as successful_orders
        FROM   orders
        WHERE  order_id not in (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')
        GROUP BY hour) t1
    LEFT JOIN (SELECT date_part('hour', creation_time)::int as hour,
                      count(order_id) as canceled_orders
               FROM   orders
               WHERE  order_id in (SELECT order_id
                                   FROM   user_actions
                                   WHERE  action = 'cancel_order')
               GROUP BY hour) t2 using (hour)
ORDER BY hour