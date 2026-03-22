insert into mart.f_sales (date_id, item_id, customer_id, city_id, quantity, payment_amount)
select dc.date_id, item_id, customer_id, city_id, quantity, payment_amount from staging.user_order_log uol
left join mart.d_calendar as dc on uol.date_time::Date = dc.date_actual
where uol.date_time::Date = '{{ds}}';

-- Добавляем столбец status
ALTER TABLE mart.f_sales 
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'shipped';


-- Проставляем status из staging для новых данных, где status есть
UPDATE mart.f_sales f
SET status = uol.status
FROM staging.user_order_log uol
JOIN mart.d_calendar dc ON uol.date_time::DATE = dc.date_actual
WHERE f.date_id = dc.date_id 
  AND f.item_id = uol.item_id 
  AND f.customer_id = uol.customer_id
  AND f.city_id = uol.city_id
  AND uol.date_time::DATE = '{{ds}}'::DATE
  AND uol.status IS NOT NULL;  -- только если в staging есть status

-- Меняем знак суммы для refunded
UPDATE mart.f_sales
SET payment_amount = -payment_amount
WHERE status = 'refunded' 
  AND date_id = (
      SELECT date_id 
      FROM mart.d_calendar 
      WHERE date_actual = '{{ds}}'::DATE
  );