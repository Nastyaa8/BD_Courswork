--создание пакета SELLERPACKAGE
CREATE OR REPLACE PACKAGE SELLERPACKAGE AS
  PROCEDURE AddBook(p_title IN NVARCHAR2, p_author IN NVARCHAR2, p_price IN NUMBER, p_stock IN NUMBER);
  PROCEDURE UpdateBook(p_book_id IN NUMBER, p_price IN NUMBER, p_stock IN NUMBER);
  PROCEDURE DeleteBook(p_book_id IN NUMBER);
  PROCEDURE ViewOrders;
  PROCEDURE UpdateOrderStatus(p_order_id IN NUMBER,p_status IN VARCHAR2);
END SELLERPACKAGE;
/
CREATE OR REPLACE PACKAGE BODY SELLERPACKAGE AS

  PROCEDURE AddBook(p_title IN NVARCHAR2, p_author IN NVARCHAR2, p_price IN NUMBER, p_stock IN NUMBER) IS
  BEGIN
    INSERT INTO books (title, author, price, stock)
    VALUES (p_title, p_author, p_price, p_stock);
    DBMS_OUTPUT.PUT_LINE('Книга "' || p_title || '" добавлена.');
  END AddBook;

  PROCEDURE UpdateBook(p_book_id IN NUMBER, p_price IN NUMBER, p_stock IN NUMBER) IS
  BEGIN
    UPDATE books
    SET price = p_price,
        stock = p_stock
    WHERE book_id = p_book_id;
    DBMS_OUTPUT.PUT_LINE('Книга с ID=' || p_book_id || ' обновлена.');
  END UpdateBook;

  PROCEDURE DeleteBook(p_book_id IN NUMBER) IS
  BEGIN
    DELETE FROM books
    WHERE book_id = p_book_id;
    DBMS_OUTPUT.PUT_LINE('Книга с ID=' || p_book_id || ' удалена.');
  END DeleteBook;

  PROCEDURE ViewOrders IS
  BEGIN
    FOR rec IN (
      SELECT o.order_id,
             c.full_name AS client,
             b.title,
             oi.qty,
             o.status
      FROM orders o
      JOIN customers c ON o.customer_id = c.customer_id
      JOIN order_items oi ON o.order_id = oi.order_id
      JOIN books b ON oi.book_id = b.book_id
      ORDER BY o.order_id
    ) LOOP
      DBMS_OUTPUT.PUT_LINE(
        'Заказ ' || rec.order_id || ': клиент ' || rec.client ||
        ', книга "' || rec.title || '", количество ' || rec.qty ||
        ', статус: ' || rec.status
      );
    END LOOP;
  END ViewOrders;

  PROCEDURE UpdateOrderStatus(p_order_id IN NUMBER, p_status IN VARCHAR2) IS
  BEGIN
    UPDATE orders
    SET status = p_status
    WHERE order_id = p_order_id;

    DBMS_OUTPUT.PUT_LINE('Статус заказа ' || p_order_id || ' обновлён на "' || p_status || '".');
  END UpdateOrderStatus;

END SELLERPACKAGE;
/







-- Добавим роль и пользователя
INSERT INTO roles (role_name) VALUES ('Customer');
INSERT INTO users (username, password_hash, role_id) 
VALUES ('ivan', '12345', 1);

-- Добавим покупателя
INSERT INTO customers (user_id, full_name, email, phone)
VALUES (1, 'Иван Иванов', 'ivan@mail.com', '123456789');

-- Добавим книгу через пакет
BEGIN
  SellerPackage.AddBook('Гарри Поттер', 'Джоан Роулинг', 500, 10);
END;
/
SELECT book_id, title FROM books;
-- Добавим заказ и позицию заказа
INSERT INTO orders (customer_id, status, total_amount) VALUES (1, 'Новый', 500);
INSERT INTO order_items (order_id, book_id, qty, price) VALUES (1, 2, 1, 500);
COMMIT;

--тестирование редактирование книги
BEGIN
  SellerPackage.AddBook('Гарри Поттер', 'Джоан Роулинг', 500, 10);
  SellerPackage.UpdateBook(1, 600, 12);  -- предполагаем, что ID = 1
  SellerPackage.DeleteBook(1);
END;
/
SET SERVEROUTPUT ON;

SELECT * FROM books;
--тестирование просмотра заказов и обновление статуса заказа
BEGIN
  -- Обновляем книгу
  SellerPackage.UpdateBook(1, 600, 12);
end;
begin
  -- Просмотр заказов
  SellerPackage.ViewOrders;
end;
begin
  -- Обновление статуса заказа
  SellerPackage.UpdateOrderStatus(1, 'Отправлен');
end;
  -- Просмотр заказов после изменения статуса
  SellerPackage.ViewOrders;

  -- Удаляем книгу
  SellerPackage.DeleteBook(1);
END;
/

