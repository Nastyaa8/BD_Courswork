CREATE OR REPLACE PACKAGE ClientPackage AS
  -- Регистрация
  PROCEDURE Register(p_username IN NVARCHAR2, p_password_hash IN NVARCHAR2, p_full_name IN NVARCHAR2, p_email IN NVARCHAR2);

  -- Авторизация
  FUNCTION Login(p_username IN NVARCHAR2, p_password_hash IN NVARCHAR2) RETURN NUMBER;

  -- Просмотр каталога
  PROCEDURE BrowseCatalog;

  -- Поиск книг
  PROCEDURE SearchByAuthor(p_author IN NVARCHAR2);
  PROCEDURE SearchByCategory(p_category IN NVARCHAR2);

  -- Добавление книги в корзину
  PROCEDURE AddToCart(p_customer_id IN NUMBER, p_book_id IN NUMBER, p_qty IN NUMBER);

  -- Оформление заказа
  PROCEDURE PlaceOrder(p_customer_id IN NUMBER);

  -- Просмотр истории заказов
  PROCEDURE ViewOrders(p_customer_id IN NUMBER);
END ClientPackage;
/
CREATE OR REPLACE PACKAGE BODY ClientPackage AS

  -- Регистрация клиента
  PROCEDURE Register(p_username IN NVARCHAR2, p_password_hash IN NVARCHAR2, p_full_name IN NVARCHAR2, p_email IN NVARCHAR2) IS
    v_count NUMBER;
    v_role_id NUMBER;
  BEGIN
    -- Проверка, существует ли username
    SELECT COUNT(*) INTO v_count FROM users WHERE username = p_username;
    IF v_count > 0 THEN
      DBMS_OUTPUT.PUT_LINE('Username "' || p_username || '" уже существует.');
      RETURN;
    END IF;

    -- Получаем роль "Customer"
    SELECT role_id INTO v_role_id FROM roles WHERE role_name = 'Customer';

    -- Создаем пользователя
    INSERT INTO users(username, password_hash, role_id)
    VALUES(p_username, p_password_hash, v_role_id);

    -- Получаем user_id
    DECLARE v_user_id NUMBER;
    BEGIN
      SELECT user_id INTO v_user_id FROM users WHERE username = p_username;
      -- Создаем запись в customers
      INSERT INTO customers(user_id, full_name, email) VALUES (v_user_id, p_full_name, p_email);
    END;

    DBMS_OUTPUT.PUT_LINE('Пользователь "' || p_username || '" зарегистрирован.');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Роль "Customer" не найдена.');
  END Register;

  -- Авторизация
  FUNCTION Login(p_username IN NVARCHAR2, p_password_hash IN NVARCHAR2) RETURN NUMBER IS
    v_user_id NUMBER;
  BEGIN
    SELECT u.user_id INTO v_user_id
    FROM users u
    WHERE u.username = p_username AND u.password_hash = p_password_hash;

    DBMS_OUTPUT.PUT_LINE('Пользователь "' || p_username || '" успешно авторизован.');
    RETURN v_user_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Неверный логин или пароль.');
      RETURN NULL;
  END Login;

  -- Просмотр каталога
  PROCEDURE BrowseCatalog IS
  BEGIN
    FOR rec IN (SELECT book_id, title, author, price, stock, category FROM books) LOOP
      DBMS_OUTPUT.PUT_LINE('ID=' || rec.book_id || ' | ' || rec.title || ' | ' || rec.author || ' | ' || rec.category || ' | ' || rec.price || ' | ' || rec.stock);
    END LOOP;
  END BrowseCatalog;

  -- Поиск по автору
  PROCEDURE SearchByAuthor(p_author IN NVARCHAR2) IS
  BEGIN
    FOR rec IN (SELECT book_id, title, author, category, price FROM books WHERE LOWER(author) LIKE LOWER('%' || p_author || '%')) LOOP
      DBMS_OUTPUT.PUT_LINE('ID=' || rec.book_id || ' | ' || rec.title || ' | ' || rec.author || ' | ' || rec.category || ' | ' || rec.price);
    END LOOP;
  END SearchByAuthor;

  -- Поиск по категории
  PROCEDURE SearchByCategory(p_category IN NVARCHAR2) IS
  BEGIN
    FOR rec IN (SELECT book_id, title, author, category, price FROM books WHERE LOWER(category) LIKE LOWER('%' || p_category || '%')) LOOP
      DBMS_OUTPUT.PUT_LINE('ID=' || rec.book_id || ' | ' || rec.title || ' | ' || rec.author || ' | ' || rec.category || ' | ' || rec.price);
    END LOOP;
  END SearchByCategory;

  -- Добавление книги в корзину (используем временную таблицу cart)
  PROCEDURE AddToCart(p_customer_id IN NUMBER, p_book_id IN NUMBER, p_qty IN NUMBER) IS
    v_price NUMBER;
  BEGIN
    SELECT price INTO v_price FROM books WHERE book_id = p_book_id;
    INSERT INTO order_items(order_id, book_id, qty, price)
    VALUES(NULL, p_book_id, p_qty, v_price);  -- order_id пока NULL, потом при оформлении
    DBMS_OUTPUT.PUT_LINE('Книга ID=' || p_book_id || ' добавлена в корзину, qty=' || p_qty);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Книга с ID=' || p_book_id || ' не найдена.');
  END AddToCart;

  -- Оформление заказа
  PROCEDURE PlaceOrder(p_customer_id IN NUMBER) IS
    v_order_id NUMBER;
    v_total NUMBER := 0;
  BEGIN
    -- Создаем заказ
    INSERT INTO orders(customer_id, status, total_amount) VALUES (p_customer_id, 'NEW', 0) RETURNING order_id INTO v_order_id;

    -- Переносим позиции из "корзины" (order_items с order_id IS NULL) в реальный заказ
    FOR rec IN (SELECT * FROM order_items WHERE order_id IS NULL) LOOP
      UPDATE order_items SET order_id = v_order_id WHERE order_item_id = rec.order_item_id;
      v_total := v_total + rec.price * rec.qty;
    END LOOP;

    -- Обновляем сумму заказа
    UPDATE orders SET total_amount = v_total WHERE order_id = v_order_id;

    DBMS_OUTPUT.PUT_LINE('Заказ ID=' || v_order_id || ' оформлен, сумма: ' || v_total);
  END PlaceOrder;

  -- Просмотр истории заказов
  PROCEDURE ViewOrders(p_customer_id IN NUMBER) IS
  BEGIN
    FOR rec IN (SELECT o.order_id, o.order_date, o.status, o.total_amount
                FROM orders o
                WHERE o.customer_id = p_customer_id) LOOP
      DBMS_OUTPUT.PUT_LINE('Заказ ID=' || rec.order_id || ' | ' || rec.order_date || ' | ' || rec.status || ' | ' || rec.total_amount);
    END LOOP;
  END ViewOrders;

END ClientPackage;
/



--тестирование
-- Регистрация
BEGIN
  ClientPackage.Register('ivan', 'pass123', 'Иван Иванов', 'ivan@mail.com');
END;
/

-- Авторизация
DECLARE
  v_user_id NUMBER;
BEGIN
  v_user_id := ClientPackage.Login('ivan', 'pass123');
END;
/

-- Просмотр каталога
BEGIN
  ClientPackage.BrowseCatalog;
END;
/

-- Поиск книг
BEGIN
  ClientPackage.SearchByAuthor('Джоан Роулинг');
  ClientPackage.SearchByCategory('Фэнтези');
END;
/

-- Добавление в корзину
BEGIN
  ClientPackage.AddToCart(1, 4, 2); -- customer_id=1, book_id=1, qty=2
END;
/

-- Оформление заказа
BEGIN
  ClientPackage.PlaceOrder(1);
END;
/

-- История заказов
BEGIN
  ClientPackage.ViewOrders(1);
END;
/
