SET SERVEROUTPUT ON;

-------------------------------------------------------------------------------
-- ШАГ 1:                  ИНИЦИАЛИЗАЦИЯ РОЛЕЙ
-------------------------------------------------------------------------------
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ШАГ 1: ИНИЦИАЛИЗАЦИЯ РОЛЕЙ ===');
    
    BOOKSTORE_USER.INIT_ROLES;
    
   
    DBMS_OUTPUT.PUT_LINE('==================================================');
EXCEPTION 
    WHEN OTHERS THEN 
        DBMS_OUTPUT.PUT_LINE(' Критическая ошибка: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-------------------------------------------------------------------------------
-- ШАГ 1.1: АВТОРИЗАЦИЯ ТЕКУЩЕГО АДМИНА (Вставляем сюда)
-------------------------------------------------------------------------------
DECLARE
    v_role_id NUMBER;
BEGIN
    -- Находим ID созданной ранее роли
    SELECT role_id INTO v_role_id 
    FROM BOOKSTORE_USER.ROLES 
    WHERE UPPER(role_name) = 'ADMIN';

    -- Регистрируем ADMINUSER в системе приложения
    MERGE INTO BOOKSTORE_USER.USERS u
    USING (SELECT 'ADMINUSER' as uname FROM DUAL) src
    ON (u.username = src.uname)
    WHEN MATCHED THEN
        UPDATE SET u.role_id = v_role_id, u.status = 'ACTIVE'
    WHEN NOT MATCHED THEN
        INSERT (username, password_hash, role_id, status)
        VALUES ('ADMINUSER', 'EXTERNAL_AUTH', v_role_id, 'ACTIVE');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(' Шаг 1.1: ADMINUSER успешно опознан как Администратор.');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Роль Admin не создана в ШАГе 1!');
END;
/

-------------------------------------------------------------------------------
-- ШАГ 2:                    ДОБАВЛЕНИЕ КНИГИ
-------------------------------------------------------------------------------
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ШАГ 2: Добавление книги ===');
    
    
    BOOKSTORE_USER.MANAGE_PRODUCT_ADD(
        p_isbn => 'ERR-001', 
        p_title => 'Коралина', 
        p_author => 'Нил Гейман', 
        p_price => 100,      --- 100
        p_stock => 10, 
        p_category => 'Test'
    );
    
    
    DBMS_OUTPUT.PUT_LINE('==================================================');

EXCEPTION 
    WHEN OTHERS THEN 
        DBMS_OUTPUT.PUT_LINE(' УСПЕХ : Система перехватила ошибку!');
        DBMS_OUTPUT.PUT_LINE('   Текст ошибки: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/

------------------------------------------------------------------------------
-- ШАГ 3:                  СОЗДАНИЕ ПОКУПАТЕЛЯ
------------------------------------------------------------------------------
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ШАГ 3: РЕГИСТРАЦИЯ ПОКУПАТЕЛЯ ===');
    
    BOOKSTORE_USER.MANAGE_CUSTOMER_ADD(
        p_username => 'unique_user', 
        p_password => '2132192929qwe', 
        p_full_name => 'Usacheva', 
        p_email => 'usach111@mail.com', 
        p_phone => '+375297694940'
    );
    DBMS_OUTPUT.PUT_LINE('==================================================');
EXCEPTION 
    WHEN OTHERS THEN 
        -- Если пользователь уже есть, это нормально для повторного теста
        DBMS_OUTPUT.PUT_LINE('️ Инфо: ' || SQLERRM); 
        DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
COMMIT;

-------------------------------------------------------------------------------
-- ШАГ 4:             СОЗДАНИЕ ЗАКАЗА (или можно сказать корзину)
-------------------------------------------------------------------------------
DECLARE
    --  ДАННЫЕ
    v_my_user_id  NUMBER := 64; -- айди пользователя
    
    v_customer_id NUMBER;
    v_order_id    NUMBER;
    v_count       NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ШАГ 4: СОЗДАНИЕ ЗАКАЗА ===');

    -- 1. ПРОВЕРКА: Существует ли покупатель?
    SELECT COUNT(*) INTO v_count 
    FROM BOOKSTORE_USER.CUSTOMERS 
    WHERE user_id = v_my_user_id;

    -- 2. ЛОГИКА
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь с ID ' || v_my_user_id || ' не имеет профиля покупателя.');
        DBMS_OUTPUT.PUT_LINE('   Действие отменено.');
    ELSE
        -- Получаем ID
        SELECT customer_id INTO v_customer_id 
        FROM BOOKSTORE_USER.CUSTOMERS 
        WHERE user_id = v_my_user_id FETCH FIRST 1 ROWS ONLY;
        
        DBMS_OUTPUT.PUT_LINE(' Покупатель найден. ID: ' || v_customer_id);
        
        -- Вызываем процедуру 
        BOOKSTORE_USER.MANAGE_ORDER_CREATE(v_customer_id, v_order_id);
        
        DBMS_OUTPUT.PUT_LINE(' Заказ успешно создан! ID: ' || v_order_id);
       
    END IF;
    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-------------------------------------------------------------------------------
-- ШАГ 4.5: НАПОЛНЕНИЕ ЗАКАЗА + ПРОСМОТР КОРЗИНЫ
-------------------------------------------------------------------------------
DECLARE
   
    v_order_id NUMBER := 65; --номер заказа из шага 4
    
    v_book_id    NUMBER;
    v_total_sum  NUMBER; -- Для проверки общей суммы
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ШАГ 4.5: ДОБАВЛЕНИЕ КНИГИ И ПРОСМОТР ===');

    -- 1. ПОИСК КНИГИ (ISBN -> Title)
    BEGIN
        SELECT book_id INTO v_book_id FROM BOOKSTORE_USER.BOOKS 
        WHERE isbn = 'ERR-001' FETCH FIRST 1 ROWS ONLY;
        DBMS_OUTPUT.PUT_LINE('->  Книга найдена по ISBN. ID: ' || v_book_id);
    EXCEPTION WHEN NO_DATA_FOUND THEN
        BEGIN
            SELECT book_id INTO v_book_id FROM BOOKSTORE_USER.BOOKS 
            WHERE title = 'Коралина' FETCH FIRST 1 ROWS ONLY;
            DBMS_OUTPUT.PUT_LINE('->  Книга найдена по Названию. ID: ' || v_book_id);
        EXCEPTION WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Книга не найдена.');
            RETURN;
        END;
    END;

    -- 2. ДОБАВЛЕНИЕ В ЗАКАЗ
    IF v_book_id IS NOT NULL THEN
        BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM(v_order_id, v_book_id, 1);
    END IF;

    -- 3. === ПРОСМОТР СОДЕРЖИМОГО КОРЗИНЫ ===
    DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    DBMS_OUTPUT.PUT_LINE(' СОДЕРЖИМОЕ ЗАКАЗА № ' || v_order_id || ':');
    
    -- Цикл по товарам в этом заказе
    FOR item IN (
        SELECT b.title, b.author, oi.qty, oi.price, (oi.qty * oi.price) as subtotal
        FROM BOOKSTORE_USER.ORDER_ITEMS oi
        JOIN BOOKSTORE_USER.BOOKS b ON oi.book_id = b.book_id
        WHERE oi.order_id = v_order_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('    Книга: ' || item.title || ' (' || item.author || ')');
        DBMS_OUTPUT.PUT_LINE('      ' || item.qty || ' шт. x ' || item.price || ' руб. = ' || item.subtotal || ' руб.');
    END LOOP;

    -- 4. ПРОВЕРКА ОБЩЕЙ СУММЫ ЗАКАЗА
    SELECT total_amount INTO v_total_sum 
    FROM BOOKSTORE_USER.ORDERS 
    WHERE order_id = v_order_id;
    
    DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    DBMS_OUTPUT.PUT_LINE(' ИТОГО К ОПЛАТЕ: ' || v_total_sum || ' руб.');
    
    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-------------------------------------------------------------------------------
-- ШАГ 5: ТЕСТ ОПЛАТЫ 
-------------------------------------------------------------------------------
DECLARE
    v_test_order_id NUMBER := 69; 
    -- ==============================================================

    v_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ТЕСТ ОПЛАТЫ ЗАКАЗА  ===');
    DBMS_OUTPUT.PUT_LINE('-> Проверяем заказ № ' || v_test_order_id);

    -- 1. Сначала проверяем, есть ли такой заказ вообще
    SELECT COUNT(*) INTO v_count 
    FROM BOOKSTORE_USER.ORDERS 
    WHERE order_id = v_test_order_id;

    -- 2. Логика (IF / ELSE)
    IF v_count = 0 THEN
        -- СЦЕНАРИЙ 1: Неверный ID (Заказа нет)
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Заказа с ID ' || v_test_order_id || ' не существует в базе.');
        DBMS_OUTPUT.PUT_LINE('   Операция оплаты отклонена (валидация ID прошла успешно).');
    ELSE
        -- СЦЕНАРИЙ 2: Верный ID (Заказ есть)
        DBMS_OUTPUT.PUT_LINE('️ Заказ найден. Отправляем запрос на оплату...');
        
        -- Вызываем процедуру смены статуса
        BOOKSTORE_USER.MANAGE_ORDER_UPDATE_STATUS(v_test_order_id, 'Оплачен');
        
        
    END IF;

    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
COMMIT;
-------------------------------------------------------------------------------
-- ШАГ 6: ТЕСТ ЗАЩИТЫ (ПРОВЕРКА ЧЕРЕЗ СЧЕТЧИК)
-------------------------------------------------------------------------------
DECLARE
    -- НОМЕР ОПЛАЧЕННОГО ЗАКАЗА
    v_order_id NUMBER := 63; 
    
    v_book_id      NUMBER;
    v_count_before NUMBER;
    v_count_after  NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ШАГ 6: ТЕСТ ЗАЩИТЫ  ===');
    DBMS_OUTPUT.PUT_LINE('-> Попытка добавить товар в ОПЛАЧЕННЫЙ заказ № ' || v_order_id);

    -- 1. Находим любую книгу для теста
    SELECT book_id INTO v_book_id FROM BOOKSTORE_USER.BOOKS FETCH FIRST 1 ROWS ONLY;

    -- 2. Считаем, сколько товаров в заказе СЕЙЧАС
    SELECT SUM(qty) INTO v_count_before 
    FROM BOOKSTORE_USER.ORDER_ITEMS 
    WHERE order_id = v_order_id;
    
    -- (Если там пусто, заменим NULL на 0)
    IF v_count_before IS NULL THEN v_count_before := 0; END IF;

    -- 3. ПЫТАЕМСЯ ВЗЛОМАТЬ (Вызываем процедуру)
    -- Она напишет "Ошибка: Нельзя менять..." в консоль, но не уронит скрипт
    BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM(v_order_id, v_book_id, 1);

    -- 4. Считаем, сколько товаров ПОТОМ
    SELECT SUM(qty) INTO v_count_after 
    FROM BOOKSTORE_USER.ORDER_ITEMS 
    WHERE order_id = v_order_id;
    
    IF v_count_after IS NULL THEN v_count_after := 0; END IF;

    -- 5. МОМЕНТ ИСТИНЫ: СРАВНИВАЕМ
    DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    IF v_count_before = v_count_after THEN
        DBMS_OUTPUT.PUT_LINE(' УСПЕХ: Количество товаров не изменилось (' || v_count_before || ').');
        DBMS_OUTPUT.PUT_LINE('   Защита сработала корректно.');
    ELSE
        DBMS_OUTPUT.PUT_LINE(' ПРОВАЛ: Количество изменилось с ' || v_count_before || ' на ' || v_count_after || '!');
        DBMS_OUTPUT.PUT_LINE('   Система пропустила взлом.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-------------------------------------------------------------------------------
-- ШАГ 7:                     БЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ
-------------------------------------------------------------------------------
DECLARE
    v_user_id NUMBER := 84; 
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ШАГ 7: БЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ ===');

    -- Используем правильное название процедуры
    BOOKSTORE_USER.TOGGLE_USER_STATUS(
        p_user_id    => v_user_id,
        p_new_status => 'BLOCKED',
        p_reason     => 'Нарушение правил магазина (Тест)'
    );
    
    DBMS_OUTPUT.PUT_LINE('==================================================');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: ' || SQLERRM);
END;
/
COMMIT;
-------------------------------------------------------------------------------
-- ШАГ 8:                 РАЗБЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_target_user VARCHAR2(50) := 'Ivan111';
    v_user_id      NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== АДМИН: РАЗБЛОКИРОВКА ПОЛЬЗОВАТЕЛЯ ===');

    -- 1. Находим ID пользователя по его логину
    SELECT user_id INTO v_user_id 
    FROM BOOKSTORE_USER.USERS 
    WHERE UPPER(username) = UPPER(v_target_user);

    -- 2. ВЫЗЫВАЕМ ПРОЦЕДУРУ (Она сама проверит ваши права админа и запишет ЛОГ)
    BOOKSTORE_USER.TOGGLE_USER_STATUS(
        p_user_id    => v_user_id,
        p_new_status => 'ACTIVE',
        p_reason     => 'Административная разблокировка через консоль'
    );

    DBMS_OUTPUT.PUT_LINE(' Команда на разблокировку ' || v_target_user || ' отправлена.');
    DBMS_OUTPUT.PUT_LINE('==================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь ' || v_target_user || ' не найден в базе.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка выполнения: ' || SQLERRM);
END;
/
-------------------------------------------------------------------------------
-- ШАГ 9:               Изменение пользователя контактных данных
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_username_to_update VARCHAR2(50) := 'kate'; 
    v_new_email      VARCHAR2(100) := 'updat.email@domain.com';
    v_new_full_name  VARCHAR2(100) := 'Петров Петр Петрович';
    v_new_address    VARCHAR2(255) := 'ул. Пушкина, д. Колотушкина, кв. 42';
    v_new_phone      VARCHAR2(50)  := '+3752967009874';

    v_current_session_user VARCHAR2(50) := UPPER(USER);
    v_has_access          BOOLEAN := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('=== ТЕСТ: КОМПЛЕКСНОЕ ОБНОВЛЕНИЕ CUSTOMER ===');
    
    -- 1. Вызов процедуры
    BOOKSTORE_USER.MANAGE_CUSTOMER_DATA_UPDATE(
        p_username => v_username_to_update,
        p_new_address => v_new_address,
        p_new_phone => v_new_phone,
        p_new_full_name => v_new_full_name,
        p_new_email => v_new_email
    );

    -- 2. ПРОВЕРКА ПРАВ (Выносим логику из SQL в PL/SQL)
    IF BOOKSTORE_USER.HAS_ROLE(v_current_session_user, 'Admin') 
       OR UPPER(v_current_session_user) = UPPER(v_username_to_update) THEN
        v_has_access := TRUE;
    END IF;

    -- 3. БЕЗОПАСНЫЙ ВЫВОД
    IF v_has_access THEN
        DECLARE
            v_check_email      VARCHAR2(100);
            v_check_name       VARCHAR2(100);
            v_check_address    VARCHAR2(255);
            v_check_phone      VARCHAR2(50);
        BEGIN
            SELECT c.email, c.full_name, c.address, c.phone
            INTO v_check_email, v_check_name, v_check_address, v_check_phone
            FROM BOOKSTORE_USER.CUSTOMERS c
            JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
            WHERE u.username = v_username_to_update;
            
            DBMS_OUTPUT.PUT_LINE('-----------------------------------');
            DBMS_OUTPUT.PUT_LINE(' Доступ разрешен. Данные изменены:');
            DBMS_OUTPUT.PUT_LINE('   Email:   ' || v_check_email);
            DBMS_OUTPUT.PUT_LINE('   Имя:     ' || v_check_name);
            DBMS_OUTPUT.PUT_LINE('   Телефон: ' || v_check_phone);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь не найден в таблице CUSTOMERS.');
        END;
    ELSE
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
        DBMS_OUTPUT.PUT_LINE(' ДОСТУП ЗАПРЕЩЕН: Вы не можете просматривать чужие данные.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-------------------------------------------------------------------------------
--                          генерируем хэш пароль 
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_plain_text VARCHAR2(50) := '123';
    v_hashed_value RAW(255);
BEGIN
    -- Хеширование пароля (используем SHA-256)
    SELECT DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(v_plain_text, 'AL32UTF8'), 
                            DBMS_CRYPTO.HASH_SH256)
    INTO v_hashed_value FROM DUAL;
    
    DBMS_OUTPUT.PUT_LINE('Введенный пароль: ' || v_plain_text);
    DBMS_OUTPUT.PUT_LINE('Хеш для передачи (RAW): ' || v_hashed_value);
    
    -- Сохраните это значение: v_hashed_value
END;
/
-------------------------------------------------------------------------------
-- ШАГ 10:               Изменение пользователя (логин,пароль,статус)
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    -- 👇 ПРОСТО ПОМЕНЯЙТЕ ИМЯ ЗДЕСЬ ДЛЯ ТЕСТА ДРУГОГО КЛИЕНТА
    v_target_user VARCHAR2(50) := UPPER('KATE'); 
    
    v_new_hash    VARCHAR2(255) := 'NEW_TEST_HASH_999';
    v_current_auth VARCHAR2(50) := UPPER(USER);
    v_cust_exists NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('   ТЕСТ: СМЕНА ПОЛЬЗОВАТЕЛЯ И ПРОВЕРКА ПРАВ       ');
    DBMS_OUTPUT.PUT_LINE('   Выполняет: ' || v_current_auth || ' -> Цель: ' || v_target_user);
    DBMS_OUTPUT.PUT_LINE('==================================================');

    -- 1. Подготовка данных для цели (чтобы не было "Не указано")
    SELECT COUNT(*) INTO v_cust_exists 
    FROM BOOKSTORE_USER.CUSTOMERS c
    JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
    WHERE UPPER(u.username) = v_target_user;

    IF v_cust_exists = 0 THEN
        -- Создаем профиль, если его нет (нужны права Админа на этот INSERT)
        INSERT INTO BOOKSTORE_USER.CUSTOMERS (user_id, full_name, email, phone, address)
        SELECT user_id, 'Тестовый Клиент ' || v_target_user, v_target_user || '@mail.com', '+375290000000', 'Адрес по умолчанию'
        FROM BOOKSTORE_USER.USERS WHERE UPPER(username) = v_target_user;
    END IF;
    COMMIT;

    -- 2. Вызов процедуры безопасности
    -- Если вы Клиент и пытаетесь поменять другого Клиента, здесь сработает защита
    BOOKSTORE_USER.MANAGE_USER_SECURITY_UPDATE(
        p_current_username  => v_target_user,
        p_new_password_hash => v_new_hash,
        p_new_status        => 'ACTIVE'
    );

    -- 3. Вывод результата
    DECLARE
        v_res_status VARCHAR2(20);
        v_res_email  VARCHAR2(100);
        v_res_name   VARCHAR2(100);
    BEGIN
        SELECT u.status, c.email, c.full_name 
        INTO v_res_status, v_res_email, v_res_name
        FROM BOOKSTORE_USER.USERS u
        LEFT JOIN BOOKSTORE_USER.CUSTOMERS c ON u.user_id = c.user_id
        WHERE UPPER(u.username) = v_target_user;

        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
        IF BOOKSTORE_USER.HAS_ROLE(v_current_auth, 'Admin') THEN
            DBMS_OUTPUT.PUT_LINE(' ОТЧЕТ АДМИНИСТРАТОРА ПО ПОЛЬЗОВАТЕЛЮ ' || v_target_user);
            DBMS_OUTPUT.PUT_LINE('   ФИО:   ' || v_res_name);
            DBMS_OUTPUT.PUT_LINE('   Email: ' || v_res_email);
        ELSE
            DBMS_OUTPUT.PUT_LINE(' Статус профиля [' || v_target_user || '] обновлен.');
            DBMS_OUTPUT.PUT_LINE(' Подробные данные скрыты.');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь ' || v_target_user || ' не найден в системе.');
    END;

    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
------------------------------------------------------------------------------
--                                Пытаемся изменить от имени клиента
------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    -- Клиент тестирует самого себя
    v_target_user VARCHAR2(50) := UPPER(USER); 
    v_new_hash    VARCHAR2(255) := 'CLIENT_NEW_HASH_123';
    v_current_auth VARCHAR2(50) := UPPER(USER);
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('   ТЕСТ ПРАВ ДОСТУПА КЛИЕНТА: ' || v_current_auth);
    DBMS_OUTPUT.PUT_LINE('==================================================');

    -- 1. Вызов процедуры безопасности (РАЗРЕШЕНО)
    -- Процедура сама сделает UPDATE внутри, используя права владельца (Definer Rights)
    BOOKSTORE_USER.MANAGE_USER_SECURITY_UPDATE(
        p_current_username  => v_target_user,
        p_new_password_hash => v_new_hash,
        p_new_status        => 'ACTIVE'
    );

    -- 2. Проверка результата
    DECLARE
        v_res_status VARCHAR2(20);
    BEGIN
        SELECT status INTO v_res_status
        FROM BOOKSTORE_USER.USERS
        WHERE UPPER(username) = v_target_user;

        DBMS_OUTPUT.PUT_LINE(' Доступ через процедуру подтвержден.');
        DBMS_OUTPUT.PUT_LINE(' Статус вашего профиля: ' || v_res_status);
        DBMS_OUTPUT.PUT_LINE(' Личные данные ФИО/Email скрыты от прямого SELECT.');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Профиль не найден.');
    END;

    DBMS_OUTPUT.PUT_LINE('==================================================');
END;
/
-------------------------------------------------------------------------------
-- ШАГ 10: ТЕСТ:                Просмотр лога
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
EXEC BOOKSTORE_USER.ADMIN_VIEW_SYSTEM_LOGS;

-------------------------------------------------------------------------
--                    Просмотр заблокированных пользователей
-------------------------------------------------------------------------
SET SERVEROUTPUT ON;
BEGIN
    -- ТЕСТ 1: Найти конкретного пользователя "Ivan" (независимо от статуса)
    DBMS_OUTPUT.PUT_LINE('--- Поиск конкретного человека ---');
    BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS(
        p_username => 'Ivan'
    );
    
    DBMS_OUTPUT.PUT_LINE('');

    -- ТЕСТ 2: Найти всех "BLOCKED" (как раньше)
    DBMS_OUTPUT.PUT_LINE('--- Поиск всех заблокированных ---');
    BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS(
        p_status => 'BLOCKED'
    );

    DBMS_OUTPUT.PUT_LINE('');

    -- ТЕСТ 3: Комбо (Найти Ивана, но только если он заблокирован)
    DBMS_OUTPUT.PUT_LINE('--- Поиск заблокированного Ивана ---');
    BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS(
        p_username => 'Ivan',
        p_status   => 'BLOCKED'
    );
END;
/
------------------------------------------------------------------------------
--                           Просмотр всех пользоватеелй
------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
EXEC CHECK_ACCOUNTS();
-------------------------------------------------------------------------
--                          Генеральная статистика
---------------------------------------------------------------------------
SET SERVEROUTPUT ON;
DECLARE
    v_ord  NUMBER;
    v_cust NUMBER;
    v_book NUMBER;
    v_sold NUMBER;
BEGIN
    -- Вызываем защищенную процедуру
    BOOKSTORE_USER.GET_GENERAL_STATS(v_ord, v_cust, v_book, v_sold);
    
    -- Выводим результат (если доступ разрешен, там будут цифры)
    IF v_ord > 0 OR v_book > 0 THEN
        DBMS_OUTPUT.PUT_LINE('--- ИТОГОВЫЙ ОТЧЕТ ---');
        DBMS_OUTPUT.PUT_LINE('Всего заказов:   ' || v_ord);
        DBMS_OUTPUT.PUT_LINE('Всего клиентов:  ' || v_cust);
        DBMS_OUTPUT.PUT_LINE('Книг в наличии:  ' || v_book);
        DBMS_OUTPUT.PUT_LINE('Продано товаров: ' || v_sold);
    END IF;
END;
/
------------------------------------------------------------------------------
--                             Популярные заказы
------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
EXEC BOOKSTORE_USER.SHOW_POPULAR_BOOKS(3);
--------------------------------------------------------------------------------
--                             История заказов клиента 
--------------------------------------------------------------------------------
EXEC BOOKSTORE_USER.CLIENT_GET_MY_HISTORY('anna');
-------------------------------------------------------------------------------
--                      ВСЕ ПОЛЬЗОВАТЕЛИ ИЛИ КОНКРЕТНЫЙ
------------------------------------------------------------------------------
EXEC GET_USERS_REPORT();

-- ИЛИ
EXEC GET_USERS_REPORT('anna'); 



