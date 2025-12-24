SELECT u.username, r.role_name 
FROM BOOKSTORE_USER.USERS u
JOIN BOOKSTORE_USER.USER_ROLES ur ON u.user_id = ur.user_id
JOIN BOOKSTORE_USER.ROLES r ON ur.role_id = r.role_id
WHERE UPPER(u.username) = 'SELLERUSER';

-- 1. Даем право Продавцу и Клиенту запускать саму функцию
GRANT EXECUTE ON BOOKSTORE_USER.HAS_ROLE TO SellerUser;
GRANT EXECUTE ON BOOKSTORE_USER.HAS_ROLE TO ClientUser;

-- 2. Даем право на чтение таблиц, которые используются внутри функции
-- Без этого функция внутри "упадет" с ошибкой ORA-00942
GRANT SELECT ON BOOKSTORE_USER.USERS TO SellerUser;
GRANT SELECT ON BOOKSTORE_USER.ROLES TO SellerUser;

GRANT SELECT ON BOOKSTORE_USER.USERS TO ClientUser;
GRANT SELECT ON BOOKSTORE_USER.ROLES TO ClientUser;
-----------------------------------------------------------------------------
--                            Функция проверки доступа к процедуре
-----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION BOOKSTORE_USER.HAS_ROLE(
    p_username IN VARCHAR2, 
    p_role_name IN VARCHAR2
) RETURN BOOLEAN 
AUTHID DEFINER  -- Функция будет иметь доступ к таблицам Админа сама по себе
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM BOOKSTORE_USER.USERS u
    JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
    WHERE UPPER(u.username) = UPPER(p_username)
      AND UPPER(r.role_name) = UPPER(p_role_name);

    RETURN v_count > 0;
END;
/

-- Проверяем, какая роль у продавца в таблице
SELECT u.username, r.role_name 
FROM BOOKSTORE_USER.USERS u
JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
WHERE UPPER(u.username) = 'SELLERUSER';

BEGIN
    -- 1. Убедимся, что роль 'Seller' существует
    INSERT INTO BOOKSTORE_USER.ROLES (role_name)
    SELECT 'Seller' FROM DUAL 
    WHERE NOT EXISTS (SELECT 1 FROM BOOKSTORE_USER.ROLES WHERE role_name = 'Seller');

    -- 2. Добавляем пользователя SELLERUSER в таблицу USERS
    -- (Если он уже есть, но без роли, мы его обновим, если нет - вставим)
    MERGE INTO BOOKSTORE_USER.USERS u
    USING (SELECT 'SELLERUSER' as username FROM DUAL) src
    ON (UPPER(u.username) = src.username)
    WHEN NOT MATCHED THEN
        INSERT (username, password_hash, role_id, status)
        VALUES ('SELLERUSER', 'temporary_hash', (SELECT role_id FROM BOOKSTORE_USER.ROLES WHERE role_name = 'Seller'), 'ACTIVE')
    WHEN MATCHED THEN
        UPDATE SET role_id = (SELECT role_id FROM BOOKSTORE_USER.ROLES WHERE role_name = 'Seller'),
                   status = 'ACTIVE';

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✅ Продавец SELLERUSER успешно зарегистрирован в таблице USERS с ролью Seller.');
END;
/


UPDATE BOOKSTORE_USER.USERS 
SET role_id = (SELECT role_id FROM BOOKSTORE_USER.ROLES WHERE role_name = 'Seller')
WHERE username = 'SellerUser';
COMMIT;

SELECT u.username, r.role_name 
FROM BOOKSTORE_USER.USERS u
JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
WHERE UPPER(u.username) = UPPER(USER);
-- 1. Узнаем ID роли админа
DECLARE
    v_admin_role_id NUMBER;
    v_sys_user VARCHAR2(50) := UPPER(USER); -- Автоматически берет ваше текущее имя
BEGIN
    SELECT role_id INTO v_admin_role_id FROM BOOKSTORE_USER.ROLES WHERE UPPER(role_name) = 'ADMIN';

    -- 2. Добавляем системного пользователя в таблицу USERS приложения
    INSERT INTO BOOKSTORE_USER.USERS (username, password_hash, role_id, status)
    VALUES (v_sys_user, 'SYSTEM_AUTH', v_admin_role_id, 'ACTIVE');
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(' Системный пользователь ' || v_sys_user || ' добавлен в таблицу как Admin!');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('ℹ️ Пользователь уже был в таблице, просто обновим его роль.');
        UPDATE BOOKSTORE_USER.USERS 
        SET role_id = v_admin_role_id 
        WHERE UPPER(username) = v_sys_user;
        COMMIT;
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Роль Admin не найдена в таблице ROLES!');
END;
/
-------------------------------------------------------------------------
--                         Служебная процедура журналирования
-------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.LOG_ACTION(
    p_user    IN VARCHAR2,
    p_table   IN VARCHAR2,
    p_action  IN VARCHAR2,
    p_details IN VARCHAR2
) IS
    PRAGMA AUTONOMOUS_TRANSACTION; -- Пишем лог, даже если основная операция упадет
BEGIN
    INSERT INTO BOOKSTORE_USER.AUDIT_LOG (
        who, 
        what_table, 
        action, 
        details_json -- Ваша колонка называется так
    ) VALUES (
        p_user, 
        p_table, 
        p_action, 
        p_details
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- Если лог сломался, мы не должны ломать основную программу
        -- Просто выведем ошибку в консоль для отладки
        DBMS_OUTPUT.PUT_LINE(' Ошибка записи лога: ' || SQLERRM);
        ROLLBACK;
END;
/


--------------------------------------------------------------------------
--                               Регистрация покупателя
--------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE MANAGE_CUSTOMER_ADD(
    p_username IN VARCHAR2,
    p_password IN VARCHAR2,
    p_full_name IN VARCHAR2,
    p_email IN VARCHAR2,
    p_phone IN VARCHAR2
) IS
    v_user_id NUMBER;
    v_role_id NUMBER;
    v_phone_exists NUMBER;
BEGIN
--валидация
-- 1. Проверка на пустоту
    IF p_username IS NULL OR TRIM(p_username) = '' THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Поле "Логин" не может быть пустым.');
        RETURN; -- <--- ПРЕРЫВАЕМ ПРОЦЕДУРУ, ВЫХОДИМ
    END IF;

    -- 2. Проверка длины пароля
    IF LENGTH(p_password) < 6 THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Пароль слишком простой (нужно минимум 6 символов).');
        RETURN; -- <--- ВЫХОДИМ
    END IF;

    -- 3. Проверка формата Email
    IF p_email NOT LIKE '%@%.%' THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Некорректный Email (отсутствует @ или точка).');
        RETURN; -- <--- ВЫХОДИМ
    END IF;
    -- 4. номер телефона
    IF NOT REGEXP_LIKE(p_phone, '^\+?[0-9]{10,15}$') THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Некорректный телефон! Допустимы только цифры (10-15 шт), можно "+".');
        DBMS_OUTPUT.PUT_LINE('   Пример RU: +79991112233 или 89991112233');
         DBMS_OUTPUT.PUT_LINE('   Пример BY: +375291234567 или 80291234567');
        RETURN; -- Выходим
    END IF;
    -- 3.  ПРОВЕРКА НА УНИКАЛЬНОСТЬ НОМЕРА ТЕЛЕФОНА
    SELECT COUNT(*) INTO v_phone_exists FROM customers WHERE phone = p_phone;
    IF v_phone_exists > 0 THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Покупатель с номером ' || p_phone || ' уже существует.');
        RETURN;
    END IF;
    -- Проверка роли
    BEGIN
        SELECT role_id INTO v_role_id FROM roles WHERE role_name = 'Client';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Ошибка: Роль "Client" не найдена. Запустите INIT_ROLES.');
            RETURN; -- Выход из процедуры
    END;

    -- Вставка
    INSERT INTO users (username, password_hash, role_id, status)
    VALUES (p_username, p_password, v_role_id, 'ACTIVE')
    RETURNING user_id INTO v_user_id;

    INSERT INTO customers (user_id, full_name, email, phone)
    VALUES (v_user_id, p_full_name, p_email, p_phone);

    LOG_ACTION(USER, 'CUSTOMERS', 'INSERT', '{"username": "'||p_username||'"}');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Покупатель ' || p_username || ' успешно добавлен.');

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Пользователь с таким логином или Email уже существует.');
        ROLLBACK;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Системная ошибка регистрации: ' || SQLERRM);
        ROLLBACK;
END;
/
-------------------------------------------------------------------------------
--                                Вход пользователя
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.LOGIN(
    p_username IN VARCHAR2,
    p_password IN VARCHAR2
) IS
    v_stored_password VARCHAR2(100);
    v_status          VARCHAR2(50);
    v_user_id         NUMBER;
BEGIN
    -- 1. Ищем пользователя
    SELECT user_id, password_hash, status 
    INTO v_user_id, v_stored_password, v_status
    FROM BOOKSTORE_USER.USERS 
    WHERE username = p_username;

    -- === БЛОК ОТЛАДКИ (Покажет правду) ===
    DBMS_OUTPUT.PUT_LINE('--- DEBUG INFO ---');
    DBMS_OUTPUT.PUT_LINE('Вижу статус в базе: [' || v_status || ']');
    -- =====================================

    -- 2. Проверяем статус (Добавили TRIM на случай пробелов)
    IF TRIM(v_status) = 'BLOCKED' OR TRIM(v_status) = 'INACTIVE' THEN
        DBMS_OUTPUT.PUT_LINE(' ВХОД ЗАПРЕЩЕН: Ваш аккаунт заблокирован.');
        
        -- Логируем JSON
        BOOKSTORE_USER.LOG_ACTION(p_username, 'AUTH', 'LOGIN_FAILED', '{"reason": "Account BLOCKED"}');
        RETURN;
    END IF;

    -- 3. Проверяем пароль
    IF p_password != v_stored_password THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Неверный пароль.');
        BOOKSTORE_USER.LOG_ACTION(p_username, 'AUTH', 'LOGIN_FAILED', '{"reason": "Wrong password"}');
        RETURN;
    END IF;

    -- 4. Успех
    DBMS_OUTPUT.PUT_LINE(' Добро пожаловать, ' || p_username || '!');
    BOOKSTORE_USER.LOG_ACTION(p_username, 'AUTH', 'LOGIN_SUCCESS', '{"status": "Logged in"}');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь не найден.');
END;
/
-----------------------------------------------------------------------------
--                     Блокирование покупателя
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.TOGGLE_USER_STATUS (
    p_user_id IN NUMBER,
    p_new_status IN VARCHAR2, -- 'BLOCKED' или 'ACTIVE'
    p_reason IN VARCHAR2 DEFAULT NULL
) IS
    v_username       VARCHAR2(50);
    v_current_status VARCHAR2(10);
    v_log_action     VARCHAR2(10);
    v_db_command     VARCHAR2(50);
    v_current_user   VARCHAR2(50) := UPPER(USER);
BEGIN
    -- 1. Получаем имя пользователя и текущий статус
    BEGIN
        SELECT username, status INTO v_username, v_current_status
        FROM BOOKSTORE_USER.USERS
        WHERE user_id = p_user_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь с ID ' || p_user_id || ' не найден.');
            RETURN;
    END;

    -- ️ 2. ПРОВЕРКА ПРАВ ДОСТУПА
    IF NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Admin') 
       AND UPPER(v_current_user) != UPPER(v_username) THEN
       
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА ДОСТУПА: Недостаточно прав для изменения этого пользователя.');
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'SECURITY', 'SECURITY_VIOLATION', 
            '{"attempt_on_id": '||p_user_id||', "target_user": "'||v_username||'"}');
        RETURN;
    END IF;

    -- 3. Проверка на дублирование статуса
    IF v_current_status = p_new_status THEN
        DBMS_OUTPUT.PUT_LINE('️ Статус пользователя ' || v_username || ' уже "' || p_new_status || '".');
        RETURN;
    END IF;

    -- 4. Подготовка команд
    IF p_new_status = 'BLOCKED' THEN
        v_db_command := 'ACCOUNT LOCK';
        v_log_action := 'BLOCK';
    ELSIF p_new_status = 'ACTIVE' THEN
        v_db_command := 'ACCOUNT UNLOCK';
        v_log_action := 'UNBLOCK';
    ELSE
        RAISE_APPLICATION_ERROR(-20007, 'Недопустимый статус. Используйте ACTIVE или BLOCKED.');
    END IF;

    -- 5. Обновление в таблице приложения
    UPDATE BOOKSTORE_USER.USERS
    SET status = p_new_status
    WHERE user_id = p_user_id;

    -- 🛠️ 6. СИСТЕМНАЯ БЛОКИРОВКА (С ЗАЩИТОЙ ОТ ORA-01918)
    BEGIN
        EXECUTE IMMEDIATE 'ALTER USER ' || v_username || ' ' || v_db_command;
        DBMS_OUTPUT.PUT_LINE(' Системная запись ' || v_username || ' обновлена в Oracle.');
    EXCEPTION
        WHEN OTHERS THEN
            -- Если пользователя нет в Oracle, мы просто игнорируем системную ошибку
            DBMS_OUTPUT.PUT_LINE(' Инфо: Схема ' || v_username || ' не найдена в СУБД (Блокировка только в приложении).');
    END;
    
    -- 7. Логирование и завершение
    BOOKSTORE_USER.LOG_ACTION(v_current_user, 'USERS', v_log_action, 
        '{"user_id": '||p_user_id||', "username": "'||v_username||'", "status": "'||p_new_status||'", "reason": "'||p_reason||'"}');

    DBMS_OUTPUT.PUT_LINE(' Статус пользователя ' || v_username || ' успешно изменен на ' || p_new_status);
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Критическая ошибка: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Выдача прав администратору (если не выдавали ранее)
GRANT EXECUTE ON BOOKSTORE_USER.TOGGLE_USER_STATUS TO RLAdmin;
COMMIT;
-------------------------------------------------------------------------------
--                      Изменение данных покупателя(емаил и телефон)
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_CUSTOMER_DATA_UPDATE(
    p_username      IN VARCHAR2,
    p_new_full_name IN VARCHAR2 DEFAULT NULL,
    p_new_email     IN VARCHAR2 DEFAULT NULL,
    p_new_phone     IN VARCHAR2 DEFAULT NULL,
    p_new_address   IN VARCHAR2 DEFAULT NULL
) IS
    v_current_user   VARCHAR2(50) := UPPER(USER);
    v_target_user_id NUMBER;
    v_phone_owner    VARCHAR2(50);
BEGIN
    -- 🛡️ ЗАЩИТА №1: Обработка дубликатов логинов (ORA-01422)
    BEGIN
        SELECT user_id INTO v_target_user_id 
        FROM BOOKSTORE_USER.USERS 
        WHERE UPPER(username) = UPPER(p_username)
        FETCH FIRST 1 ROWS ONLY; -- Берем только ОДНУ строку, даже если их много
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь ' || p_username || ' не найден.');
            RETURN;
    END;

    -- 🛡️ ЗАЩИТА №2: Проверка прав доступа
    IF NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Admin') 
       AND UPPER(v_current_user) != UPPER(p_username) THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Нет прав на изменение чужого профиля!');
        RETURN;
    END IF;

    -- 🛡️ ЗАЩИТА №3: Проверка уникальности телефона при смене
    IF p_new_phone IS NOT NULL THEN
        BEGIN
            SELECT u.username INTO v_phone_owner
            FROM BOOKSTORE_USER.CUSTOMERS c
            JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
            WHERE c.phone = p_new_phone 
              AND c.user_id != v_target_user_id -- Не считаем самого себя
            FETCH FIRST 1 ROWS ONLY;

            DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Номер ' || p_new_phone || ' уже занят пользователем ' || v_phone_owner);
            RETURN;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN NULL; -- Номер свободен
        END;
    END IF;

    -- 4. Само обновление
    UPDATE BOOKSTORE_USER.CUSTOMERS
    SET full_name = NVL(p_new_full_name, full_name),
        email     = NVL(p_new_email, email),
        phone     = NVL(p_new_phone, phone),
        address   = NVL(p_new_address, address)
    WHERE user_id = v_target_user_id;

    IF SQL%ROWCOUNT > 0 THEN
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'CUSTOMERS', 'UPDATE', '{"target": "'||p_username||'"}');
        DBMS_OUTPUT.PUT_LINE(' Профиль ' || p_username || ' успешно обновлен.');
    END IF;
    
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Непредвиденная ошибка: ' || SQLERRM);
        ROLLBACK;
END;
/

-------------------------------------------------------------------------------
--            Изменение данных безопасности покупателя (Логин, Пароль, Статус)
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE MANAGE_USER_SECURITY_UPDATE(
    p_current_username  IN VARCHAR2,
    p_new_username      IN VARCHAR2 DEFAULT NULL,
    p_new_password_hash IN VARCHAR2 DEFAULT NULL, 
    p_new_status        IN VARCHAR2 DEFAULT NULL 
) IS
    v_user_id        NUMBER;
    v_current_user   VARCHAR2(50) := UPPER(USER);
    -- 👇 ВОТ ЭТА СТРОКА БЫЛА ПРОПУЩЕНА
    v_actual_db_user VARCHAR2(50); 
BEGIN
    -- 1. Находим пользователя и сохраняем его точное имя
    BEGIN
        SELECT user_id, username INTO v_user_id, v_actual_db_user
        FROM USERS
        WHERE UPPER(username) = UPPER(p_current_username);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Пользователь ' || p_current_username || ' не найден.');
            RETURN;
    END;

    -- ️ 2. ПРОВЕРКА ПРАВ
    IF NOT HAS_ROLE(v_current_user, 'Admin') 
       AND UPPER(v_current_user) != UPPER(v_actual_db_user) THEN
       
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Нет прав на изменение данных ' || v_actual_db_user);
        LOG_ACTION(v_current_user, 'SECURITY', 'UNAUTHORIZED_UPDATE', '{"target": "'||v_actual_db_user||'"}');
        RETURN;
    END IF;

    -- 3. ОБНОВЛЕНИЕ
    UPDATE USERS
    SET
        username = NVL(p_new_username, username),
        password_hash = NVL(p_new_password_hash, password_hash),
        status = NVL(p_new_status, status)
    WHERE user_id = v_user_id;

    -- 4. СИНХРОНИЗАЦИЯ СУБД (LOCK/UNLOCK)
    IF p_new_status IS NOT NULL THEN
        BEGIN
            IF p_new_status = 'BLOCKED' THEN
                EXECUTE IMMEDIATE 'ALTER USER ' || v_actual_db_user || ' ACCOUNT LOCK';
            ELSIF p_new_status = 'ACTIVE' THEN
                EXECUTE IMMEDIATE 'ALTER USER ' || v_actual_db_user || ' ACCOUNT UNLOCK';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN NULL; -- Если системного юзера нет, пропускаем
        END;
    END IF;

    -- 5. ЛОГИРОВАНИЕ
    LOG_ACTION(v_current_user, 'USERS', 'SECURITY_UPDATE', 
        '{"user_id": '||v_user_id||', "old_name": "'||v_actual_db_user||'", "new_name": "'||p_new_username||'"}');
        
    DBMS_OUTPUT.PUT_LINE(' Данные для ' || v_actual_db_user || ' успешно обновлены.');
    COMMIT;

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Логин ' || p_new_username || ' уже занят.');
        ROLLBACK;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Системная ошибка: ' || SQLERRM);
        ROLLBACK;
END;
/




BEGIN
    -- 1. Добавляем системного пользователя в таблицу приложения
    INSERT INTO BOOKSTORE_USER.USERS (username, password_hash, role_id, status)
    VALUES (
        'CLIENTUSER', 
        'TEST_HASH_QUICK', 
        (SELECT role_id FROM BOOKSTORE_USER.ROLES WHERE role_name = 'Customer'), 
        'ACTIVE'
    );

    -- 2. Создаем ему анкету (чтобы не было ошибок поиска)
    INSERT INTO BOOKSTORE_USER.CUSTOMERS (user_id, full_name, email, phone, address)
    SELECT user_id, 'Тестовый Клиент (Системный)', 'client@bookstore.by', '+3750000000', 'Минск'
    FROM BOOKSTORE_USER.USERS WHERE username = 'CLIENTUSER';

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(' Пользователь CLIENTUSER успешно зарегистрирован в системе.');
END;
/

----------------------------------------------------------------------------
-- 3.1                          Добавление товара
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_PRODUCT_ADD(
    p_isbn      IN VARCHAR2,
    p_title     IN VARCHAR2,
    p_author    IN VARCHAR2,
    p_price     IN NUMBER,
    p_stock     IN NUMBER,
    p_category  IN VARCHAR2,
    p_image_url IN VARCHAR2 DEFAULT NULL
) IS
    v_current_user VARCHAR2(50) := UPPER(USER);
BEGIN
    -- 🛡️ ПРОВЕРКА ПРАВ: Только 'Admin' или 'Seller' (Продавец)
    IF NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Admin') 
       AND NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Seller') THEN
        
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: У вас нет прав для добавления товаров в каталог!');
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'BOOKS', 'UNAUTHORIZED_ADD_ATTEMPT', '{"isbn": "'||p_isbn||'"}');
        RETURN;
    END IF;

    -- 1. Валидация данных
    IF p_price < 0 OR p_stock < 0 THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Цена или количество не могут быть отрицательными.');
        RETURN;
    END IF;

    -- 2. Вставка в таблицу
    INSERT INTO BOOKSTORE_USER.BOOKS (isbn, title, author, price, stock, category, image_url)
    VALUES (p_isbn, p_title, p_author, p_price, p_stock, p_category, p_image_url);
    
    DBMS_OUTPUT.PUT_LINE(' Книга "' || p_title || '" успешно добавлена в каталог.');

    -- 3. Логирование
    BOOKSTORE_USER.LOG_ACTION(v_current_user, 'BOOKS', 'INSERT', '{"isbn": "' || p_isbn || '"}');

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: ISBN ' || p_isbn || ' уже существует.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Системная ошибка: ' || SQLERRM);
END;
/
----------------------------------------------------------------------------
--                                  Изменение товара
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_PRODUCT_EDIT(
    p_book_id IN NUMBER,
    p_new_title IN VARCHAR2 DEFAULT NULL,
    p_new_author IN VARCHAR2 DEFAULT NULL,
    p_new_price IN NUMBER DEFAULT NULL,
    p_new_stock IN NUMBER DEFAULT NULL,
    p_new_category IN VARCHAR2 DEFAULT NULL
) IS
    v_discount_percent NUMBER;
    v_current_user     VARCHAR2(50) := UPPER(USER);
BEGIN
    -- 🛡️ 1. ПРОВЕРКА ПРАВ ДОСТУПА
    -- Разрешаем только ролям 'Admin' и 'Seller'
    IF NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Admin') 
       AND NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Seller') THEN
        
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА БЕЗОПАСНОСТИ: У клиента нет прав на редактирование каталога!');
        -- Логируем попытку несанкционированного доступа
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'BOOKS', 'UNAUTHORIZED_EDIT', '{"book_id": '||p_book_id||'}');
        RETURN; -- Выход из процедуры
    END IF;

    -- 2. Валидация (Проверка только если значение передано)
    IF p_new_price IS NOT NULL AND p_new_price <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Цена должна быть положительной. Операция отменена.');
        RETURN; -- Убираем ROLLBACK здесь, так как транзакция еще не началась
    END IF;
    
    IF p_new_stock IS NOT NULL AND p_new_stock < 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Запас не может быть отрицательным. Операция отменена.');
        RETURN;
    END IF;

    -- 3. Получаем текущую скидку
    SELECT COALESCE(discount_percent, 0) INTO v_discount_percent
    FROM BOOKSTORE_USER.BOOKS
    WHERE book_id = p_book_id;

    -- 4. Обновление
    UPDATE BOOKSTORE_USER.BOOKS 
    SET 
        title = COALESCE(p_new_title, title),
        author = COALESCE(p_new_author, author),
        category = COALESCE(p_new_category, category),
        price = COALESCE(p_new_price, price),
        stock = COALESCE(p_new_stock, stock),
        price_after_discount = COALESCE(p_new_price, price) * (1 - v_discount_percent / 100)
    WHERE book_id = p_book_id;

    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Товар с ID ' || p_book_id || ' не найден.');
    ELSE
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'BOOKS', 'BOOK_UPDATE_FULL', 
            '{"book_id": '||p_book_id||', "editor": "'||v_current_user||'"}');
        DBMS_OUTPUT.PUT_LINE('  Товар ID ' || p_book_id || ' успешно обновлен пользователем ' || v_current_user);
        COMMIT;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Книга с ID ' || p_book_id || ' не найдена.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('  Ошибка изменения товара: ' || SQLERRM);
        ROLLBACK;
END;
/
------------------------------------------------------------------------
--                               Удаление (Мягкое)
-------------------------------------------------------------------------
ALTER TABLE BOOKS ADD (is_archived NUMBER(1) DEFAULT 0 NOT NULL);
COMMENT ON COLUMN BOOKS.is_archived IS 'Флаг мягкого удаления: 1, если товар в архиве и недоступен для продажи.';

CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_PRODUCT_DELETE(
    p_book_id IN NUMBER
) IS
    v_count        NUMBER;
    v_current_user VARCHAR2(50) := UPPER(USER);
BEGIN
    -- ️ 1. ПРОВЕРКА ПРАВ ДОСТУПА
    -- Только 'Admin' или 'Seller' могут удалять товары
    IF NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Admin') 
       AND NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Seller') THEN
        
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА БЕЗОПАСНОСТИ: У вас нет прав на удаление товаров из каталога!');
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'BOOKS', 'UNAUTHORIZED_DELETE_ATTEMPT', '{"book_id": '||p_book_id||'}');
        RETURN;
    END IF;

    -- 2. Проверка наличия товара в заказах
    SELECT COUNT(*) INTO v_count 
    FROM BOOKSTORE_USER.ORDER_ITEMS 
    WHERE book_id = p_book_id;
    
    IF v_count > 0 THEN
        --  МЯГКОЕ УДАЛЕНИЕ (Архивация)
        -- Используем ваш новый флаг is_archived
        UPDATE BOOKSTORE_USER.BOOKS 
        SET stock = 0, 
            is_archived = 1,
            title = '[АРХИВ] ' || title 
        WHERE book_id = p_book_id;
        
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'BOOKS', 'SOFT_DELETE', '{"book_id": '||p_book_id||'}');
        DBMS_OUTPUT.PUT_LINE('️ Товар есть в заказах. Он деактивирован и перенесен в архив.');
    ELSE
        -- 🗑️ ПОЛНОЕ УДАЛЕНИЕ (Если заказов нет)
        DELETE FROM BOOKSTORE_USER.BOOKS WHERE book_id = p_book_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Товар с ID ' || p_book_id || ' не найден.');
        ELSE
            BOOKSTORE_USER.LOG_ACTION(v_current_user, 'BOOKS', 'DELETE', '{"book_id": '||p_book_id||'}');
            DBMS_OUTPUT.PUT_LINE(' Товар полностью удален из базы.');
        END IF;
    END IF;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка удаления товара: ' || SQLERRM);
        ROLLBACK;
END;
/
--------------------------------------------------------------------------------
--                               Управление заказами 
--------------------------------------------------------------------------------
-- Создание заказа
CREATE OR REPLACE PROCEDURE MANAGE_ORDER_CREATE(
    p_customer_id IN NUMBER,
    p_out_order_id OUT NUMBER
) IS
BEGIN
    INSERT INTO orders (customer_id, status, total_amount)
    VALUES (p_customer_id, 'Новый', 0)
    RETURNING order_id INTO p_out_order_id;
    
    LOG_ACTION(USER, 'ORDERS', 'INSERT', '{"customer_id": '||p_customer_id||'}');
    DBMS_OUTPUT.PUT_LINE('Заказ создан. ID: ' || p_out_order_id);
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -2291 THEN
            DBMS_OUTPUT.PUT_LINE('Ошибка: Указанный покупатель не существует.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Ошибка создания заказа: ' || SQLERRM);
        END IF;
        p_out_order_id := NULL; -- Возвращаем NULL при ошибке
END;
/
----------------------------------------------------------------------------
--                        Добавление товара в заказ
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_ORDER_CREATE(
    p_customer_id IN NUMBER,
    p_order_id OUT NUMBER
) IS
    v_status VARCHAR2(50);
    v_user_id NUMBER;
BEGIN
    -- 1. НАЙТИ и ПРОВЕРИТЬ СТАТУС ПОЛЬЗОВАТЕЛЯ (Критичный шаг)
    
    -- Сначала находим его user_id (родительский ID в таблице USERS)
    SELECT user_id INTO v_user_id
    FROM BOOKSTORE_USER.CUSTOMERS
    WHERE customer_id = p_customer_id;
    
    -- Затем проверяем статус в таблице USERS
    SELECT status INTO v_status
    FROM BOOKSTORE_USER.USERS
    WHERE user_id = v_user_id;
    
    -- Если пользователь заблокирован, запрещаем действие
    IF v_status = 'BLOCKED' OR v_status = 'INACTIVE' THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка безопасности: Пользователь заблокирован и не может совершать действия.');
        -- Обязательно логируем попытку
        BOOKSTORE_USER.LOG_ACTION('System', 'ORDERS', 'CREATE_DENIED', '{"reason": "User is BLOCKED", "customer_id": ' || p_customer_id || '}');
        p_order_id := NULL; -- Гарантируем, что ID не вернется
        RETURN; -- Выходим из процедуры
    END IF;

    -- 2. Если статус 'ACTIVE', продолжаем как раньше
    
    -- Вставка нового заказа
    INSERT INTO BOOKSTORE_USER.ORDERS (customer_id, order_date, total_amount, status)
    VALUES (p_customer_id, SYSDATE, 0, 'Новый')
    RETURNING order_id INTO p_order_id;

    -- Логирование
    BOOKSTORE_USER.LOG_ACTION('System', 'ORDERS', 'INSERT', '{"order_id": ' || p_order_id || ', "customer_id": ' || p_customer_id || '}');
    DBMS_OUTPUT.PUT_LINE('Заказ создан. ID: ' || p_order_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка: Профиль покупателя не найден.');
        p_order_id := NULL;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Системная ошибка: ' || SQLERRM);
        p_order_id := NULL;
        ROLLBACK;
END;
/
----------------------------------------------------------------------------
--                        Удаление товара из заказа
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_ORDER_REMOVE_ITEM(
    p_order_id IN NUMBER,
    p_book_id  IN NUMBER,
    p_qty_to_remove IN NUMBER DEFAULT NULL -- Количество для удаления (если NULL, удаляется все)
) IS
    v_order_status VARCHAR2(50);
    v_customer_id  NUMBER;
    v_user_id      NUMBER;
    v_user_status  VARCHAR2(50);
    v_item_price   NUMBER;
    v_current_qty  NUMBER;
BEGIN
    -- 1. ПРОВЕРКА ЗАКАЗА И СТАТУСА ПОЛЬЗОВАТЕЛЯ
    
    -- Получаем статус заказа и customer_id
    SELECT status, customer_id INTO v_order_status, v_customer_id
    FROM BOOKSTORE_USER.ORDERS
    WHERE order_id = p_order_id;
    
    -- Проверка: Можно менять только "Новый" заказ
    IF v_order_status != 'Новый' THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Невозможно удалить товар. Заказ уже имеет статус: ' || v_order_status);
        RETURN;
    END IF;

    -- Проверка: Заблокирован ли пользователь (ваша защита)
    SELECT user_id INTO v_user_id
    FROM BOOKSTORE_USER.CUSTOMERS WHERE customer_id = v_customer_id;
    
    SELECT status INTO v_user_status
    FROM BOOKSTORE_USER.USERS WHERE user_id = v_user_id;

    IF v_user_status = 'BLOCKED' OR v_user_status = 'INACTIVE' THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка безопасности: Пользователь заблокирован и не может менять заказ.');
        RETURN;
    END IF;
    
    -- 2. ЛОГИКА УДАЛЕНИЯ/УМЕНЬШЕНИЯ КОЛИЧЕСТВА
    
    -- Находим текущее количество
    SELECT qty, price INTO v_current_qty, v_item_price
    FROM BOOKSTORE_USER.ORDER_ITEMS
    WHERE order_id = p_order_id AND book_id = p_book_id;

    -- Если нужно удалить всю позицию (или больше, чем есть)
    IF p_qty_to_remove IS NULL OR p_qty_to_remove >= v_current_qty THEN
        
        DELETE FROM BOOKSTORE_USER.ORDER_ITEMS
        WHERE order_id = p_order_id AND book_id = p_book_id;
        
        DBMS_OUTPUT.PUT_LINE(' Позиция книги полностью удалена из заказа.');

    -- Иначе, уменьшаем количество
    ELSE
        
        UPDATE BOOKSTORE_USER.ORDER_ITEMS
        SET qty = qty - p_qty_to_remove
        WHERE order_id = p_order_id AND book_id = p_book_id;
        
        DBMS_OUTPUT.PUT_LINE(' Количество книги уменьшено на ' || p_qty_to_remove || ' шт.');
        
    END IF;

    -- 3. ОБНОВЛЕНИЕ ОБЩЕЙ СУММЫ ЗАКАЗА
    UPDATE BOOKSTORE_USER.ORDERS o
    SET o.total_amount = (
        SELECT NVL(SUM(oi.qty * oi.price), 0)
        FROM BOOKSTORE_USER.ORDER_ITEMS oi
        WHERE oi.order_id = p_order_id
    )
    WHERE o.order_id = p_order_id;
    
    COMMIT; -- Фиксация изменений
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Заказ или позиция книги не найдены.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Системная ошибка: ' || SQLERRM);
        ROLLBACK;
END;
/
-----------------------------------------------------------------------------
--                          Обновление статуса заказа
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_ORDER_UPDATE_STATUS(
    p_order_id IN NUMBER,
    p_new_status IN VARCHAR2
) IS
    v_current_status VARCHAR2(50);
    v_current_user   VARCHAR2(50) := UPPER(USER);
BEGIN
    -- ️ 1. ПРОВЕРКА ПРАВ ДОСТУПА: ТОЛЬКО АДМИН
    IF NOT BOOKSTORE_USER.HAS_ROLE(v_current_user, 'Admin') THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА БЕЗОПАСНОСТИ: У вас нет прав администратора для смены статуса заказа!');
        -- Логируем попытку (важно для аудита)
        BOOKSTORE_USER.LOG_ACTION(v_current_user, 'ORDERS', 'UNAUTHORIZED_STATUS_CHANGE', '{"order_id": '||p_order_id||'}');
        RETURN;
    END IF;

    -- 2. Узнаем текущий статус
    SELECT status INTO v_current_status 
    FROM BOOKSTORE_USER.ORDERS 
    WHERE order_id = p_order_id;

    -- 3. Проверка: Если статус уже такой же - выходим
    IF v_current_status = p_new_status THEN
        DBMS_OUTPUT.PUT_LINE('️ Инфо: Заказ № ' || p_order_id || ' УЖЕ имеет статус "' || p_new_status || '".');
        RETURN; 
    END IF;

    -- 4. Защита бизнес-логики: Нельзя менять статус "Оплачен"
    IF v_current_status = 'Оплачен' AND p_new_status != 'Оплачен' THEN
         DBMS_OUTPUT.PUT_LINE(' Ошибка: Нельзя изменить статус уже оплаченного заказа!');
         RETURN;
    END IF;

    -- 5. Обновляем статус
    UPDATE BOOKSTORE_USER.ORDERS
    SET status = p_new_status
    WHERE order_id = p_order_id;

    COMMIT; -- Фиксируем изменения

    DBMS_OUTPUT.PUT_LINE(' Статус заказа № ' || p_order_id || ' успешно изменен: ' || v_current_status || ' -> ' || p_new_status);
    BOOKSTORE_USER.LOG_ACTION(v_current_user, 'ORDERS', 'STATUS_UPDATE', '{"order_id": '||p_order_id||', "new_status": "'||p_new_status||'"}');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Заказ № ' || p_order_id || ' не найден.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Системная ошибка: ' || SQLERRM);
        ROLLBACK;
END;
/
--------------------------------------------------------------------------------
    --                               5. ЛОГИРОВАНИЕ 
    --              Мы просто перечисляем: КТО, ТАБЛИЦА, ДЕЙСТВИЕ, ДЕТАЛИ
--------------------------------------------------------------------------------    
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.SHOW_SECURITY_REPORT IS
    v_current_user VARCHAR2(50) := UPPER(USER);
    v_role         VARCHAR2(50);
BEGIN
    -- Получаем роль для заголовка
    BEGIN
        SELECT UPPER(r.role_name) INTO v_role
        FROM BOOKSTORE_USER.USERS u
        JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
        WHERE UPPER(u.username) = v_current_user;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_role := 'GUEST';
    END;

    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('️  СИСТЕМА МОНИТОРИНГА БЕЗОПАСНОСТИ BOOKSTORE');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' ТЕКУЩИЙ ПОЛЬЗОВАТЕЛЬ: ' || v_current_user);
    DBMS_OUTPUT.PUT_LINE('️ ПРИКЛАДНАЯ РОЛЬ:      ' || v_role);
    DBMS_OUTPUT.PUT_LINE(' ДАТА ОТЧЕТА:          ' || TO_CHAR(SYSDATE, 'DD.MM.YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    -- Если Админ — показываем логи
    IF v_role = 'ADMIN' THEN
        DBMS_OUTPUT.PUT_LINE(' ПОСЛЕДНИЕ СОБЫТИЯ В ЖУРНАЛЕ АУДИТА:');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
        FOR r IN (
            SELECT * FROM (
                SELECT ts, who, action, what_table FROM BOOKSTORE_USER.AUDIT_LOG ORDER BY ts DESC
            ) WHERE ROWNUM <= 5
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                '• [' || TO_CHAR(r.ts, 'HH24:MI') || '] ' || 
                RPAD(r.who, 12) || ' | ' || 
                RPAD(r.action, 20) || ' | Таблица: ' || r.what_table
            );
        END LOOP;
    ELSE
        -- Если не Админ — выводим предупреждение
        DBMS_OUTPUT.PUT_LINE('  ВНИМАНИЕ: Доступ к детальному логу ограничен.');
        DBMS_OUTPUT.PUT_LINE('Ваш уровень доступа позволяет только просмотр каталога.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/
-----------------------------------------------------------------------------
--                         Общая статистика(генеральная)
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.GET_GENERAL_STATS (
    p_total_orders      OUT NUMBER,
    p_total_customers   OUT NUMBER,
    p_total_books       OUT NUMBER,
    p_total_items_sold  OUT NUMBER
) IS
    v_current_user VARCHAR2(50) := UPPER(USER);
    v_role_in_db   VARCHAR2(50);
BEGIN
    -- 1. ОПРЕДЕЛЯЕМ РОЛЬ ПОЛЬЗОВАТЕЛЯ
    BEGIN
        SELECT UPPER(TRIM(r.role_name)) INTO v_role_in_db
        FROM BOOKSTORE_USER.USERS u
        JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
        WHERE UPPER(u.username) = v_current_user;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_role_in_db := 'GUEST';
    END;

    -- 2. ПРОВЕРКА: ТОЛЬКО ДЛЯ АДМИНА
    IF v_role_in_db != 'ADMIN' THEN
        -- Обнуляем выходные параметры
        p_total_orders      := 0;
        p_total_customers   := 0;
        p_total_books       := 0;
        p_total_items_sold  := 0;

        -- Логируем попытку несанкционированного доступа
        INSERT INTO BOOKSTORE_USER.AUDIT_LOG (who, what_table, action, details_json)
        VALUES (v_current_user, 'STATISTICS', 'UNAUTHORIZED_STATS_VIEW', '{"role_attempted":"'||v_role_in_db||'"}');
        COMMIT;

        DBMS_OUTPUT.PUT_LINE(' ОШИБКА ДОСТУПА: Статистика доступна только администратору.');
        RETURN; -- Прекращаем выполнение
    END IF;

    -- 3. ОСНОВНАЯ ЛОГИКА (только если проверку прошел)
    
    -- Считаем заказы
    SELECT COUNT(*) INTO p_total_orders FROM BOOKSTORE_USER.ORDERS;

    -- Считаем уникальных покупателей
    SELECT COUNT(DISTINCT CUSTOMER_ID) INTO p_total_customers FROM BOOKSTORE_USER.ORDERS;

    -- Считаем книги
    SELECT COUNT(*) INTO p_total_books FROM BOOKSTORE_USER.BOOKS;
    
    -- Считаем продажи
    SELECT NVL(SUM(QTY), 0) INTO p_total_items_sold FROM BOOKSTORE_USER.ORDER_ITEMS;

    DBMS_OUTPUT.PUT_LINE(' Статистика успешно сформирована для Администратора.');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка получения статистики: ' || SQLERRM);
        p_total_orders := 0;
        p_total_customers := 0;
        p_total_books := 0;
        p_total_items_sold := 0;
END;
/
-----------------------------------------------------------------------------
--                         Популярные заказы
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.GET_POPULAR_PRODUCTS (
    p_limit   IN NUMBER DEFAULT 5,
    p_cursor  OUT SYS_REFCURSOR
) IS
    v_current_user VARCHAR2(50) := UPPER(USER);
    v_role_in_db   VARCHAR2(50);
BEGIN
    -- 1. ОПРЕДЕЛЯЕМ РОЛЬ ПОЛЬЗОВАТЕЛЯ
    BEGIN
        SELECT UPPER(TRIM(r.role_name)) INTO v_role_in_db
        FROM BOOKSTORE_USER.USERS u
        JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
        WHERE UPPER(u.username) = v_current_user;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_role_in_db := 'GUEST';
    END;

    -- 2. ПРОВЕРКА ПРАВ
    IF v_role_in_db = 'ADMIN' THEN
        --  Доступ разрешен: открываем курсор с реальными данными
        OPEN p_cursor FOR
            SELECT 
                b.TITLE,
                b.AUTHOR,
                SUM(oi.QTY) as sold_count,
                SUM(oi.QTY * oi.PRICE) as total_revenue
            FROM BOOKSTORE_USER.ORDER_ITEMS oi
            JOIN BOOKSTORE_USER.BOOKS b ON oi.book_id = b.book_id
            GROUP BY b.book_id, b.TITLE, b.AUTHOR
            ORDER BY sold_count DESC
            FETCH FIRST p_limit ROWS ONLY;
            
        DBMS_OUTPUT.PUT_LINE(' Топ-продуктов сформирован для Администратора.');
    ELSE
        --  Доступ запрещен: открываем «пустой» курсор с заглушкой
        OPEN p_cursor FOR 
            SELECT 'ДОСТУП ЗАПРЕЩЕН' as TITLE, '---' as AUTHOR, 0 as sold_count, 0 as total_revenue FROM DUAL WHERE 1=0;
        
        -- Логируем попытку
        INSERT INTO BOOKSTORE_USER.AUDIT_LOG (who, what_table, action, details_json)
        VALUES (v_current_user, 'ORDER_ITEMS/BOOKS', 'UNAUTHORIZED_POPULAR_PRODUCTS_VIEW', '{"limit":' || p_limit || '}');
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА: У вас нет прав для просмотра аналитики продаж.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        OPEN p_cursor FOR SELECT NULL as TITLE, NULL as AUTHOR, 0 as sold_count, 0 as total_revenue FROM DUAL WHERE 1=0;
        DBMS_OUTPUT.PUT_LINE(' Ошибка процедуры: ' || SQLERRM);
END;
/
-----------------------------------------------------------------------------
--                                  публичная обертка
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.SHOW_POPULAR_BOOKS(p_limit IN NUMBER DEFAULT 5) IS
    v_cursor SYS_REFCURSOR;
    v_title  VARCHAR2(200);
    v_author VARCHAR2(200);
    v_count  NUMBER;
    v_rev    NUMBER;
    
    e_no_access EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_no_access, -6550); 
BEGIN
    -- Заголовок отчета
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('            АНАЛИТИЧЕСКИЙ ОТЧЕТ: ТОП ПРОДАЖ           ');
    DBMS_OUTPUT.PUT_LINE('==================================================');
    
    BEGIN
        -- Вызов защищенной аналитики
        BOOKSTORE_USER.GET_POPULAR_PRODUCTS(p_limit, v_cursor);
        
        DBMS_OUTPUT.PUT_LINE('  Запрошено позиций: ' || p_limit);
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 56, '-'));
        DBMS_OUTPUT.PUT_LINE(RPAD('НАЗВАНИЕ КНИГИ', 25) || ' | ' || RPAD('ПРОДАНО', 10) || ' | ' || 'ВЫРУЧКА');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 56, '-'));

        LOOP
            FETCH v_cursor INTO v_title, v_author, v_count, v_rev;
            EXIT WHEN v_cursor%NOTFOUND;
            
            -- Форматированный вывод строки
            DBMS_OUTPUT.PUT_LINE(
                RPAD(SUBSTR(v_title, 1, 23), 25) || ' | ' || 
                RPAD(v_count || ' шт.', 10) || ' | ' || 
                TO_CHAR(v_rev, '999,990.00') || ' руб.'
            );
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 56, '-'));
        DBMS_OUTPUT.PUT_LINE('  Отчет сформирован успешно: ' || TO_CHAR(SYSDATE, 'HH24:MI:SS'));
        CLOSE v_cursor;

    EXCEPTION
        WHEN e_no_access THEN
            -- Красивое оформление ошибки доступа
            DBMS_OUTPUT.PUT_LINE(' ');
            DBMS_OUTPUT.PUT_LINE('   ДОСТУП ЗАБЛОКИРОВАН');
            DBMS_OUTPUT.PUT_LINE('  =============================================');
            DBMS_OUTPUT.PUT_LINE('  Ошибка: Недостаточно прав (Требуется роль ADMIN)');
            DBMS_OUTPUT.PUT_LINE('  Действие: Попытка чтения коммерческой тайны');
            DBMS_OUTPUT.PUT_LINE('  ===============================================');
            DBMS_OUTPUT.PUT_LINE('  Данный инцидент был записан в журнал аудита.');
    END;
    
   
END;
/
-----------------------------------------------------------------------------
--                         ЗАКАЗЫ покупателя
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.CLIENT_GET_MY_HISTORY (
    p_username IN VARCHAR2 -- Логин клиента, чью историю хотим посмотреть
) IS
    v_current_user VARCHAR2(50) := UPPER(USER);
    v_role_in_db   VARCHAR2(50);
    v_found        BOOLEAN := FALSE;
BEGIN
    -- 1. ️ ПРОВЕРКА РОЛИ (Только ADMIN или SELLER)
    BEGIN
        SELECT UPPER(TRIM(r.role_name)) INTO v_role_in_db
        FROM BOOKSTORE_USER.USERS u
        JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
        WHERE UPPER(u.username) = v_current_user;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_role_in_db := 'GUEST';
    END;

    IF v_role_in_db NOT IN ('ADMIN', 'SELLER') THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА ДОСТУПА: Просмотр истории заказов клиентов разрешен только персоналу.');
        
        -- Логируем попытку доступа
        INSERT INTO BOOKSTORE_USER.AUDIT_LOG (who, what_table, action, details_json)
        VALUES (v_current_user, 'ORDERS', 'UNAUTHORIZED_HISTORY_VIEW', '{"target_client":"'||p_username||'"}');
        COMMIT;
        RETURN;
    END IF;

    -- 2. ОСНОВНАЯ ЛОГИКА
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('  ИСТОРИЯ ЗАКАЗОВ ДЛЯ КЛИЕНТА: ' || UPPER(p_username));
    DBMS_OUTPUT.PUT_LINE(' Сгенерировал: ' || v_current_user || ' (' || v_role_in_db || ')');
    DBMS_OUTPUT.PUT_LINE('==================================================');

    FOR r IN (
        SELECT o.order_id, o.order_date, o.status, o.total_amount
        FROM BOOKSTORE_USER.ORDERS o -- Используем базовую таблицу или вью
        WHERE o.customer_id = (
            SELECT c.customer_id
            FROM BOOKSTORE_USER.CUSTOMERS c
            JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
            WHERE UPPER(u.username) = UPPER(p_username)
        )
        ORDER BY o.order_date DESC
    ) LOOP
        v_found := TRUE;
        DBMS_OUTPUT.PUT_LINE(' Заказ № ' || r.order_id || ' от ' || TO_CHAR(r.order_date, 'DD.MM.YYYY'));
        DBMS_OUTPUT.PUT_LINE('   Статус: ' || r.status);
        DBMS_OUTPUT.PUT_LINE('   Сумма:  ' || TO_CHAR(r.total_amount, '999,990.00') || ' руб.');
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    END LOOP;

    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE('  ℹ️  У пользователя ' || p_username || ' заказов не найдено.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('--- Конец списка ---');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Произошла ошибка: ' || SQLERRM);
END;
/
------------------------------------------------------------------------------
--                               КАТАЛОГ
------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.CLIENT_SEARCH_BOOKS (
    p_keyword   IN VARCHAR2 DEFAULT NULL,
    p_category  IN VARCHAR2 DEFAULT NULL,
    p_max_price IN NUMBER   DEFAULT NULL,
    p_limit     IN NUMBER   DEFAULT 50
) IS
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.ENABLE(NULL); 
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE(' ПОИСК ПО КАТАЛОГУ (Топ ' || p_limit || ' результатов)');
    DBMS_OUTPUT.PUT_LINE('==================================================');

    FOR r IN (
        -- 👇 1. Добавили image_url в выборку
        SELECT title, author, category, price, stock, availability, isbn, image_url
        FROM BOOKSTORE_USER.BooksInfo
        WHERE 
            (p_keyword IS NULL OR 
             LOWER(title) LIKE '%'||LOWER(p_keyword)||'%' OR 
             LOWER(author) LIKE '%'||LOWER(p_keyword)||'%')
            AND
            (p_category IS NULL OR category = p_category)
            AND
            (p_max_price IS NULL OR price <= p_max_price)
        ORDER BY price ASC
        FETCH FIRST p_limit ROWS ONLY
    ) LOOP
        v_count := v_count + 1;
        
        DBMS_OUTPUT.PUT_LINE(' ' || r.title);
        DBMS_OUTPUT.PUT_LINE('   ️ Автор: ' || r.author);
        DBMS_OUTPUT.PUT_LINE('    Цена:  ' || r.price || ' руб.');
        
        IF r.availability = 'Да' THEN
            DBMS_OUTPUT.PUT_LINE('    В наличии (' || r.stock || ' шт.)');
        ELSE
            DBMS_OUTPUT.PUT_LINE('    Нет в наличии');
        END IF;
        
        -- 👇 2. Добавили вывод картинки (если она есть)
        IF r.image_url IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('    Картинка: ' || r.image_url);
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('    ISBN: ' || r.isbn);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    END LOOP;

    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(' Ничего не найдено.');
    ELSIF v_count = p_limit THEN
        DBMS_OUTPUT.PUT_LINE('️ Показаны первые ' || p_limit || ' книг. Уточните поиск.');
    ELSE
        DBMS_OUTPUT.PUT_LINE(' Найдено книг: ' || v_count);
    END IF;
END;
/
-------------------------------------------------------------------------------
--                           Детализация заказа(чек)
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.CLIENT_GET_ORDER_DETAILS (
    p_order_id IN NUMBER
) IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('===  ДЕТАЛИ ЗАКАЗА № ' || p_order_id || ' ===');
    
    FOR r IN (
        SELECT title, author, qty, price, total_item_price
        FROM BOOKSTORE_USER.OrderItemsInfo -- <--- ВАШЕ VIEW
        WHERE order_id = p_order_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(' ' || r.title);
        DBMS_OUTPUT.PUT_LINE('   ' || r.qty || ' шт. x ' || r.price || ' = ' || r.total_item_price || ' руб.');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('===================================');
END;
/
-----------------------------------------------------------------------------
--                                Досье клиента
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.CLIENT_BUY_BOOK_AUTO (
    p_username IN VARCHAR2,
    p_book_id  IN NUMBER,
    p_qty      IN NUMBER
) IS
    v_current_user VARCHAR2(50) := UPPER(USER);
    v_cust_id      NUMBER;
BEGIN
    -- РАСШИРЕННАЯ ПРОВЕРКА ДЛЯ ПРОДАВЦА
    IF v_current_user != UPPER(p_username) 
       AND v_current_user NOT IN ('ADMINUSER', 'BOOKSTORE_USER', 'SYSTEM', 'SELLERUSER') -- Добавьте сюда логин продавца
    THEN
        DBMS_OUTPUT.PUT_LINE(' ОШИБКА ДОСТУПА: Продавец ' || v_current_user || ' не имеет прав оформлять заказ на ' || p_username);
        RETURN;
    END IF;

    -- Ищем клиента (anna)
    SELECT customer_id INTO v_cust_id
    FROM BOOKSTORE_USER.CUSTOMERS c
    JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
    WHERE UPPER(u.username) = UPPER(p_username);

    -- Создаем заказ
    INSERT INTO BOOKSTORE_USER.ORDERS (customer_id, order_date, status, total_amount)
    VALUES (v_cust_id, SYSDATE, 'Новый', 0);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(' Заказ для ' || p_username || ' успешно оформлен продавцом ' || v_current_user);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: Клиент ' || p_username || ' не найден в базе.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' Ошибка: ' || SQLERRM);
END;
/
-----------------------------------------------------------------------------
--                         Ревизия пользователей
-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.SAFE_ADMIN_ACCOUNT_CHECK (
    p_username IN VARCHAR2 DEFAULT NULL
) IS
    -- Специальная переменная для перехвата системной ошибки "Нет доступа"
    e_no_privileges EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_no_privileges, -6550); 
BEGIN
    -- Попытка вызвать защищенную админскую процедуру
    BEGIN
        BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS(p_status => NULL, p_username => p_username);
    EXCEPTION
        WHEN e_no_privileges THEN
            -- Вместо системной ошибки выводим аккуратный текст
            DBMS_OUTPUT.PUT_LINE(' ');
            DBMS_OUTPUT.PUT_LINE('===================================================');
            DBMS_OUTPUT.PUT_LINE('             УВЕДОМЛЕНИЕ БЕЗОПАСНОСТИ             ');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE(' ОШИБКА: Запрошенный модуль требует прав АДМИНИСТРАТОРА.');
            DBMS_OUTPUT.PUT_LINE(' Ваша попытка доступа зафиксирована в журнале аудита.   ');
            DBMS_OUTPUT.PUT_LINE('');
    END;
END;
/
-------------------------------------------------------------------------------
--                             Чтение логов (было)
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.ADMIN_VIEW_LOGS (
    p_table_name IN VARCHAR2 DEFAULT NULL -- Какую таблицу проверяем? (NULL = все)
) IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================================================');
    DBMS_OUTPUT.PUT_LINE('️ АДМИН: Журнал аудита (View AuditLogInfo)');
    IF p_table_name IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('   Фильтр по таблице: ' || UPPER(p_table_name));
    END IF;
    DBMS_OUTPUT.PUT_LINE('==================================================');

    FOR r IN (
        SELECT ts, who, action, what_table, details_json
        FROM BOOKSTORE_USER.AuditLogInfo
        WHERE p_table_name IS NULL OR what_table = UPPER(p_table_name)
        ORDER BY ts DESC
        FETCH FIRST 10 ROWS ONLY -- Показываем только последние 10 записей
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(r.ts, 'HH24:MI') || '] Пользователь: ' || r.who);
        DBMS_OUTPUT.PUT_LINE('   Сделал: ' || r.action || ' в таблице ' || r.what_table);
        
        -- Обрезаем JSON, если он длинный, для удобства чтения
        IF r.details_json IS NOT NULL THEN
             DBMS_OUTPUT.PUT_LINE('   Детали: ' || SUBSTR(r.details_json, 1, 60));
        END IF;
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    END LOOP;
END;
/
-------------------------------------------------------------------------------
--                            Автооплата 
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.CLIENT_BUY_BOOK_AUTO (
    p_username IN VARCHAR2,
    p_isbn     IN VARCHAR2,
    p_qty      IN NUMBER DEFAULT 1
) IS
    v_cust_id  NUMBER;
    v_book_id  NUMBER;
    v_price    NUMBER;
    v_stock    NUMBER;
    v_order_id NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===  КЛИЕНТ: ПОКУПКА (АВТОМАТИЧЕСКАЯ) ===');

    -- 1. Находим ID покупателя по Логину
    BEGIN
        SELECT c.customer_id INTO v_cust_id
        FROM BOOKSTORE_USER.CUSTOMERS c
        JOIN BOOKSTORE_USER.USERS u ON c.user_id = u.user_id
        WHERE u.username = p_username;
        
        DBMS_OUTPUT.PUT_LINE(' Покупатель: ' || p_username || ' (ID: ' || v_cust_id || ')');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Клиент с логином "' || p_username || '" не найден.');
            RETURN;
    END;

    -- 2. Находим Книгу (С ИСПРАВЛЕНИЕМ ПРОБЕЛОВ - TRIM)
    BEGIN
        SELECT book_id, price, stock INTO v_book_id, v_price, v_stock
        FROM BOOKSTORE_USER.BOOKS
        WHERE TRIM(isbn) = TRIM(p_isbn) -- <--- Важный момент: убираем пробелы
          AND (is_archived = 0 OR is_archived IS NULL);

        -- Проверка наличия
        IF v_stock < p_qty THEN
             DBMS_OUTPUT.PUT_LINE(' Ошибка: Недостаточно товара (Остаток: ' || v_stock || ')');
             RETURN;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE(' Книга найдена. ID: ' || v_book_id || ', Цена: ' || v_price);

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' Ошибка: Книга с ISBN "' || p_isbn || '" не найдена (или в архиве).');
            RETURN;
    END;

    -- 3. Ищем открытую корзину ИЛИ создаем новую
    BEGIN
        -- Пробуем найти существующую корзину (статус 'Новый')
        SELECT order_id INTO v_order_id
        FROM BOOKSTORE_USER.ORDERS
        WHERE customer_id = v_cust_id AND status = 'Новый'
        FETCH FIRST 1 ROWS ONLY;
        
        DBMS_OUTPUT.PUT_LINE('ℹ️ Найдена открытая корзина № ' || v_order_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Корзины нет -> Создаем новую через ВАШУ процедуру
            DBMS_OUTPUT.PUT_LINE(' Корзины нет. Создаем новую...');
            
            BOOKSTORE_USER.MANAGE_ORDER_CREATE(
                p_customer_id => v_cust_id,
                p_order_id    => v_order_id -- Получаем ID обратно
            );
            
            -- Если процедура вернула NULL (например, юзер заблокирован), выходим
            IF v_order_id IS NULL THEN
                RETURN;
            END IF;
    END;

    -- 4. Добавляем товар в корзину через ВАШУ процедуру
    -- (Она сама спишет со склада и пересчитает сумму)
    BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM(
        p_order_id => v_order_id,
        p_book_id  => v_book_id,
        p_qty      => p_qty
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(' УСПЕХ: Покупка завершена.');
END;
/
-------------------------------------------------------------------------------
--                            ВСЕ ПОЛЬЗОВАТЕЛИ 
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.ADMIN_GET_ALL_USER_DATA (
    p_username_filter IN VARCHAR2 DEFAULT NULL
) IS
    v_current_user VARCHAR2(50) := UPPER(USER);
    v_role_name    VARCHAR2(50);
    v_found        BOOLEAN := FALSE;
BEGIN
    -- ️ 1. ПРОВЕРКА ПРАВ: Выясняем роль того, кто запустил процедуру
    BEGIN
        SELECT UPPER(r.role_name) INTO v_role_name
        FROM BOOKSTORE_USER.USERS u
        JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
        WHERE UPPER(u.username) = v_current_user;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_role_name := 'GUEST';
    END;

    -- Если не админ — блокируем выполнение
    IF v_role_name != 'ADMIN' AND v_current_user != 'BOOKSTORE_USER' THEN
        DBMS_OUTPUT.PUT_LINE(' ДОСТУП ЗАПРЕЩЕН: Данная информация доступна только Администратору.');
        RETURN;
    END IF;

    --  2. ВЫВОД ПОЛНОЙ ИНФОРМАЦИИ
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
    DBMS_OUTPUT.PUT_LINE(
        RPAD('ID', 5) || 
        RPAD('ЛОГИН', 15) || 
        RPAD('РОЛЬ', 12) || 
        RPAD('ФИО КЛИЕНТА', 25) || 
        RPAD('ТЕЛЕФОН', 15)
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));

    FOR r IN (
        SELECT 
            u.user_id, 
            u.username, 
            r.role_name, 
            c.full_name, 
            c.phone, 
            c.email
        FROM BOOKSTORE_USER.USERS u
        LEFT JOIN BOOKSTORE_USER.ROLES r ON u.role_id = r.role_id
        LEFT JOIN BOOKSTORE_USER.CUSTOMERS c ON u.user_id = c.user_id
        WHERE (p_username_filter IS NULL OR LOWER(u.username) LIKE '%'||LOWER(p_username_filter)||'%')
        ORDER BY u.user_id
    ) LOOP
        v_found := TRUE;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.user_id, 5) || 
            RPAD(r.username, 15) || 
            RPAD(NVL(r.role_name, 'НЕТ'), 12) || 
            RPAD(NVL(r.full_name, '---'), 25) || 
            RPAD(NVL(r.phone, '---'), 15)
        );
    END LOOP;

    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE('Пользователи не найдены.');
    END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
END;
/