 -------------------------------------------------------------------------------
--                                Вход пользователя
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_login VARCHAR2(50) := 'kate';
    v_pass  VARCHAR2(50) := 'pass324324';
BEGIN
    DBMS_OUTPUT.PUT_LINE('=========================================');
    DBMS_OUTPUT.PUT_LINE('=== ТЕСТ: ПОПЫТКА ВХОДА ===');
    DBMS_OUTPUT.PUT_LINE('Пользователь ' || v_login || ' пытается войти...');

    -- Вызываем процедуру входа
    BOOKSTORE_USER.LOGIN(v_login, v_pass);

    DBMS_OUTPUT.PUT_LINE('=========================================');
END;
/
-------------------------------------------------------------------------------
--                             Регистрация пользователя
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    
    v_test_user VARCHAR2(50) := 'Test_User_New_1'; 
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== НАЧАЛО ТЕСТА ВАЛИДАЦИИ ===');
    DBMS_OUTPUT.PUT_LINE('Тестируем пользователя: ' || v_test_user);

   
    DBMS_OUTPUT.PUT_LINE('-> Пробуем зарегистрировать с плохим Email...');
    
    BOOKSTORE_USER.MANAGE_CUSTOMER_ADD(
        p_username  => 'kate1',
        p_password  => 'pass324324',
        p_full_name => 'Тестовый Клиент',
        p_email     => 'bad_email@gmail.com',     -- <--- ОШИБКА ЗДЕСЬ (нет @)
        p_phone     => '+3752967098674'
    );

    -- 2. ПРОВЕРКА: Появился ли он в базе?
    DBMS_OUTPUT.PUT_LINE(''); 
    DBMS_OUTPUT.PUT_LINE('-> Проверяем результат в таблице USERS:');
    
    FOR r IN (SELECT user_id FROM BOOKSTORE_USER.USERS WHERE username = v_test_user) LOOP
        DBMS_OUTPUT.PUT_LINE('!!! ВНИМАНИЕ: Пользователь все-таки создался! ID: ' || r.user_id);
    END LOOP;
    
   
    DBMS_OUTPUT.PUT_LINE('====================');
END;
/
-------------------------------------------------------------------------------
--                            Заполнение корзины
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    -- ВВОДНЫЕ ДАННЫЕ (Только логин и что хотим купить)
    v_my_login   VARCHAR2(50) := 'kate1'; 
    v_book_isbn  VARCHAR2(20) := '978-0-91-005422'; -- Книга, которую ищем
   
    -- ТЕХНИЧЕСКИЕ ПЕРЕМЕННЫЕ (Скрипт найдет их сам)
    v_cust_id    NUMBER;
    v_order_id   NUMBER;
    v_book_id    NUMBER;
    v_total_sum  NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('===  КЛИЕНТ: ПОКУПКА (АВТОМАТИЧЕСКАЯ) ===');

    -- 1. КТО Я? (Находим свой ID)
    BEGIN
        SELECT c.customer_id INTO v_cust_id
        FROM BOOKSTORE_USER.CUSTOMERS c
        JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
        WHERE u.username = v_my_login;
        
        DBMS_OUTPUT.PUT_LINE(' Покупатель определен: ' || v_my_login || ' (ID: ' || v_cust_id || ')');
    EXCEPTION WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Вас нет в базе покупателей.'); RETURN;
    END;

    -- 2. ГДЕ МОЯ КОРЗИНА? (Ищем открытый заказ)
    BEGIN
        SELECT order_id INTO v_order_id
        FROM BOOKSTORE_USER.ORDERS
        WHERE customer_id = v_cust_id 
          AND status = 'Новый' -- Ищем только открытую корзину
        FETCH FIRST 1 ROWS ONLY; -- Берем первую (если их вдруг несколько)
        
        DBMS_OUTPUT.PUT_LINE('️ Найдена открытая корзина № ' || v_order_id);
        
    EXCEPTION WHEN NO_DATA_FOUND THEN
        -- Если корзины нет -> Создаем новую!
        DBMS_OUTPUT.PUT_LINE('️ Открытой корзины нет. Создаем новую...');
        BOOKSTORE_USER.MANAGE_ORDER_CREATE(v_cust_id, v_order_id);
        DBMS_OUTPUT.PUT_LINE(' Создан новый заказ № ' || v_order_id);
    END;

    -- 3. ЧТО ПОКУПАЕМ? (Ищем книгу)
    BEGIN
        SELECT book_id INTO v_book_id FROM BOOKSTORE_USER.BOOKS 
        WHERE isbn = v_book_isbn FETCH FIRST 1 ROWS ONLY;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        -- Фоллбэк: ищем по названию, если ISBN не найден
        BEGIN
             SELECT book_id INTO v_book_id FROM BOOKSTORE_USER.BOOKS 
             WHERE title = 'Стивен Кинг' FETCH FIRST 1 ROWS ONLY;
        EXCEPTION WHEN OTHERS THEN
             DBMS_OUTPUT.PUT_LINE(' Книга не найдена.'); RETURN;
        END;
    END;

    -- 4. КЛАДЕМ В КОРЗИНУ
    BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM(v_order_id, v_book_id, 1);

    -- 5. ПЕЧАТАЕМ ЧЕК
    DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    DBMS_OUTPUT.PUT_LINE(' ВАШ ЧЕК (Заказ № ' || v_order_id || '):');
    FOR item IN (
        SELECT b.title, oi.qty, oi.price, (oi.qty * oi.price) as sub
        FROM BOOKSTORE_USER.ORDER_ITEMS oi
        JOIN BOOKSTORE_USER.BOOKS b ON oi.book_id = b.book_id
        WHERE oi.order_id = v_order_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('    ' || item.title || ': ' || item.qty || ' шт. x ' || item.price || ' = ' || item.sub);
    END LOOP;
    
    -- Итого
    SELECT total_amount INTO v_total_sum FROM BOOKSTORE_USER.ORDERS WHERE order_id = v_order_id;
    DBMS_OUTPUT.PUT_LINE(' ИТОГО: ' || v_total_sum);
    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
COMMIT;
-------------------------------------------------------------------------------
--                            Удаление товара из корзины
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_my_login      VARCHAR2(50) := 'kate1'; 
    v_order_id      NUMBER;
    v_book_to_remove  NUMBER;
    v_total_sum     NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('===  ДИАГНОСТИКА УДАЛЕНИЯ ===');

    -- 1. ДИАГНОСТИКА: НАХОДИМ ОТКРЫТУЮ КОРЗИНУ КЛИЕНТА
    BEGIN
        SELECT o.order_id INTO v_order_id
        FROM BOOKSTORE_USER.ORDERS o
        JOIN BOOKSTORE_USER.CUSTOMERS c ON o.customer_id = c.customer_id
        JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
        WHERE u.username = v_my_login AND o.status = 'Новый'
        FETCH FIRST 1 ROWS ONLY;

        DBMS_OUTPUT.PUT_LINE('1.  УСПЕХ: Найдена активная корзина № ' || v_order_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('1.  ОШИБКА: У клиента ' || v_my_login || ' НЕТ активной корзины (status = Новый).');
            RETURN;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('1.  ОШИБКА: Проблема с поиском корзины: ' || SQLERRM);
            RETURN;
    END;

    -- 2. ДИАГНОСТИКА: НАХОДИМ КНИГУ
    BEGIN
        SELECT book_id INTO v_book_to_remove 
        FROM BOOKSTORE_USER.BOOKS 
        WHERE title = ' Безумный Меч Будущего' FETCH FIRST 1 ROWS ONLY;
        
        DBMS_OUTPUT.PUT_LINE('2.  УСПЕХ: Найдена книга "Коралина" (ID: ' || v_book_to_remove || ')');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('2.  ОШИБКА: Книга "Коралина" не найдена в каталоге.');
            RETURN;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('2.  ОШИБКА: Проблема с поиском книги: ' || SQLERRM);
            RETURN;
    END;
    
    DBMS_OUTPUT.PUT_LINE('--- ОБЕ ПРОВЕРКИ ПРОЙДЕНЫ. ВЫЗЫВАЕМ ПРОЦЕДУРУ ---');

    -- 3. ВЫЗОВ ПРОЦЕДУРЫ УДАЛЕНИЯ
    BOOKSTORE_USER.MANAGE_ORDER_REMOVE_ITEM(
        p_order_id => v_order_id,
        p_book_id  => v_book_to_remove,
        p_qty_to_remove => 1 
    );
    
    -- (Далее идет проверка суммы, если вызов процедуры успешен)
    SELECT total_amount INTO v_total_sum 
    FROM BOOKSTORE_USER.ORDERS 
    WHERE order_id = v_order_id;
    
    DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Новая сумма в корзине: ' || v_total_sum || ' руб.');
    DBMS_OUTPUT.PUT_LINE('==================================================');

EXCEPTION
    -- Это общий блок, который срабатывает, если что-то пошло не так после шага 2.
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' ГЛАВНАЯ ОШИБКА: ' || SQLERRM);
        ROLLBACK;
END;
/
-------------------------------------------------------------------------------
--                             Просмотр заказов
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
BEGIN
   
    BOOKSTORE_USER.CLIENT_GET_MY_HISTORY('kate'); 
END;
/
-----------------------------------------------------------------------------
--                            Просмотр каталога
-----------------------------------------------------------------------------
SET SERVEROUTPUT ON;
BEGIN
    BOOKSTORE_USER.CLIENT_SEARCH_BOOKS();
END;
/
------------------------------------------------------------------------------
--               Найти конкретную книгу по автору или по названию
------------------------------------------------------------------------------
BEGIN
    BOOKSTORE_USER.CLIENT_SEARCH_BOOKS(p_keyword => 'Великий Гэтсби');
END;
/
------------------------------------------------------------------------------
--                             Найти по жанру
------------------------------------------------------------------------------
BEGIN
    BOOKSTORE_USER.CLIENT_SEARCH_BOOKS(
        p_category => 'Фантастика', 
        p_max_price => 1000
    );
END;
/
-----------------------------------------------------------------------------
--                          Чек
-----------------------------------------------------------------------------
SET SERVEROUTPUT ON;
BEGIN
    BOOKSTORE_USER.CLIENT_GET_ORDER_DETAILS(101);
END;
/
