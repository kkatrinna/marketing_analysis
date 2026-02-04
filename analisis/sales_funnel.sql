USE marketing_analysis;
GO

-- 1. ОБЩАЯ ВОРОНКА ПРОДАЖ
PRINT '=== 1. ОБЩАЯ ВОРОНКА ПРОДАЖ ===';
SELECT 
    'Все каналы' as segment,
    touched_users as "Касания",
    visited_website as "Посетили сайт",
    made_purchase as "Совершили покупку",
    visit_rate_percent as "Конверсия в посещение, %",
    conversion_rate_percent as "Конверсия в покупку, %",
    ROUND(CAST(made_purchase AS FLOAT) / touched_users * 100, 2) as "Общая конверсия, %"
FROM vw_sales_funnel
WHERE channel = 'context_ads' -- Пример для одного канала, можно изменить
UNION ALL
SELECT 
    'Все каналы (сумма)' as segment,
    SUM(touched_users),
    SUM(visited_website),
    SUM(made_purchase),
    ROUND(CAST(SUM(visited_website) AS FLOAT) / SUM(touched_users) * 100, 2),
    ROUND(CAST(SUM(made_purchase) AS FLOAT) / SUM(visited_website) * 100, 2),
    ROUND(CAST(SUM(made_purchase) AS FLOAT) / SUM(touched_users) * 100, 2)
FROM vw_sales_funnel;
GO

-- 2. ВОРОНКА ПО КАНАЛАМ
PRINT '=== 2. ВОРОНКА ПРОДАЖ ПО КАНАЛАМ ===';
SELECT 
    channel as "Канал",
    touched_users as "Касания",
    visited_website as "Посещения",
    made_purchase as "Покупки",
    visit_rate_percent as "Посещение/Касание, %",
    conversion_rate_percent as "Покупка/Посещение, %",
    ROUND(CAST(made_purchase AS FLOAT) / touched_users * 100, 2) as "Покупка/Касание, %",
    ROW_NUMBER() OVER (ORDER BY conversion_rate_percent DESC) as rank_conversion,
    CASE 
        WHEN conversion_rate_percent > 40 THEN 'Высокая конверсия'
        WHEN conversion_rate_percent > 25 THEN 'Средняя конверсия'
        ELSE 'Низкая конверсия'
    END as conversion_category
FROM vw_sales_funnel
ORDER BY conversion_rate_percent DESC;
GO

-- 3. ДЕТАЛЬНАЯ ВОРОНКА С ВРЕМЕННЫМИ ИНТЕРВАЛАМИ
PRINT '=== 3. ВОРОНКА С ВРЕМЕННЫМИ ИНТЕРВАЛАМИ ===';
WITH detailed_funnel AS (
    SELECT 
        mt.channel,
        mt.user_id,
        mt.touch_date,
        MIN(s.session_date) as first_session,
        MIN(o.order_date) as first_order,
        DATEDIFF(HOUR, mt.touch_date, MIN(s.session_date)) as hours_to_session,
        DATEDIFF(HOUR, MIN(s.session_date), MIN(o.order_date)) as hours_to_purchase
    FROM marketing_touch mt
    LEFT JOIN sessions s ON mt.user_id = s.user_id 
        AND s.session_date >= mt.touch_date
        AND s.session_date <= DATEADD(DAY, 7, mt.touch_date)
    LEFT JOIN orders o ON mt.user_id = o.user_id 
        AND o.status = 'completed'
        AND o.order_date >= mt.touch_date
        AND o.order_date <= DATEADD(DAY, 30, mt.touch_date)
    GROUP BY mt.channel, mt.user_id, mt.touch_date
)
SELECT 
    channel,
    COUNT(DISTINCT user_id) as total_users,
    COUNT(DISTINCT CASE WHEN first_session IS NOT NULL THEN user_id END) as visited,
    COUNT(DISTINCT CASE WHEN first_order IS NOT NULL THEN user_id END) as purchased,
    -- Время до первого действия
    ROUND(AVG(CASE WHEN hours_to_session IS NOT NULL THEN hours_to_session END), 1) as avg_hours_to_session,
    ROUND(AVG(CASE WHEN hours_to_purchase IS NOT NULL THEN hours_to_purchase END), 1) as avg_hours_to_purchase,
    -- Процент пользователей по временным интервалам
    ROUND(CAST(COUNT(DISTINCT CASE WHEN hours_to_session <= 1 THEN user_id END) AS FLOAT) / 
          COUNT(DISTINCT CASE WHEN first_session IS NOT NULL THEN user_id END) * 100, 2) as session_within_1h,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN hours_to_purchase <= 24 THEN user_id END) AS FLOAT) / 
          COUNT(DISTINCT CASE WHEN first_order IS NOT NULL THEN user_id END) * 100, 2) as purchase_within_24h
FROM detailed_funnel
GROUP BY channel
ORDER BY avg_hours_to_purchase;
GO

-- 4. АНАЛИЗ МНОГОКАНАЛЬНОЙ ВОРОНКИ
PRINT '=== 4. МНОГОКАНАЛЬНЫЕ ВЗАИМОДЕЙСТВИЯ ===';
WITH user_journey AS (
    SELECT 
        o.user_id,
        STRING_AGG(DISTINCT mt.channel, ' → ') WITHIN GROUP (ORDER BY mt.touch_date) as journey_path,
        COUNT(DISTINCT mt.channel) as unique_channels,
        COUNT(DISTINCT mt.touch_id) as total_touches
    FROM orders o
    JOIN marketing_touch mt ON o.user_id = mt.user_id 
        AND mt.touch_date <= o.order_date
        AND mt.touch_date >= DATEADD(DAY, -30, o.order_date)
    WHERE o.status = 'completed'
    GROUP BY o.user_id
)
SELECT 
    CASE 
        WHEN unique_channels = 1 THEN 'Один канал'
        WHEN unique_channels = 2 THEN 'Два канала'
        WHEN unique_channels = 3 THEN 'Три канала'
        ELSE 'Более трех каналов'
    END as channel_count_category,
    COUNT(DISTINCT user_id) as customers,
    AVG(unique_channels) as avg_channels_per_customer,
    AVG(total_touches) as avg_touches_per_customer,
    -- Топ-5 путей
    (SELECT TOP 5 journey_path 
     FROM user_journey uj2 
     WHERE uj2.unique_channels = uj.unique_channels 
     GROUP BY journey_path 
     ORDER BY COUNT(*) DESC 
     FOR XML PATH('')) as top_journeys
FROM user_journey uj
GROUP BY 
    CASE 
        WHEN unique_channels = 1 THEN 'Один канал'
        WHEN unique_channels = 2 THEN 'Два канала'
        WHEN unique_channels = 3 THEN 'Три канала'
        ELSE 'Более трех каналов'
    END
ORDER BY customers DESC;
GO

-- 5. ТОЧКИ ОТТОКА В ВОРОНКЕ
PRINT '=== 5. АНАЛИЗ ТОЧЕК ОТТОКА ===';
WITH funnel_steps AS (
    SELECT 
        mt.channel,
        mt.user_id,
        CASE WHEN EXISTS (
            SELECT 1 FROM sessions s 
            WHERE s.user_id = mt.user_id 
            AND s.session_date BETWEEN mt.touch_date AND DATEADD(DAY, 7, mt.touch_date)
        ) THEN 1 ELSE 0 END as reached_session,
        CASE WHEN EXISTS (
            SELECT 1 FROM orders o 
            WHERE o.user_id = mt.user_id 
            AND o.status = 'completed'
            AND o.order_date BETWEEN mt.touch_date AND DATEADD(DAY, 30, mt.touch_date)
        ) THEN 1 ELSE 0 END as reached_purchase
    FROM marketing_touch mt
)
SELECT 
    channel,
    COUNT(DISTINCT user_id) as total_users,
    SUM(reached_session) as users_with_session,
    SUM(reached_purchase) as users_with_purchase,
    -- Отток на каждом этапе
    COUNT(DISTINCT user_id) - SUM(reached_session) as lost_before_session,
    SUM(reached_session) - SUM(reached_purchase) as lost_before_purchase,
    -- Процент оттока
    ROUND(CAST(COUNT(DISTINCT user_id) - SUM(reached_session) AS FLOAT) / COUNT(DISTINCT user_id) * 100, 2) as lost_before_session_pct,
    ROUND(CAST(SUM(reached_session) - SUM(reached_purchase) AS FLOAT) / NULLIF(SUM(reached_session), 0) * 100, 2) as lost_before_purchase_pct
FROM funnel_steps
GROUP BY channel
ORDER BY lost_before_session_pct DESC;
GO