--ALTER DATABASE OPEN;
SELECT constraint_name
FROM user_constraints
WHERE table_name = 'ORDERS'
  AND constraint_type = 'R';
ALTER TABLE orders
DROP CONSTRAINT SYS_C008280;
ALTER TABLE orders
ADD CONSTRAINT orders_customer_id_fk
FOREIGN KEY (customer_id) 
REFERENCES customers(customer_id) 
ON DELETE CASCADE;

SELECT constraint_name, r_constraint_name
FROM user_constraints
WHERE table_name = 'ORDER_ITEMS'
  AND constraint_type = 'R';
-- Удаляем старый внешний ключ
ALTER TABLE order_items
DROP CONSTRAINT SYS_C008283;

-- Добавляем новый с ON DELETE CASCADE
ALTER TABLE order_items
ADD CONSTRAINT order_items_order_id_fk
FOREIGN KEY (order_id)
REFERENCES orders(order_id)
ON DELETE CASCADE;
