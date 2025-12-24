GRANT EXECUTE ON BOOKSTORE_USER.IS_ADMIN TO PUBLIC;
GRANT EXECUTE ON BOOKSTORE_USER.TOGGLE_USER_STATUS TO PUBLIC;
GRANT EXECUTE ON BOOKSTORE_USER.HAS_ROLE TO PUBLIC;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_USER_SECURITY_UPDATE TO PUBLIC;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_PRODUCT_ADD TO PUBLIC;
GRANT EXECUTE ON  BOOKSTORE_USER.MANAGE_PRODUCT_EDIT TO PUBLIC;
GRANT EXECUTE ON  BOOKSTORE_USER.MANAGE_PRODUCT_DELETE TO PUBLIC;
GRANT EXECUTE ON  BOOKSTORE_USER.MANAGE_ORDER_UPDATE_STATUS TO PUBLIC;
GRANT EXECUTE ON  BOOKSTORE_USER.ADMIN_VIEW_SYSTEM_LOGS  TO PUBLIC;
GRANT EXECUTE ON BOOKSTORE_USER.ADMIN_VIEW_LOGS  TO PUBLIC;
GRANT EXECUTE ON  BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS TO PUBLIC;
GRANT EXECUTE ON  BOOKSTORE_USER.GET_GENERAL_STATS TO PUBLIC;
GRANT EXECUTE ON BOOKSTORE_USER.SHOW_POPULAR_BOOKS TO PUBLIC;
-- Разрешаем запуск персоналу (обязательно)
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_GET_MY_HISTORY TO SellerUser;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_GET_MY_HISTORY TO AdminUser;
-- Если вы хотите, чтобы Клиент тоже мог запустить (и получить отказ внутри процедуры)
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_GET_MY_HISTORY TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_GET_ORDER_DETAILS TO PUBLIC;
-- Разрешаем запуск Продавцу и Админу
GRANT EXECUTE ON BOOKSTORE_USER.SELLER_CHECK_CLIENT TO SellerUser;
GRANT EXECUTE ON BOOKSTORE_USER.SELLER_CHECK_CLIENT TO AdminUser;

-- Если хотите проверить работу "отказа" под Клиентом, дайте право и ему:
GRANT EXECUTE ON BOOKSTORE_USER.SELLER_CHECK_CLIENT TO ClientUser;
-- 1. Разрешаем запуск всем (клиентам, продавцам, админам)
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_BUY_BOOK_AUTO TO PUBLIC;
-- 1. Сначала отзываем права у всех (на всякий случай)
REVOKE EXECUTE ON BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS FROM PUBLIC;
GRANT EXECUTE ON BOOKSTORE_USER.SAFE_ADMIN_ACCOUNT_CHECK TO PUBLIC;
CREATE OR REPLACE PUBLIC SYNONYM CHECK_ACCOUNTS FOR BOOKSTORE_USER.SAFE_ADMIN_ACCOUNT_CHECK;
-- Даем право запуска ВСЕМ (внутренняя проверка в процедуре сама их отсеет)
GRANT EXECUTE ON BOOKSTORE_USER.ADMIN_GET_ALL_USER_DATA TO PUBLIC;

-- Создаем короткое имя для всех
CREATE OR REPLACE PUBLIC SYNONYM GET_USERS_REPORT FOR BOOKSTORE_USER.ADMIN_GET_ALL_USER_DATA;
-- 2. Даем право только администратору
GRANT EXECUTE ON BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS TO AdminUser;

-- 3. Создаем синоним для удобства
CREATE OR REPLACE PUBLIC SYNONYM ADMIN_CHECK_ACCOUNTS FOR BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS;
-- 2. Создаем публичный синоним, чтобы не писать имя схемы
CREATE OR REPLACE PUBLIC SYNONYM CLIENT_BUY_BOOK_AUTO FOR BOOKSTORE_USER.CLIENT_BUY_BOOK_AUTO;
-- Создаем синоним для удобства
CREATE OR REPLACE PUBLIC SYNONYM SELLER_CHECK_CLIENT FOR BOOKSTORE_USER.SELLER_CHECK_CLIENT;
SELECT grantee, privilege, grantor 
FROM dba_tab_privs 
WHERE table_name = 'AUDIT_LOG' AND owner = 'BOOKSTORE_USER';
SELECT grantee FROM dba_role_privs WHERE granted_role = 'RLADMIN';
-- Отзываем права на прямое чтение таблицы и вьюхи у всех, кроме админа
REVOKE SELECT ON BOOKSTORE_USER.AUDIT_LOG FROM SellerUser;
REVOKE SELECT ON BOOKSTORE_USER.AUDIT_LOG FROM ClientUser;

-- Если у вас есть вьюхи (например, AuditLogInfo), отзовите права и на них
REVOKE SELECT ON BOOKSTORE_USER.AUDIT_LOG_INFO FROM SellerUser;
REVOKE SELECT ON BOOKSTORE_USER.AUDIT_LOG_INFO FROM ClientUser;

-- Даем права на чтение таблиц, которые нужны для проверки
GRANT SELECT ON BOOKSTORE_USER.USERS TO SellerUser;
GRANT SELECT ON BOOKSTORE_USER.USER_ROLES TO SellerUser;
GRANT SELECT ON BOOKSTORE_USER.ROLES TO SellerUser;
GRANT SELECT ON BOOKSTORE_USER.CUSTOMERS TO SellerUser;
GRANT SELECT, INSERT, UPDATE ON BOOKSTORE_USER.BOOKS TO SellerUser;

-- ВЫПОЛНЯТЬ ПОД ADMINUSER
CREATE OR REPLACE PROCEDURE BOOKSTORE_USER.MANAGE_USER_SECURITY_UPDATE() 
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_USER_SECURITY_UPDATE TO ClientUser;
-- (весь код процедуры, который мы обсуждали ранее)
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_USER_SECURITY_UPDATE TO PUBLIC;
GRANT EXECUTE ON  BOOKSTORE_USER.MANAGE_CUSTOMER_DATA_UPDATE  TO PUBLIC;
-- ===== Роль и пользователь администратора =====
CREATE ROLE RLAdmin;
GRANT EXECUTE ON AdminPackage TO RLAdmin;
CREATE USER AdminUser IDENTIFIED BY Qwerty12345;
GRANT RLAdmin TO AdminUser;
-- ===== Роль и пользователь продавца =====
CREATE ROLE RLSeller;
GRANT EXECUTE ON SellerPackage TO RLSeller;
CREATE USER SellerUser IDENTIFIED BY "Qwerty12345";
GRANT RLSeller TO SellerUser;
-- ===== Роль и пользователь покупателя =====
CREATE ROLE RLClient;
GRANT EXECUTE ON ClientPackage TO RLClient;
CREATE USER ClientUser IDENTIFIED BY "Qwerty12345";
GRANT RLClient TO ClientUser;
SET SERVEROUTPUT ON;
BEGIN
    -- 1. Удаляем пользователя, если он существует (ошибку ORA-01918 игнорируем)
    BEGIN 
        EXECUTE IMMEDIATE 'DROP USER SellerUser CASCADE'; 
        DBMS_OUTPUT.PUT_LINE('Старый SellerUser удален.');
    EXCEPTION 
        WHEN OTHERS THEN 
            IF SQLCODE != -1918 THEN -- Игнорируем ORA-01918 (пользователь не существует)
                RAISE;
            END IF;
    END;
    
    -- 2. Создаем пользователя SellerUser (БЕЗ кавычек для пароля)
    EXECUTE IMMEDIATE 'CREATE USER SellerUser IDENTIFIED BY Qwerty12345';
    DBMS_OUTPUT.PUT_LINE(' SellerUser создан.');
    
    -- 3. Даем право на вход (CONNECT)
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO SellerUser';
    DBMS_OUTPUT.PUT_LINE(' Право CREATE SESSION выдано.');
    
    -- 4. Выдаем роль продавца (RLSeller)
    -- Предполагается, что роль RLSeller уже создана в вашей схеме.
    EXECUTE IMMEDIATE 'GRANT RLSeller TO SellerUser';
    DBMS_OUTPUT.PUT_LINE(' Роль RLSeller выдана.');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('ИНФО: SellerUser готов к работе. Логин: SellerUser, Пароль: Qwerty12345');
END;
/
BEGIN
   -- Удаляем пользователя, если он "криво" создался (ошибку игнорируем, если его нет)
   BEGIN EXECUTE IMMEDIATE 'DROP USER AdminUser CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
   
   -- Создаем заново БЕЗ кавычек в пароле (чтобы не путаться с регистром)
   EXECUTE IMMEDIATE 'CREATE USER AdminUser IDENTIFIED BY Qwerty12345';
   
   -- Даем право на вход
   EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO AdminUser';
   
   -- Возвращаем ему его роль (если скрипт ролей уже запускали)
   EXECUTE IMMEDIATE 'GRANT RLAdmin TO AdminUser';
END;
/
BEGIN
    -- 1. Удаляем пользователя
    BEGIN
        EXECUTE IMMEDIATE 'DROP USER ClientUser CASCADE';
        DBMS_OUTPUT.PUT_LINE('Старый пользователь ClientUser удален.');
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- 2. Создаем заново (Пароль: Qwerty12345)
    EXECUTE IMMEDIATE 'CREATE USER ClientUser IDENTIFIED BY Qwerty12345';
    DBMS_OUTPUT.PUT_LINE('✅ Пользователь ClientUser создан.');

    -- 3. Выдаем право на вход
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO ClientUser';
    DBMS_OUTPUT.PUT_LINE('✅ Право на вход выдано.');

    -- 4. ВОЗВРАЩАЕМ РОЛЬ (ИСПРАВЛЕНО)
    BEGIN
        -- Добавлено слово GRANT
        EXECUTE IMMEDIATE 'GRANT RLClient TO ClientUser'; 
        DBMS_OUTPUT.PUT_LINE(' Роль RLClient успешно возвращена пользователю.');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('⚠️ Внимание: Роль не найдена. Проверьте, создавали ли вы RLClient в INIT_ROLES.');
            DBMS_OUTPUT.PUT_LINE('   Ошибка: ' || SQLERRM);
    END;

    -- 5. Права на процедуру LOGIN
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON BOOKSTORE_USER.LOGIN TO ClientUser';
    DBMS_OUTPUT.PUT_LINE(' Права на процедуру LOGIN выданы.');
END;
/
-- 1. Сначала даем права на подключение самим ролям (чтобы пользователи с этими ролями могли войти)
GRANT CREATE SESSION TO RLAdmin;
GRANT CREATE SESSION TO RLSeller;
GRANT CREATE SESSION TO RLClient;

---------------------------------------------------------------------------
-- 2. НАСТРОЙКА РОЛИ АДМИНИСТРАТОРА (RLAdmin)
-- Админ может всё: читать/писать во все таблицы и запускать любые процедуры
---------------------------------------------------------------------------
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_USER_SECURITY_UPDATE TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_CUSTOMER_DATA_UPDATE TO RLAdmin;
-- Гранты на Таблицы (Полный доступ)
GRANT SELECT, INSERT, UPDATE, DELETE ON BOOKSTORE_USER.ROLES TO RLAdmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON BOOKSTORE_USER.USERS TO RLAdmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON BOOKSTORE_USER.CUSTOMERS TO RLAdmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON BOOKSTORE_USER.BOOKS TO RLAdmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON BOOKSTORE_USER.ORDERS TO RLAdmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON BOOKSTORE_USER.ORDER_ITEMS TO RLAdmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON BOOKSTORE_USER.AUDIT_LOG TO RLAdmin;
-- Разрешаем создавать пользователей
GRANT CREATE USER TO RLAdmin;

-- Разрешаем BOOKSTORE_USER выдавать любые роли (нужно для GRANT RLSeller/RLAdmin)
GRANT GRANT ANY ROLE TO RLAdmin; 
-- Действие: BOOKSTORE_USER
GRANT SELECT ON BOOKSTORE_USER.AUDIT_LOG TO RLAdmin;
-- ДЕЙСТВИЕ: BOOKSTORE_USER
GRANT EXECUTE ON BOOKSTORE_USER.HASH_PASSWORD TO RLAdmin;
COMMIT;
-- Разрешаем  подключаться (CREATE SESSION)
GRANT CREATE SESSION TO RLAdmin;

-- Разрешаем создавать таблицы (если вдруг нужно)
GRANT CREATE TABLE TO RLAdmin;
-- Гранты на Процедуры (Выполнение)
-- Админские процедуры
GRANT SELECT, INSERT ON BOOKSTORE_USER.AUDIT_LOG TO AdminUser;
GRANT EXECUTE ON BOOKSTORE_USER.INIT_ROLES TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.ADMIN_CHECK_ACCOUNTS TO RLAdmin;
Commit;
GRANT EXECUTE ON BOOKSTORE_USER.ADMIN_VIEW_LOGS TO RLAdmin;
Commit;
GRANT EXECUTE ON BOOKSTORE_USER.LOG_ACTION TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_CUSTOMER_ADD TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_CUSTOMER_BLOCK TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_CUSTOMER_EDIT TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_PRODUCT_ADD TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_PRODUCT_EDIT TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_PRODUCT_DELETE TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.ADD_STAFF TO RLAdmin;
-- Операционные процедуры
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_CREATE TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_UPDATE_STATUS TO RLAdmin;
-- Аналитика
GRANT EXECUTE ON BOOKSTORE_USER.ANALYZE_GENERAL_STATS TO RLAdmin;
GRANT EXECUTE ON BOOKSTORE_USER.CHECK_REPLICATION_STATUS TO RLAdmin;


---------------------------------------------------------------------------
-- 3. НАСТРОЙКА РОЛИ ПРОДАВЦА (RLSeller)
-- Продавец работает с заказами, видит каталог и клиентов, но не может удалять юзеров
---------------------------------------------------------------------------
-- ДЕЙСТВИЕ: ДОБАВЛЕНИЕ КНИГИ
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_PRODUCT_ADD TO RLSeller;
GRANT EXECUTE ON BOOKSTORE_USER.SELLER_CHECK_CLIENT  TO RLSeller;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_SEARCH_BOOKS  TO RLSeller;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_BUY_BOOK_AUTO TO RLSeller;
COMMIT;
GRANT EXECUTE ON MANAGE_PRODUCT_EDIT TO RLSeller;
COMMIT;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_PRODUCT_DELETE TO RLSeller;
COMMIT;
-- Гранты на Таблицы
GRANT SELECT ON BOOKSTORE_USER.BOOKS TO RLSeller;        -- Видит каталог
GRANT SELECT ON BOOKSTORE_USER.CUSTOMERS TO RLSeller;    -- Видит клиентов
GRANT SELECT ON BOOKSTORE_USER.ROLES TO RLSeller;        -- Техническое чтение

-- Продавец может менять заказы
GRANT SELECT, INSERT, UPDATE ON BOOKSTORE_USER.ORDERS TO RLSeller;
GRANT SELECT, INSERT, UPDATE ON BOOKSTORE_USER.ORDER_ITEMS TO RLSeller;

-- Гранты на Процедуры
-- Продавец может менять статус заказа (Его главная работа)
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_UPDATE_STATUS TO RLSeller;
-- Продавец может оформить заказ за клиента (по телефону, например)
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_CREATE TO RLSeller;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM TO RLSeller;
-- Продавец может смотреть аналитику
GRANT EXECUTE ON BOOKSTORE_USER.ANALYZE_GENERAL_STATS TO RLSeller;

-- ВАЖНО: У RLSeller НЕТ прав на MANAGE_USER_*, MANAGE_PRODUCT_* (кроме чтения) и AUDIT_LOG


---------------------------------------------------------------------------
-- 4. НАСТРОЙКА РОЛИ КЛИЕНТА (RLClient)
-- Клиент видит каталог и может создавать заказы
---------------------------------------------------------------------------

-- Гранты на Таблицы
GRANT SELECT ON BOOKSTORE_USER.BOOKS TO RLClient; -- Только чтение каталога
-- Разрешаем всем (или специальному юзеру) пытаться войти
GRANT EXECUTE ON BOOKSTORE_USER.LOGIN TO RLClient; 

-- Гранты на Процедуры
-- Клиент может создавать заказы и добавлять товары
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_CREATE TO RLClient;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM TO RLClient;
-- Разрешаем Клиенту создавать заказы
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_CREATE TO ClientUser;
-- и удалять
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_REMOVE_ITEM TO ClientUser;
-- Разрешаем Клиенту читать таблицу покупателей (чтобы узнать свой ID)
GRANT SELECT ON BOOKSTORE_USER.CUSTOMERS TO ClientUser;
-- ВАЖНО: Клиент НЕ видит таблицу USERS, CUSTOMERS (чужих), AUDIT_LOG
-- Разрешаем Клиенту (ClientUser) добавлять товары
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM TO ClientUser;

-- Разрешаем Клиенту читать таблицу книг (чтобы он мог найти ID по названию)
GRANT SELECT ON BOOKSTORE_USER.BOOKS TO ClientUser;

-- Разрешаем читать свои заказы (и позиции)
GRANT SELECT ON BOOKSTORE_USER.ORDER_ITEMS TO ClientUser;
GRANT SELECT ON BOOKSTORE_USER.ORDERS TO ClientUser;
-- Разрешаем Клиенту читать таблицы, необходимые для определения личности
GRANT SELECT ON BOOKSTORE_USER.USERS TO ClientUser;
GRANT SELECT ON BOOKSTORE_USER.CUSTOMERS TO ClientUser;

-- Разрешаем Клиенту читать таблицу книг (для поиска)
GRANT SELECT ON BOOKSTORE_USER.BOOKS TO ClientUser;

-- Разрешаем Клиенту создавать заказы и добавлять товары
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_CREATE TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_CUSTOMER_ADD TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_GET_MY_HISTORY TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_SEARCH_BOOKS TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_SEARCH_BOOKS TO SellerUser;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_SEARCH_BOOKS TO AdminUser;
GRANT EXECUTE ON BOOKSTORE_USER.CLIENT_GET_ORDER_DETAILS TO ClientUser;

-- ПРОВЕРКА И ОБНОВЛЕНИЕ ГРАНТОВ ДЛЯ CLIENTUSER

-- 1. Права на чтение (КРИТИЧНО для ДИАГНОСТИКИ)
GRANT SELECT ON BOOKSTORE_USER.USERS TO ClientUser;
GRANT SELECT ON BOOKSTORE_USER.CUSTOMERS TO ClientUser;
GRANT SELECT ON BOOKSTORE_USER.ORDERS TO ClientUser;
GRANT SELECT ON BOOKSTORE_USER.BOOKS TO ClientUser;
GRANT SELECT ON BOOKSTORE_USER.MANAGE_CUSTOMER_ADD TO ClientUser;
-- 2. Права на выполнение (Для работы скриптов)
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_CREATE TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_ADD_ITEM TO ClientUser;
GRANT EXECUTE ON BOOKSTORE_USER.MANAGE_ORDER_REMOVE_ITEM TO ClientUser;


---------------------------------------------------------------------------
-- 5. НАЗНАЧЕНИЕ РОЛЕЙ ПОЛЬЗОВАТЕЛЯМ
-- Связываем роли с конкретными логинами
---------------------------------------------------------------------------

GRANT RLAdmin TO AdminUser;
GRANT RLSeller TO SellerUser;
GRANT RLClient TO ClientUser;

-- Делаем роли активными по умолчанию при входе
ALTER USER AdminUser DEFAULT ROLE RLAdmin;
ALTER USER SellerUser DEFAULT ROLE RLSeller;
ALTER USER ClientUser DEFAULT ROLE RLClient;

PROMPT Права доступа успешно настроены.


-- СТАТИСТИКА
GRANT EXECUTE ON BOOKSTORE_USER.GET_GENERAL_STATS TO RLSeller;
GRANT EXECUTE ON BOOKSTORE_USER.GET_GENERAL_STATS TO RLAdmin;

GRANT EXECUTE ON BOOKSTORE_USER.GET_POPULAR_PRODUCTS TO RLSeller;
GRANT EXECUTE ON BOOKSTORE_USER.GET_POPULAR_PRODUCTS TO RLAdmin;

COMMIT;