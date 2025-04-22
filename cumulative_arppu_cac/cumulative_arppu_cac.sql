WITH 
    campaign_users AS (
        SELECT user_id, 'Кампания № 1' AS ads_campaign
        FROM (VALUES
            (8631),(8632),(8638),(8643),(8657),(8673),(8706),(8707),(8715),(8723),
            (8732),(8739),(8741),(8750),(8751),(8752),(8770),(8774),(8788),(8791),
            (8804),(8810),(8815),(8828),(8830),(8845),(8853),(8859),(8867),(8869),
            (8876),(8879),(8883),(8896),(8909),(8911),(8933),(8940),(8972),(8976),
            (8988),(8990),(9002),(9004),(9009),(9019),(9020),(9035),(9036),(9061),
            (9069),(9071),(9075),(9081),(9085),(9089),(9108),(9113),(9144),(9145),
            (9146),(9162),(9165),(9167),(9175),(9180),(9182),(9197),(9198),(9210),
            (9223),(9251),(9257),(9278),(9287),(9291),(9313),(9317),(9321),(9334),
            (9351),(9391),(9398),(9414),(9420),(9422),(9431),(9450),(9451),(9454),
            (9472),(9476),(9478),(9491),(9494),(9505),(9512),(9518),(9524),(9526),
            (9528),(9531),(9535),(9550),(9559),(9561),(9562),(9599),(9603),(9605),
            (9611),(9612),(9615),(9625),(9633),(9652),(9654),(9655),(9660),(9662),
            (9667),(9677),(9679),(9689),(9695),(9720),(9726),(9739),(9740),(9762),
            (9778),(9786),(9794),(9804),(9810),(9813),(9818),(9828),(9831),(9836),
            (9838),(9845),(9871),(9887),(9891),(9896),(9897),(9916),(9945),(9960),
            (9963),(9965),(9968),(9971),(9993),(9998),(9999),(10001),(10013),(10016),
            (10023),(10030),(10051),(10057),(10064),(10082),(10103),(10105),(10122),(10134),
            (10135)
        ) AS t(user_id)
        UNION ALL
        SELECT user_id, 'Кампания № 2' AS ads_campaign
        FROM (VALUES
            (8629),(8630),(8644),(8646),(8650),(8655),(8659),(8660),(8663),(8665),
            (8670),(8675),(8680),(8681),(8682),(8683),(8694),(8697),(8700),(8704),
            (8712),(8713),(8719),(8729),(8733),(8742),(8748),(8754),(8771),(8794),
            (8795),(8798),(8803),(8805),(8806),(8812),(8814),(8825),(8827),(8838),
            (8849),(8851),(8854),(8855),(8870),(8878),(8882),(8886),(8890),(8893),
            (8900),(8902),(8913),(8916),(8923),(8929),(8935),(8942),(8943),(8949),
            (8953),(8955),(8966),(8968),(8971),(8973),(8980),(8995),(8999),(9000),
            (9007),(9013),(9041),(9042),(9047),(9064),(9068),(9077),(9082),(9083),
            (9095),(9103),(9109),(9117),(9123),(9127),(9131),(9137),(9140),(9149),
            (9161),(9179),(9181),(9183),(9185),(9190),(9196),(9203),(9207),(9226),
            (9227),(9229),(9230),(9231),(9250),(9255),(9259),(9267),(9273),(9281),
            (9282),(9289),(9292),(9303),(9310),(9312),(9315),(9327),(9333),(9335),
            (9337),(9343),(9356),(9368),(9370),(9383),(9392),(9404),(9410),(9421),
            (9428),(9432),(9437),(9468),(9479),(9483),(9485),(9492),(9495),(9497),(9498),
            (9500),(9510),(9527),(9529),(9530),(9538),(9539),(9545),(9557),(9558),(9560),
            (9564),(9567),(9570),(9591),(9596),(9598),(9616),(9631),(9634),(9635),(9636),
            (9658),(9666),(9672),(9684),(9692),(9700),(9704),(9706),(9711),(9719),(9727),(9735),
            (9741),(9744),(9749),(9752),(9753),(9755),(9757),(9764),(9783),(9784),(9788),(9790),
            (9808),(9820),(9839),(9841),(9843),(9853),(9855),(9859),(9863),(9877),(9879),(9880),
            (9882),(9883),(9885),(9901),(9904),(9908),(9910),(9912),(9920),(9929),(9930),(9935),
            (9939),(9958),(9959),(9961),(9983),(10027),(10033),(10038),(10045),(10047),(10048),
            (10058),(10059),(10067),(10069),(10073),(10075),(10078),(10079),(10081),(10092),(10106),(10110),(10113),(10131)
        ) AS t(user_id)
    ),

    first_actions AS (
        SELECT
            cu.user_id,
            cu.ads_campaign,
            MIN(ua.time::date) AS start_date
        FROM campaign_users cu
        JOIN user_actions ua USING(user_id)
        GROUP BY cu.user_id, cu.ads_campaign
    ),

    order_revenue AS (
        SELECT
            o.order_id,
            SUM(p.price) AS revenue
        FROM orders o
        CROSS JOIN UNNEST(o.product_ids) AS pid
        JOIN products p ON p.product_id = pid
        GROUP BY o.order_id
    ),

    good_orders AS (
        SELECT DISTINCT ua.user_id, ua.order_id
        FROM user_actions ua
        WHERE ua.action = 'create_order'
          AND ua.order_id NOT IN (
              SELECT order_id
              FROM user_actions
              WHERE action = 'cancel_order'
          )
    ),

    valid_orders AS (
        SELECT
            go.user_id,
            go.order_id,
            o.creation_time::date AS order_date,
            orv.revenue
        FROM good_orders go
        JOIN orders o         ON o.order_id = go.order_id
        JOIN order_revenue orv ON orv.order_id = go.order_id
    ),

    orders_by_day AS (
        SELECT
            fa.ads_campaign,
            vo.user_id,
            (vo.order_date - fa.start_date) AS day,
            vo.revenue
        FROM first_actions fa
        JOIN valid_orders vo
          ON fa.user_id = vo.user_id
        WHERE vo.order_date >= fa.start_date
    ),

    daily_rev AS (
        SELECT
            ads_campaign,
            day,
            SUM(revenue) AS daily_revenue
        FROM orders_by_day
        GROUP BY ads_campaign, day
    ),

    cum_rev AS (
        SELECT
            ads_campaign,
            day,
            SUM(daily_revenue) OVER (
                PARTITION BY ads_campaign
                ORDER BY day
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_revenue
        FROM daily_rev
    ),

    cohort_size AS (
        SELECT
            fa.ads_campaign,
            COUNT(DISTINCT vo.user_id) AS customers
        FROM first_actions fa
        JOIN valid_orders vo
          ON fa.user_id = vo.user_id
         AND vo.order_date >= fa.start_date
        GROUP BY fa.ads_campaign
    ),

    cac_calc AS (
        SELECT
            cu.ads_campaign,
            ROUND(250000.0 / COUNT(DISTINCT ua.user_id), 2) AS cac
        FROM campaign_users cu
        JOIN user_actions ua
          ON cu.user_id = ua.user_id
         AND ua.action = 'create_order'
         AND ua.order_id NOT IN (
             SELECT order_id
             FROM user_actions
             WHERE action = 'cancel_order'
         )
        GROUP BY cu.ads_campaign
    )

SELECT
    cr.ads_campaign,
    'Day ' || cr.day                                 AS day,
    ROUND(cr.cumulative_revenue::numeric / cs.customers, 2) AS cumulative_arppu,
    cc.cac
FROM cum_rev cr
JOIN cohort_size cs  USING(ads_campaign)
JOIN cac_calc     cc USING(ads_campaign)
ORDER BY cr.ads_campaign, cr.day;
