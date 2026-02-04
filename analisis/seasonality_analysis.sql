USE marketing_analysis;
GO

-- 1. ÌÅÑß×ÍÀß ÄÈÍÀÌÈÊÀ ÏÐÎÄÀÆ
PRINT '=== 1. ÌÅÑß×ÍÀß ÄÈÍÀÌÈÊÀ ÏÐÎÄÀÆ ===';
SELECT 
    year,
    month_num,
    month_name,
    channel,
    SUM(orders_count) as monthly_orders,
    SUM(daily_revenue) as monthly_revenue,
    SUM(daily_marketing_cost) as monthly_cost,
    SUM(daily_profit) as monthly_profit,
    ROUND(AVG(avg_order_value), 2) as monthly_avg_order_value,
    ROUND(SUM(daily_profit) / NULLIF(SUM(daily_marketing_cost), 0) * 100, 2) as monthly_roi,
    ROUND(SUM(daily_revenue) / NULLIF(SUM(orders_count), 0), 2) as revenue_per_order,
    LAG(SUM(daily_revenue)) OVER (PARTITION BY channel ORDER BY year, month_num) as prev_month_revenue,
    ROUND((SUM(daily_revenue) - LAG(SUM(daily_revenue)) OVER (PARTITION BY channel ORDER BY year, month_num)) / 
          NULLIF(LAG(SUM(daily_revenue)) OVER (PARTITION BY channel ORDER BY year, month_num), 0) * 100, 2) as revenue_growth_pct
FROM vw_daily_sales
GROUP BY year, month_num, month_name, channel
ORDER BY year, month_num, channel;
GO

-- 2. ÑÅÇÎÍÍÎÑÒÜ ÏÎ ÄÍßÌ ÍÅÄÅËÈ
PRINT '=== 2. ÀÍÀËÈÇ ÏÎ ÄÍßÌ ÍÅÄÅËÈ ===';
SELECT 
    DATEPART(WEEKDAY, o.order_date) as day_of_week,
    DATENAME(WEEKDAY, o.order_date) as day_name,
    mt.channel,
    COUNT(DISTINCT o.order_id) as orders_count,
    ROUND(SUM(o.total_amount), 2) as total_revenue,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    COUNT(DISTINCT o.user_id) as unique_customers,
    ROUND(SUM(o.total_amount) / COUNT(DISTINCT o.user_id), 2) as revenue_per_customer
FROM orders o
JOIN marketing_touch mt ON o.user_id = mt.user_id
WHERE o.status = 'completed'
GROUP BY 
    DATEPART(WEEKDAY, o.order_date),
    DATENAME(WEEKDAY, o.order_date),
    mt.channel
ORDER BY day_of_week, total_revenue DESC;
GO

-- 3. ×ÀÑÎÂÛÅ ÏÀÒÒÅÐÍÛ ÀÊÒÈÂÍÎÑÒÈ
PRINT '=== 3. ÀÊÒÈÂÍÎÑÒÜ ÏÎ ×ÀÑÀÌ ÑÓÒÎÊ ===';
SELECT 
    DATEPART(HOUR, o.order_date) as hour_of_day,
    mt.channel,
    COUNT(DISTINCT o.order_id) as orders_count,
    ROUND(SUM(o.total_amount), 2) as hourly_revenue,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    CASE 
        WHEN DATEPART(HOUR, o.order_date) BETWEEN 9 AND 17 THEN 'Ðàáî÷èå ÷àñû'
        WHEN DATEPART(HOUR, o.order_date) BETWEEN 18 AND 22 THEN 'Âå÷åð'
        WHEN DATEPART(HOUR, o.order_date) BETWEEN 23 AND 5 THEN 'Íî÷ü'
        ELSE 'Óòðî'
    END as time_segment
FROM orders o
JOIN marketing_touch mt ON o.user_id = mt.user_id
WHERE o.status = 'completed'
GROUP BY 
    DATEPART(HOUR, o.order_date),
    mt.channel,
    CASE 
        WHEN DATEPART(HOUR, o.order_date) BETWEEN 9 AND 17 THEN 'Ðàáî÷èå ÷àñû'
        WHEN DATEPART(HOUR, o.order_date) BETWEEN 18 AND 22 THEN 'Âå÷åð'
        WHEN DATEPART(HOUR, o.order_date) BETWEEN 23 AND 5 THEN 'Íî÷ü'
        ELSE 'Óòðî'
    END
ORDER BY hour_of_day, hourly_revenue DESC;
GO

-- 4. ÊÂÀÐÒÀËÜÍÀß ÄÈÍÀÌÈÊÀ
PRINT '=== 4. ÊÂÀÐÒÀËÜÍÛÉ ÀÍÀËÈÇ ===';
WITH quarterly_stats AS (
    SELECT 
        year,
        quarter,
        channel,
        SUM(daily_revenue) as quarterly_revenue,
        SUM(daily_marketing_cost) as quarterly_cost,
        SUM(orders_count) as quarterly_orders,
        SUM(daily_profit) as quarterly_profit
    FROM vw_daily_sales
    GROUP BY year, quarter, channel
)
SELECT 
    year,
    quarter,
    channel,
    quarterly_revenue,
    quarterly_cost,
    quarterly_orders,
    quarterly_profit,
    ROUND(quarterly_profit / NULLIF(quarterly_cost, 0) * 100, 2) as quarterly_roi,
    ROUND(quarterly_revenue / quarterly_orders, 2) as avg_order_value,
    LAG(quarterly_revenue) OVER (PARTITION BY channel ORDER BY year, quarter) as prev_quarter_revenue,
    ROUND((quarterly_revenue - LAG(quarterly_revenue) OVER (PARTITION BY channel ORDER BY year, quarter)) / 
          NULLIF(LAG(quarterly_revenue) OVER (PARTITION BY channel ORDER BY year, quarter), 0) * 100, 2) as revenue_growth_qoq
FROM quarterly_stats
ORDER BY year, quarter, quarterly_roi DESC;
GO

-- 5. ÑÐÀÂÍÅÍÈÅ Ñ ÏÐÅÄÛÄÓÙÈÌÈ ÏÅÐÈÎÄÀÌÈ
PRINT '=== 5. ÑÐÀÂÍÈÒÅËÜÍÛÉ ÀÍÀËÈÇ ===';
WITH monthly_comparison AS (
    SELECT 
        year,
        month_num,
        month_name,
        channel,
        SUM(daily_revenue) as current_revenue,
        SUM(daily_marketing_cost) as current_cost,
        SUM(orders_count) as current_orders
    FROM vw_daily_sales
    GROUP BY year, month_num, month_name, channel
)
SELECT 
    mc1.channel,
    mc1.year as current_year,
    mc1.month_name as current_month,
    mc1.current_revenue,
    mc1.current_orders,
    mc2.year as prev_year,
    mc2.month_name as prev_month,
    mc2.current_revenue as prev_revenue,
    mc2.current_orders as prev_orders,
    ROUND((mc1.current_revenue - mc2.current_revenue) / NULLIF(mc2.current_revenue, 0) * 100, 2) as revenue_growth_yoy,
    ROUND((mc1.current_orders - mc2.current_orders) / NULLIF(mc2.current_orders, 0) * 100, 2) as orders_growth_yoy,
    CASE 
        WHEN (mc1.current_revenue - mc2.current_revenue) / NULLIF(mc2.current_revenue, 0) > 0.2 THEN 'Ñèëüíûé ðîñò'
        WHEN (mc1.current_revenue - mc2.current_revenue) / NULLIF(mc2.current_revenue, 0) > 0 THEN 'Óìåðåííûé ðîñò'
        ELSE 'Ñíèæåíèå'
    END as growth_category
FROM monthly_comparison mc1
LEFT JOIN monthly_comparison mc2 ON mc1.channel = mc2.channel 
    AND mc1.month_num = mc2.month_num 
    AND mc1.year = mc2.year + 1
WHERE mc1.year = 2023
ORDER BY revenue_growth_yoy DESC;
GO

-- 6. ÒÐÅÍÄÛ ÏÎ ÊÀÒÅÃÎÐÈßÌ ÒÎÂÀÐÎÂ
PRINT '=== 6. ÑÅÇÎÍÍÎÑÒÜ ÏÎ ÊÀÒÅÃÎÐÈßÌ ÒÎÂÀÐÎÂ ===';
SELECT 
    p.category,
    DATEPART(MONTH, o.order_date) as month,
    DATENAME(MONTH, o.order_date) as month_name,
    COUNT(DISTINCT o.order_id) as orders_count,
    SUM(oi.quantity) as units_sold,
    ROUND(SUM(oi.quantity * oi.price), 2) as category_revenue,
    ROUND(AVG(oi.quantity * oi.price), 2) as avg_order_value,
    ROUND(SUM(oi.quantity * (oi.price - oi.cost)), 2) as category_profit,
    RANK() OVER (PARTITION BY p.category ORDER BY SUM(oi.quantity * oi.price) DESC) as month_rank_in_category
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.status = 'completed'
    AND o.order_date >= '2023-01-01'
GROUP BY p.category, DATEPART(MONTH, o.order_date), DATENAME(MONTH, o.order_date)
ORDER BY p.category, month;
GO