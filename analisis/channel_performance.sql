USE marketing_analysis;
GO

PRINT '=== 1. Œ—ÕŒ¬Õ€≈ Ã≈“–» » œŒ  ¿Õ¿À¿Ã ===';
SELECT 
    channel,
    acquired_customers,
    avg_cac,
    avg_ltv_90d,
    ltv_cac_ratio,
    total_revenue_90d,
    total_marketing_cost,
    roi_percent,
    CASE 
        WHEN roi_percent > 100 THEN '¬˚ÒÓÍËÈ ROI'
        WHEN roi_percent > 30 THEN '’ÓÓ¯ËÈ ROI'
        WHEN roi_percent > 0 THEN 'ÕËÁÍËÈ ROI'
        ELSE 'ŒÚËˆ‡ÚÂÎ¸Ì˚È ROI'
    END as roi_category
FROM vw_channel_performance
ORDER BY roi_percent DESC;
GO

-- 2. ƒ≈“¿À‹Õ€… ¿Õ¿À»« CAC » LTV
PRINT '=== 2. ƒ≈“¿À»«»–Œ¬¿ÕÕ€… ¿Õ¿À»« CAC » LTV ===';
WITH channel_details AS (
    SELECT 
        mt.channel,
        COUNT(DISTINCT mt.user_id) as total_touched,
        COUNT(DISTINCT o.user_id) as converted_customers,
        ROUND(AVG(mt.ad_cost), 2) as avg_ad_cost,
        ROUND(SUM(mt.ad_cost) / NULLIF(COUNT(DISTINCT o.user_id), 0), 2) as cac_with_conversion,
        ROUND(AVG(o.total_amount), 2) as avg_order_value,
        ROUND(SUM(o.total_amount) / NULLIF(COUNT(DISTINCT o.user_id), 0), 2) as avg_revenue_per_customer
    FROM marketing_touch mt
    LEFT JOIN orders o ON mt.user_id = o.user_id 
        AND o.status = 'completed'
        AND o.order_date BETWEEN mt.touch_date AND DATEADD(DAY, 90, mt.touch_date)
    GROUP BY mt.channel
)
SELECT 
    cd.*,
    vcp.avg_ltv_90d,
    vcp.ltv_cac_ratio,
    ROUND(CAST(cd.converted_customers AS FLOAT) / cd.total_touched * 100, 2) as conversion_rate_percent,
    CASE 
        WHEN cd.cac_with_conversion < vcp.avg_ltv_90d * 0.3 THEN 'ŒÔÚËÏ‡Î¸Ì˚È CAC'
        WHEN cd.cac_with_conversion < vcp.avg_ltv_90d * 0.5 THEN 'œËÂÏÎÂÏ˚È CAC'
        ELSE '¬˚ÒÓÍËÈ CAC'
    END as cac_assessment
FROM channel_details cd
JOIN vw_channel_performance vcp ON cd.channel = vcp.channel
ORDER BY vcp.ltv_cac_ratio DESC;
GO

-- 3. ¿Õ¿À»« –ŒÃ¿ÕŒ¬ œŒ  ¿Ãœ¿Õ»ﬂÃ
PRINT '=== 3. ¿Õ¿À»« ›‘‘≈ “»¬ÕŒ—“»  ¿Ãœ¿Õ»… ===';
SELECT 
    mt.campaign_name,
    mt.channel,
    COUNT(DISTINCT mt.user_id) as users_touched,
    COUNT(DISTINCT o.order_id) as orders_generated,
    ROUND(SUM(o.total_amount), 2) as total_revenue,
    ROUND(AVG(mt.ad_cost), 2) as avg_ad_cost,
    ROUND(SUM(o.total_amount) / NULLIF(COUNT(DISTINCT mt.user_id), 0), 2) as revenue_per_touch,
    ROUND(SUM(o.total_amount) / NULLIF(SUM(mt.ad_cost), 0), 2) as romi
FROM marketing_touch mt
LEFT JOIN orders o ON mt.user_id = o.user_id 
    AND o.status = 'completed'
    AND o.order_date BETWEEN mt.touch_date AND DATEADD(DAY, 30, mt.touch_date)
GROUP BY mt.campaign_name, mt.channel
HAVING COUNT(DISTINCT mt.user_id) > 10
ORDER BY romi DESC;
GO

-- 4. ¿Õ¿À»« ”—“–Œ…—“¬
PRINT '=== 4. ›‘‘≈ “»¬ÕŒ—“‹ œŒ “»œ¿Ã ”—“–Œ…—“¬ ===';
SELECT 
    mt.device_type,
    mt.channel,
    COUNT(DISTINCT mt.user_id) as users,
    COUNT(DISTINCT o.order_id) as orders,
    ROUND(CAST(COUNT(DISTINCT o.order_id) AS FLOAT) / COUNT(DISTINCT mt.user_id) * 100, 2) as conversion_rate,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    ROUND(SUM(o.total_amount), 2) as total_revenue
FROM marketing_touch mt
LEFT JOIN orders o ON mt.user_id = o.user_id 
    AND o.status = 'completed'
GROUP BY mt.device_type, mt.channel
ORDER BY conversion_rate DESC;
GO

-- 5. ¬–≈Ã≈ÕÕ€≈ “–≈Õƒ€ ›‘‘≈ “»¬ÕŒ—“»
PRINT '=== 5. ƒ»Õ¿Ã» ¿ ›‘‘≈ “»¬ÕŒ—“» œŒ Ã≈—ﬂ÷¿Ã ===';
SELECT 
    DATEPART(YEAR, o.order_date) as year,
    DATEPART(MONTH, o.order_date) as month,
    DATENAME(MONTH, o.order_date) as month_name,
    mt.channel,
    COUNT(DISTINCT o.order_id) as monthly_orders,
    ROUND(SUM(o.total_amount), 2) as monthly_revenue,
    ROUND(SUM(mc.total_cost), 2) as monthly_cost,
    ROUND((SUM(o.total_amount) - SUM(mc.total_cost)) / NULLIF(SUM(mc.total_cost), 0) * 100, 2) as monthly_roi,
    ROUND(AVG(o.total_amount), 2) as avg_order_value
FROM orders o
JOIN marketing_touch mt ON o.user_id = mt.user_id
LEFT JOIN marketing_costs mc ON mt.channel = mc.channel 
    AND DATEPART(YEAR, mc.cost_date) = DATEPART(YEAR, o.order_date)
    AND DATEPART(MONTH, mc.cost_date) = DATEPART(MONTH, o.order_date)
WHERE o.status = 'completed'
    AND o.order_date >= '2023-01-01'
GROUP BY 
    DATEPART(YEAR, o.order_date),
    DATEPART(MONTH, o.order_date),
    DATENAME(MONTH, o.order_date),
    mt.channel
ORDER BY year, month, monthly_roi DESC;
GO