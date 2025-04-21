with users_first as (SELECT min(time)::date as date,
                            user_id
                     FROM   user_actions
                     GROUP BY user_id), all_revenue as (SELECT o.creation_time::date as date,
                                          sum(p.price) as revenue
                                   FROM   orders o cross join unnest(o.product_ids) as pr_id join products p
                                           ON pr_id = p.product_id
                                   WHERE  o.order_id not in (SELECT order_id
                                                             FROM   user_actions
                                                             WHERE  action = 'cancel_order')
                                   GROUP BY o.creation_time::date), revenue_new_users as (SELECT o.creation_time::date as date,
                                                              sum(p.price) as new_users_revenue
                                                       FROM   orders o join user_actions ua
                                                               ON ua.order_id = o.order_id and
                                                                  ua.action = 'create_order' join users_first uf
                                                               ON uf.user_id = ua.user_id and
                                                                  uf.date = o.creation_time::date cross join unnest(o.product_ids) as pr_id join products p
                                                               ON pr_id = p.product_id
                                                       WHERE  o.order_id not in (SELECT order_id
                                                                                 FROM   user_actions
                                                                                 WHERE  action = 'cancel_order')
                                                       GROUP BY o.creation_time::date)
SELECT ar.date,
       ar.revenue,
       rnu.new_users_revenue,
       round(rnu.new_users_revenue::decimal / ar.revenue * 100 ,
             2) as new_users_revenue_share,
       round((ar.revenue - rnu.new_users_revenue)::decimal / ar.revenue * 100 ,
             2) as old_users_revenue_share
FROM   all_revenue ar
    LEFT JOIN revenue_new_users rnu
        ON rnu.date = ar.date
ORDER BY ar.date;