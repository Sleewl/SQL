with all_users as (SELECT time::date as date,
                          count(distinct user_id) as users
                   FROM   user_actions
                   WHERE  time::date between '2022-08-26'
                      and '2022-09-08'
                   GROUP BY date), paying_users as (SELECT time::date as date,
                                        count(distinct user_id) filter (WHERE action = 'create_order' and order_id not in (SELECT order_id
                                                                                                                    FROM   user_actions
                                                                                                                    WHERE  action = 'cancel_order')) as pay_users
                                 FROM   user_actions
                                 WHERE  time::date between '2022-08-26'
                                    and '2022-09-08'
                                 GROUP BY date), avg_order_value as (SELECT time::date as date,
                                           count(distinct order_id) filter (WHERE action = 'create_order' and order_id not in (SELECT order_id
                                                                                                                        FROM   user_actions
                                                                                                                        WHERE  action = 'cancel_order')) as all_orders
                                    FROM   user_actions
                                    WHERE  time::date between '2022-08-26'
                                       and '2022-09-08'
                                    GROUP BY date), revenue_per_day as (SELECT o.creation_time::date as date,
                                           sum(p.price) as revenue
                                    FROM   orders o cross join unnest(o.product_ids) as pr_id join products p
                                            ON pr_id = p.product_id
                                    WHERE  o.creation_time::date between '2022-08-26'
                                       and '2022-09-08'
                                       and o.order_id not in (SELECT order_id
                                                           FROM   user_actions
                                                           WHERE  action = 'cancel_order')
                                    GROUP BY o.creation_time::date), weekdays as (SELECT to_char(rpd.date, 'Day') as weekday,
                                                     date_part('isodow', rpd.date) as weekday_number,
                                                     array_agg(rpd.date) as dates
                                              FROM   revenue_per_day rpd
                                              GROUP BY 1, 2 having count(*) = 2)
SELECT w.weekday,
       w.weekday_number,
       round((SELECT sum(rpd2.revenue)
       FROM   revenue_per_day rpd2
       WHERE  rpd2.date = any(w.dates))::numeric / (SELECT count(distinct ua.user_id)
                                             FROM   user_actions ua
                                             WHERE  ua.time::date = any(w.dates)), 2) as arpu, round((SELECT sum(rpd2.revenue)
                                                         FROM   revenue_per_day rpd2
                                                         WHERE  rpd2.date = any(w.dates))::numeric / (SELECT count(distinct ua2.user_id)
                                             FROM   user_actions ua2
                                             WHERE  ua2.action = 'create_order'
                                                and ua2.order_id not in (SELECT order_id
                                                                      FROM   user_actions
                                                                      WHERE  action = 'cancel_order')
                                                and ua2.time::date = any(w.dates)), 2) as arppu, round((SELECT sum(rpd2.revenue)
                                                        FROM   revenue_per_day rpd2
                                                        WHERE  rpd2.date = any(w.dates))::numeric / (SELECT count(distinct ua3.order_id)
                                             FROM   user_actions ua3
                                             WHERE  ua3.action = 'create_order'
                                                and ua3.order_id not in (SELECT order_id
                                                                      FROM   user_actions
                                                                      WHERE  action = 'cancel_order')
                                                and ua3.time::date = any(w.dates)), 2) as aov
FROM   weekdays w
ORDER BY w.weekday_number;