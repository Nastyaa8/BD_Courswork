-------------------------------------------------------------------------------
--                ШАГ 1: ТЕСТ: ДОБАВЛЕНИЕ КНИГИ
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_new_isbn VARCHAR2(50) := '978-0-6432-7356-3'; -- Новый уникальный ISBN
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('===  ДОБАВЛЕНИЕ КНИГИ ОТ ИМЕНИ ПРОДАВЦА (SellerUser) ===');
    
    -- Вызов процедуры добавления продукта (Книга: Великий Гэтсби)
    BOOKSTORE_USER.MANAGE_PRODUCT_ADD(
        p_isbn => v_new_isbn,
        p_title => 'Великий Гэтсби',
        p_author => 'Ф. Скотт Фицджеральд',
        p_price => 480.00,
        p_stock => 80,
        p_category => 'Классика',
        p_image_url => 'https://myshop.com/img/photo_book.jpg'
    );
    
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' SellerUser успешно завершил операцию.');
    DBMS_OUTPUT.PUT_LINE('==================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА ДОБАВЛЕНИЯ КНИГИ ПРОДАВЦОМ: ' || SQLERRM);
END;
/
COMMIT;
------------------------------------------------------------------------------
-- ТЕСТ ИЗМЕНЕНИЯ С ВЫВОДОМ НОВЫХ ДАННЫХ
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_book_id NUMBER;
    v_target_isbn CONSTANT VARCHAR2(50) := '978-0-11-006867';
    
    -- Переменные для получения новых данных
    v_new_title BOOKSTORE_USER.BOOKS.title%TYPE;
    v_new_author BOOKSTORE_USER.BOOKS.author%TYPE;
    v_new_price BOOKSTORE_USER.BOOKS.price%TYPE;
    v_new_stock BOOKSTORE_USER.BOOKS.stock%TYPE;
    v_new_category BOOKSTORE_USER.BOOKS.category%TYPE;
    v_price_after_discount BOOKSTORE_USER.BOOKS.price_after_discount%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('===  ТЕСТ: Изменение и вывод новых характеристик ===');

    -- 1. Получаем ID книги
    SELECT book_id INTO v_book_id
    FROM BOOKSTORE_USER.BOOKS
    WHERE isbn = v_target_isbn;
    
    DBMS_OUTPUT.PUT_LINE('Начато изменение книги ID: ' || v_book_id);

    -- 2. ВЫЗОВ ПРОЦЕДУРЫ ИЗМЕНЕНИЯ
    BOOKSTORE_USER.MANAGE_PRODUCT_EDIT(
        p_book_id => v_book_id,
        p_new_title => 'Великий Гэтсби: Юбилейное издание', -- НОВОЕ НАЗВАНИЕ
        p_new_author => 'Ф. Скотт Фицджеральд, ред. 2025',   -- НОВЫЙ АВТОР
        p_new_price => 3725.50,                             -- НОВАЯ ЦЕНА
        p_new_stock => 30,                                 -- НОВЫЙ ЗАПАС
        p_new_category => 'Классика XX века'               -- НОВАЯ КАТЕГОРИЯ
    );
    
    DBMS_OUTPUT.PUT_LINE(' Все параметры обновлены. Фиксация транзакции...');
    COMMIT; 

    -- 3. ПРОВЕРКА: Получение и вывод новых данных
    SELECT title, author, price, stock, category, price_after_discount
    INTO v_new_title, v_new_author, v_new_price, v_new_stock, v_new_category, v_price_after_discount
    FROM BOOKSTORE_USER.BOOKS
    WHERE book_id = v_book_id;

    DBMS_OUTPUT.PUT_LINE('--- НОВЫЕ ХАРАКТЕРИСТИКИ КНИГИ ---');
    DBMS_OUTPUT.PUT_LINE('Название:      ' || v_new_title);
    DBMS_OUTPUT.PUT_LINE('Автор:         ' || v_new_author);
    DBMS_OUTPUT.PUT_LINE('Цена (price):  ' || v_new_price);
    DBMS_OUTPUT.PUT_LINE('Запас (stock): ' || v_new_stock);
    DBMS_OUTPUT.PUT_LINE('Категория:     ' || v_new_category);
    DBMS_OUTPUT.PUT_LINE('Цена со скидкой: ' || v_price_after_discount);
    
    DBMS_OUTPUT.PUT_LINE('==================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Книга с ISBN ' || v_target_isbn || ' не найдена.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' СИСТЕМНАЯ ОШИБКА: ' || SQLERRM);
        ROLLBACK;
END;
/
-- (Добавляем две тестовые книги)
SET SERVEROUTPUT ON;
BEGIN
    -- Книга А: Для жесткого удаления
    BOOKSTORE_USER.MANAGE_PRODUCT_ADD('978-1-2345-1000-A', 'Тест Книга А (Hard Delete)', 'Автор А', 100, 10, 'Тест');
    -- Книга Б: Для мягкого удаления
    BOOKSTORE_USER.MANAGE_PRODUCT_ADD('978-1-2345-1000-B', 'Тест Книга Б (Soft Delete)', 'Автор Б', 200, 20, 'Тест');
    COMMIT;
END;
/
-------------------------------------------------------------------------------
-- ТЕСТ 1: ЖЕСТКОЕ УДАЛЕНИЕ (Hard Delete)
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_book_id NUMBER;
    v_target_isbn CONSTANT VARCHAR2(50) := '978-0-63-017663';
    v_result_message VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ️ ТЕСТ 1: ЖЕСТКОЕ УДАЛЕНИЕ (Hard Delete) ===');

    -- Получаем ID книги А
    SELECT book_id INTO v_book_id
    FROM BOOKSTORE_USER.BOOKS
    WHERE isbn = v_target_isbn;

    DBMS_OUTPUT.PUT_LINE('Запущено удаление книги ID: ' || v_book_id);

    -- Вызов процедуры
    BOOKSTORE_USER.MANAGE_PRODUCT_DELETE(
        p_book_id => v_book_id
    );
    
    -- Проверка: Книга не должна быть найдена (COUNT = 0)
    DECLARE
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM BOOKSTORE_USER.BOOKS WHERE book_id = v_book_id;
        
        IF v_count = 0 THEN
            v_result_message := ' УСПЕХ: Книга полностью удалена из таблицы.';
        ELSE
            v_result_message := ' СБОЙ: Книга найдена в таблице (Hard Delete failed).';
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('РЕЗУЛЬТАТ ТЕСТА 1: ' || v_result_message);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('==================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
         DBMS_OUTPUT.PUT_LINE(' ОШИБКА В ТЕСТЕ 1: Книга не найдена, возможно, уже удалена.');
         ROLLBACK;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' СИСТЕМНАЯ ОШИБКА В ТЕСТЕ 1: ' || SQLERRM);
        ROLLBACK;
END;
/

-------------------------------------------------------------------------------
-- ТЕСТ 2: МЯГКОЕ УДАЛЕНИЕ (Soft Delete)
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_book_id NUMBER;
    v_target_isbn CONSTANT VARCHAR2(50) := '978-3-004106';
    v_result_message VARCHAR2(200);
    v_title_check BOOKSTORE_USER.BOOKS.title%TYPE;
    v_stock_check BOOKSTORE_USER.BOOKS.stock%TYPE;
    v_archived_check NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ️ ТЕСТ 2: МЯГКОЕ УДАЛЕНИЕ (Soft Delete) ===');

    -- Получаем ID книги Б
    SELECT book_id INTO v_book_id
    FROM BOOKSTORE_USER.BOOKS
    WHERE isbn = v_target_isbn;

    DBMS_OUTPUT.PUT_LINE('Запущено удаление книги ID: ' || v_book_id);

    -- Вызов процедуры
    BOOKSTORE_USER.MANAGE_PRODUCT_DELETE(
        p_book_id => v_book_id
    );
    
    -- Проверка: Книга должна остаться, но быть помечена
    SELECT title, stock, is_archived 
    INTO v_title_check, v_stock_check, v_archived_check
    FROM BOOKSTORE_USER.BOOKS
    WHERE book_id = v_book_id;
    
    IF v_title_check LIKE '[АРХИВ]%' AND v_stock_check = 0 AND v_archived_check = 1 THEN
        v_result_message := ' УСПЕХ: Книга перенесена в АРХИВ (Soft Delete).';
    ELSE
        v_result_message := ' СБОЙ: Книга не была правильно заархивирована.';
    END IF;

    DBMS_OUTPUT.PUT_LINE('РЕЗУЛЬТАТ ТЕСТА 2: ' || v_result_message);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('==================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
         DBMS_OUTPUT.PUT_LINE(' ОШИБКА В ТЕСТЕ 2: Книга не найдена, возможно, была удалена жестко.');
         ROLLBACK;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' СИСТЕМНАЯ ОШИБКА В ТЕСТЕ 2: ' || SQLERRM);
        ROLLBACK;
END;
/
-------------------------------------------------------------------------------
-- ТЕСТ 3:               ОБЩАЯ СТАТИСТИКА МАГАЗИНА
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    -- Переменные для получения результатов (OUT параметры)
    v_orders_cnt   NUMBER;
    v_customers_cnt NUMBER;
    v_books_cnt    NUMBER;
    v_sold_items   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE(' ЧАСТЬ 1: ОБЩАЯ СТАТИСТИКА МАГАЗИНА');
    DBMS_OUTPUT.PUT_LINE('==================================================');

    -- Вызов процедуры
    BOOKSTORE_USER.GET_GENERAL_STATS(
        p_total_orders     => v_orders_cnt,
        p_total_customers  => v_customers_cnt,
        p_total_books      => v_books_cnt,
        p_total_items_sold => v_sold_items
    );
    
    -- Вывод полученных значений
    DBMS_OUTPUT.PUT_LINE('1. Всего оформлено заказов: ' || v_orders_cnt);
    DBMS_OUTPUT.PUT_LINE('2. Уникальных покупателей:  ' || v_customers_cnt);
    DBMS_OUTPUT.PUT_LINE('3. Книг в ассортименте:     ' || v_books_cnt);
    DBMS_OUTPUT.PUT_LINE('4. Всего продано книг (шт): ' || v_sold_items);
    
    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-------------------------------------------------------------------------------
-- ТЕСТ 4:              Популярные книги
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    -- Переменная для курсора
    v_report_cursor SYS_REFCURSOR;
    
    -- Переменные для чтения строки из курсора
    v_title    BOOKSTORE_USER.BOOKS.TITLE%TYPE;
    v_author   BOOKSTORE_USER.BOOKS.AUTHOR%TYPE;
    v_qty      NUMBER;
    v_revenue  NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE(' ЧАСТЬ 2: РЕЙТИНГ ПРОДАЖ (ТОП-5)');
    DBMS_OUTPUT.PUT_LINE('==================================================');

    -- Вызов процедуры (запрашиваем топ-5)
    BOOKSTORE_USER.GET_POPULAR_PRODUCTS(
        p_limit  => 5,
        p_cursor => v_report_cursor
    );
    
    -- Цикл по строкам курсора
    LOOP
        FETCH v_report_cursor INTO v_title, v_author, v_qty, v_revenue;
        EXIT WHEN v_report_cursor%NOTFOUND; -- Выход, когда строки кончились
        
        DBMS_OUTPUT.PUT_LINE('   Книга:   ' || v_title);
        DBMS_OUTPUT.PUT_LINE('   Автор:   ' || v_author);
        DBMS_OUTPUT.PUT_LINE('   Продано: ' || v_qty || ' шт.');
        DBMS_OUTPUT.PUT_LINE('   Выручка: ' || v_revenue || ' у.е.');
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    END LOOP;
    
    -- Обязательно закрываем курсор
    CLOSE v_report_cursor;
    
    DBMS_OUTPUT.PUT_LINE(' Отчет сформирован успешно.');
    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-- сырые данные
SELECT 
    b.title as "Название книги",
    SUM(oi.qty) as "ВСЕГО ПРОДАНО (ШТ)",
    SUM(oi.qty * oi.price) as "ВСЕГО ДЕНЕГ (Выручка)"
FROM BOOKSTORE_USER.ORDER_ITEMS oi
JOIN BOOKSTORE_USER.BOOKS b ON oi.book_id = b.book_id
GROUP BY b.title
ORDER BY "ВСЕГО ПРОДАНО (ШТ)" DESC; -- Сортируем от максимума к минимуму
------------------------------------------------------------------------------
--                              Досье клиента
------------------------------------------------------------------------------
SET SERVEROUTPUT ON;

--покупка на себя
EXEC CLIENT_BUY_BOOK_AUTO('anna', 589327, 1)
COMMIT;
--проверка
SELECT u.username, c.customer_id 
FROM BOOKSTORE_USER.USERS u
JOIN BOOKSTORE_USER.CUSTOMERS c ON u.user_id = c.user_id
WHERE UPPER(u.username) = 'ANNA';

SELECT * FROM BOOKSTORE_USER.ORDERS;

EXEC CLIENT_BUY_BOOK_AUTO('admin', 101, 1);

