
USE marketing_analysis;
GO

-- 1. —≈√Ã≈Õ“¿÷»ﬂ  À»≈Õ“Œ¬
PRINT '=== 1. —≈√Ã≈Õ“¿÷»ﬂ  À»≈Õ“Œ¬ ===';
SELECT 
    rfm_segment,
    COUNT(DISTINCT user_id) as customers_count,
    ROUND(CAST(COUNT(DISTINCT user_id) AS FLOAT) / SUM(COUNT(DISTINCT user_id)) OVER () * 100, 2) as segment_percent,
    ROUND(AVG(total_revenue), 2) as avg_revenue_per_customer,
    ROUND(SUM(total_revenue), 2) as total_segment_revenue,
    ROUND(AVG(total_orders), 2) as avg_orders_per_customer,
    ROUND(AVG(customer_lifetime_days), 2) as avg_lifetime_days,
    acquisition_channel,
    ROUND(AVG(age), 2) as avg_age,
    STRING_AGG(DISTINCT country, ', ') WITHIN GROUP (ORDER BY country) as countries
FROM vw_customer_rfm
GROUP BY rfm_segment, acquisition_channel
ORDER BY total_segment_revenue DESC;
GO

-- 2. ’¿–¿ “≈–»—“» »  À»≈Õ“Œ¬ œŒ  ¿Õ¿À¿Ã
PRINT '=== 2. œŒ–“–≈“€  À»≈Õ“Œ¬ œŒ  ¿Õ¿À¿Ã ===';
SELECT 
    acquisition_channel,
    COUNT(DISTINCT user_id) as total_customers,
    ROUND(AVG(age), 2) as avg_age,
    STRING_AGG(DISTINCT gender, ', ') as gender_distribution,
    STRING_AGG(DISTINCT country, ', ') as top_countries,
    ROUND(AVG(total_orders), 2) as avg_orders,
    ROUND(AVG(total_revenue), 2) as avg_lifetime_value,
    ROUND(AVG(DATEDIFF(DAY, registration_date, GETDATE())), 2) as avg_days_since_registration,
    ROUND(SUM(total_revenue) / COUNT(DISTINCT user_id), 2) as revenue_per_customer
FROM vw_customer_rfm
WHERE acquisition_channel IS NOT NULL
GROUP BY acquisition_channel
ORDER BY avg_lifetime_value DESC;
GO

-- 3. ¿Õ¿À»« ”ƒ≈–∆¿Õ»ﬂ  À»≈Õ“Œ¬
PRINT '=== 3. ¿Õ¿À»« ”ƒ≈–∆¿Õ»ﬂ ===';
WITH customer_cohorts AS (
    SELECT 
        user_id,
        DATEPART(YEAR, registration_date) as cohort_year,
        DATEPART(MONTH, registration_date) as cohort_month,
        CONCAT(DATEPART(YEAR, registration_date), '-', 
               FORMAT(DATEPART(MONTH, registration_date), '00')) as cohort,
        MIN(order_date) as first_order_date
    FROM users u
    LEFT JOIN orders o ON u.user_id = o.user_id AND o.status = 'completed'
    GROUP BY user_id, 
             DATEPART(YEAR, registration_date), 
             DATEPART(MONTH, registration_date)
),
cohort_analysis AS (
    SELECT 
        cohort,
        cohort_year,
        cohort_month,
        COUNT(DISTINCT user_id) as cohort_size,
        COUNT(DISTINCT CASE WHEN DATEDIFF(MONTH, registration_date, first_order_date) = 0 THEN user_id END) as m0_retained,
        COUNT(DISTINCT CASE WHEN DATEDIFF(MONTH, registration_date, first_order_date) = 1 THEN user_id END) as m1_retained,
        COUNT(DISTINCT CASE WHEN DATEDIFF(MONTH, registration_date, first_order_date) = 2 THEN user_id END) as m2_retained,
        COUNT(DISTINCT CASE WHEN DATEDIFF(MONTH, registration_date, first_order_date) = 3 THEN user_id END) as m3_retained
    FROM customer_cohorts cc
    JOIN users u ON cc.user_id = u.user_id
    GROUP BY cohort, cohort_year, cohort_month
)
SELECT 
    cohort,
    cohort_size,
    m0_retained,
    m1_retained,
    m2_retained,
    m3_retained,
    ROUND(CAST(m0_retained AS FLOAT) / cohort_size * 100, 2) as m0_retention_rate,
    ROUND(CAST(m1_retained AS FLOAT) / cohort_size * 100, 2) as m1_retention_rate,
    ROUND(CAST(m2_retained AS FLOAT) / cohort_size * 100, 2) as m2_retention_rate,
    ROUND(CAST(m3_retained AS FLOAT) / cohort_size * 100, 2) as m3_retention_rate
FROM cohort_analysis
ORDER BY cohort_year, cohort_month;
GO

-- 4. ¿Õ¿À»« œŒ¬“Œ–Õ€’ œŒ ”œŒ 
PRINT '=== 4. ¿Õ¿À»« œŒ¬“Œ–Õ€’ œŒ ”œŒ  ===';
WITH customer_orders AS (
    SELECT 
        user_id,
        COUNT(DISTINCT order_id) as order_count,
        MIN(order_date) as first_order_date,
        MAX(order_date) as last_order_date,
        SUM(total_amount) as total_spent
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
),
order_frequency AS (
    SELECT 
        order_count,
        COUNT(DISTINCT user_id) as customers,
        ROUND(AVG(total_spent), 2) as avg_total_spent,
        ROUND(AVG(DATEDIFF(DAY, first_order_date, last_order_date)), 2) as avg_customer_lifetime_days,
        ROUND(AVG(total_spent / NULLIF(order_count, 0)), 2) as avg_order_value,
        CASE 
            WHEN order_count = 1 THEN 'Œ‰ÌÓÍ‡ÚÌ˚Â'
            WHEN order_count = 2 THEN 'ƒ‚ÛÍ‡ÚÌ˚Â'
            WHEN order_count BETWEEN 3 AND 5 THEN 'œÓÒÚÓˇÌÌ˚Â (3-5)'
            WHEN order_count BETWEEN 6 AND 10 THEN 'ÀÓˇÎ¸Ì˚Â (6-10)'
            ELSE 'VIP (>10)'
        END as customer_type
    FROM customer_orders
    GROUP BY order_count,
        CASE 
            WHEN order_count = 1 THEN 'Œ‰ÌÓÍ‡ÚÌ˚Â'
            WHEN order_count = 2 THEN 'ƒ‚ÛÍ‡ÚÌ˚Â'
            WHEN order_count BETWEEN 3 AND 5 THEN 'œÓÒÚÓˇÌÌ˚Â (3-5)'
            WHEN order_count BETWEEN 6 AND 10 THEN 'ÀÓˇÎ¸Ì˚Â (6-10)'
            ELSE 'VIP (>10)'
        END
)
SELECT 
    customer_type,
    SUM(customers) as total_customers,
    ROUND(CAST(SUM(customers) AS FLOAT) / SUM(SUM(customers)) OVER () * 100, 2) as percent_of_total,
    ROUND(AVG(avg_total_spent), 2) as avg_lifetime_value,
    ROUND(SUM(avg_total_spent * customers) / SUM(customers), 2) as weighted_avg_ltv,
    ROUND(AVG(avg_customer_lifetime_days), 2) as avg_lifetime_days,
    ROUND(AVG(avg_order_value), 2) as avg_order_value
FROM order_frequency
GROUP BY customer_type
ORDER BY weighted_avg_ltv DESC;
GO

-- 5. ¿Õ¿À»« √≈Œ√–¿‘»»  À»≈Õ“Œ¬
PRINT '=== 5. √≈Œ√–¿‘»◊≈— »… ¿Õ¿À»« ===';
SELECT 
    country,
    city,
    COUNT(DISTINCT u.user_id) as total_customers,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(o.total_amount), 2) as total_revenue,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    ROUND(SUM(o.total_amount) / COUNT(DISTINCT u.user_id), 2) as revenue_per_customer,
    ROUND(CAST(COUNT(DISTINCT o.order_id) AS FLOAT) / COUNT(DISTINCT u.user_id), 2) as avg_orders_per_customer,
    STRING_AGG(DISTINCT mt.channel, ', ') as top_acquisition_channels
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id AND o.status = 'completed'
LEFT JOIN marketing_touch mt ON u.user_id = mt.user_id
WHERE country IS NOT NULL
GROUP BY country, city
HAVING COUNT(DISTINCT u.user_id) > 5
ORDER BY total_revenue DESC;
GO

-- 6. ¿Õ¿À»« ¬Œ«–¿—“Õ€’ √–”œœ
PRINT '=== 6. ¿Õ¿À»« œŒ ¬Œ«–¿—“Õ€Ã √–”œœ¿Ã ===';
WITH age_groups AS (
    SELECT 
        user_id,
        CASE 
            WHEN age < 20 THEN 'ƒÓ 20'
            WHEN age BETWEEN 20 AND 29 THEN '20-29'
            WHEN age BETWEEN 30 AND 39 THEN '30-39'
            WHEN age BETWEEN 40 AND 49 THEN '40-49'
            WHEN age >= 50 THEN '50+'
            ELSE 'ÕÂ ÛÍ‡Á‡Ì'
        END as age_group,
        gender,
        country
    FROM users
)
SELECT 
    ag.age_group,
    ag.gender,
    COUNT(DISTINCT ag.user_id) as customers_count,
    COUNT(DISTINCT o.order_id) as orders_count,
    ROUND(SUM(o.total_amount), 2) as total_revenue,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    ROUND(SUM(o.total_amount) / COUNT(DISTINCT ag.user_id), 2) as revenue_per_customer,
    STRING_AGG(DISTINCT mt.channel, ', ') as preferred_channels,
    STRING_AGG(DISTINCT p.category, ', ') as preferred_categories
FROM age_groups ag
LEFT JOIN orders o ON ag.user_id = o.user_id AND o.status = 'completed'
LEFT JOIN marketing_touch mt ON ag.user_id = mt.user_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
GROUP BY ag.age_group, ag.gender
ORDER BY ag.age_group, total_revenue DESC;
GO

-- 7.  –Œ——-¿Õ¿À»« RFM » ƒ≈ÃŒ√–¿‘»»
PRINT '=== 7. RFM » ƒ≈ÃŒ√–¿‘»◊≈— »… ¿Õ¿À»« ===';
SELECT 
    cr.rfm_segment,
    cr.acquisition_channel,
    CASE 
        WHEN cr.age < 25 THEN '18-24'
        WHEN cr.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN cr.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN cr.age >= 45 THEN '45+'
        ELSE 'ÕÂ ÛÍ‡Á‡Ì'
    END as age_group,
    cr.gender,
    COUNT(DISTINCT cr.user_id) as customers,
    ROUND(AVG(cr.total_orders), 2) as avg_orders,
    ROUND(AVG(cr.total_revenue), 2) as avg_revenue,
    ROUND(AVG(cr.customer_lifetime_days), 2) as avg_lifetime_days,
    ROUND(AVG(DATEDIFF(DAY, cr.last_order_date, GETDATE())), 2) as avg_days_since_last_order
FROM vw_customer_rfm cr
GROUP BY 
    cr.rfm_segment,
    cr.acquisition_channel,
    CASE 
        WHEN cr.age < 25 THEN '18-24'
        WHEN cr.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN cr.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN cr.age >= 45 THEN '45+'
        ELSE 'ÕÂ ÛÍ‡Á‡Ì'
    END,
    cr.gender
HAVING COUNT(DISTINCT cr.user_id) > 3
ORDER BY cr.rfm_segment, customers DESC;
GO