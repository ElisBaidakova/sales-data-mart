CREATE TABLE IF NOT EXISTS mart.f_customer_retention (
    new_customers_count INTEGER,
    returning_customers_count INTEGER,
    refunded_customer_count INTEGER,
    period_name VARCHAR(20) DEFAULT 'weekly',
    period_id INTEGER,
    item_id INTEGER,
    new_customers_revenue NUMERIC,
    returning_customers_revenue NUMERIC,
    customers_refunded INTEGER
);

-- Вставляем агрегированные данные
INSERT INTO mart.f_customer_retention (
    new_customers_count,
    returning_customers_count,
    refunded_customer_count,
    period_name,
    period_id,
    item_id,
    new_customers_revenue,
    returning_customers_revenue,
    customers_refunded
)
WITH weekly_data AS (
    -- Базовые данные: заказы с номером недели
    SELECT 
        customer_id,
        item_id,
        payment_amount,
        status,
        EXTRACT(WEEK FROM date_id::DATE) AS period_id
    FROM mart.f_sales
    WHERE date_id::DATE = '{{ ds }}'::DATE
),
customer_statistics AS (
    -- Статистика по каждому клиенту в рамках периода и товара
    SELECT 
        customer_id,
        item_id,
        period_id,
        COUNT(*) AS order_count,                    -- сколько заказов сделал клиент
        SUM(payment_amount) AS customer_revenue,    -- доход с клиента
        COUNT(CASE WHEN status = 'refunded' THEN 1 END) AS refunded_orders  -- сколько возвратов
    FROM weekly_data
    GROUP BY customer_id, item_id, period_id
),
classified AS (
    -- Классифицируем клиентов и считаем метрики
    SELECT 
        item_id,
        period_id,
        COUNT(CASE WHEN order_count = 1 THEN 1 END) AS new_customers_count,  -- Новые клиенты
        COUNT(CASE WHEN order_count > 1 THEN 1 END) AS returning_customers_count,  -- Клиенты с >1 заказа
        COUNT(CASE WHEN refunded_orders > 0 THEN 1 END) AS refunded_customer_count,  -- Клиенты с возвратами
        SUM(CASE WHEN order_count = 1 THEN customer_revenue END) AS new_customers_revenue,  -- Доход от новых клиентов
        SUM(CASE WHEN order_count > 1 THEN customer_revenue END) AS returning_customers_revenue,  -- Доход от вернувшихся
        SUM(refunded_orders) AS customers_refunded  -- Общее число возвратов
    FROM customer_statistics
    GROUP BY item_id, period_id
)
SELECT 
    new_customers_count,
    returning_customers_count,
    refunded_customer_count,
    'weekly' AS period_name,
    period_id,
    item_id,
    COALESCE(new_customers_revenue, 0) AS new_customers_revenue,
    COALESCE(returning_customers_revenue, 0) AS returning_customers_revenue,
    COALESCE(customers_refunded, 0) AS customers_refunded
FROM classified;