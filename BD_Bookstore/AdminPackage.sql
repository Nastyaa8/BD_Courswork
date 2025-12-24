CREATE OR REPLACE PACKAGE AdminPackage AS
  -- Управление пользователями
  PROCEDURE AddUser(p_username IN NVARCHAR2, p_password_hash IN NVARCHAR2, p_role_name IN NVARCHAR2);
  PROCEDURE DeleteUser(p_user_id IN NUMBER);

  -- Просмотр статистики
  PROCEDURE ViewStatistics;

  -- Управление ролями
  PROCEDURE AddRole(p_role_name IN NVARCHAR2);
  PROCEDURE DeleteRole(p_role_id IN NUMBER);

  -- Репликация (имитация для курсового проекта)
  PROCEDURE ReplicateToMSSQL;
END AdminPackage;
/
CREATE OR REPLACE PACKAGE BODY AdminPackage AS

  -- Добавление пользователя
 PROCEDURE AddUser(p_username IN NVARCHAR2, p_password_hash IN NVARCHAR2, p_role_name IN NVARCHAR2) IS
  v_role_id NUMBER;
  v_count   NUMBER;
BEGIN
  -- Получаем id роли
  SELECT role_id INTO v_role_id FROM roles WHERE role_name = p_role_name;

  -- Проверяем, есть ли уже пользователь с таким username
  SELECT COUNT(*) INTO v_count FROM users WHERE username = p_username;

  IF v_count = 0 THEN
    INSERT INTO users (username, password_hash, role_id)
    VALUES (p_username, p_password_hash, v_role_id);
    DBMS_OUTPUT.PUT_LINE('Пользователь "' || p_username || '" добавлен с ролью "' || p_role_name || '".');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Пользователь "' || p_username || '" уже существует, добавление пропущено.');
  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Роль "' || p_role_name || '" не найдена.');
END AddUser;


  -- Удаление пользователя
  PROCEDURE DeleteUser(p_user_id IN NUMBER) IS
  BEGIN
    DELETE FROM users
    WHERE user_id = p_user_id;
    DBMS_OUTPUT.PUT_LINE('Пользователь с ID=' || p_user_id || ' удалён.');
  END DeleteUser;

  -- Просмотр статистики
  PROCEDURE ViewStatistics IS
    v_books NUMBER;
    v_users NUMBER;
    v_orders NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_books FROM books;
    SELECT COUNT(*) INTO v_users FROM users;
    SELECT COUNT(*) INTO v_orders FROM orders;

    DBMS_OUTPUT.PUT_LINE('Статистика магазина:');
    DBMS_OUTPUT.PUT_LINE('Книги: ' || v_books);
    DBMS_OUTPUT.PUT_LINE('Пользователи: ' || v_users);
    DBMS_OUTPUT.PUT_LINE('Заказы: ' || v_orders);
  END ViewStatistics;

  -- Добавление роли
 PROCEDURE AddRole(p_role_name IN NVARCHAR2) IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM roles WHERE role_name = p_role_name;

  IF v_count = 0 THEN
    INSERT INTO roles (role_name) VALUES (p_role_name);
    DBMS_OUTPUT.PUT_LINE('Роль "' || p_role_name || '" добавлена.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Роль "' || p_role_name || '" уже существует, добавление пропущено.');
  END IF;
END AddRole;


  -- Удаление роли
  PROCEDURE DeleteRole(p_role_id IN NUMBER) IS
  BEGIN
    DELETE FROM roles
    WHERE role_id = p_role_id;
    DBMS_OUTPUT.PUT_LINE('Роль с ID=' || p_role_id || ' удалена.');
  END DeleteRole;

  -- Репликация (имитация)
  PROCEDURE ReplicateToMSSQL IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Изменения будут реплицироваться на MS SQL Server через Oracle GoldenGate или SSIS.');
    DBMS_OUTPUT.PUT_LINE('PL/SQL не управляет репликацией напрямую, это делает DBA.');
  END ReplicateToMSSQL;

END AdminPackage;
/


--тестирование
BEGIN
  -- Работа с ролями
  AdminPackage.AddRole('Seller');
  AdminPackage.AddRole('Admin');
end;
begin
  -- Добавление пользователей
  AdminPackage.AddUser('ivan', 'pass123', 'Customer');
  AdminPackage.AddUser('anna', 'pass456', 'Seller');
end;
begin
  -- Просмотр статистики
  AdminPackage.ViewStatistics;
end;
begin
  -- Репликация (демонстрация)
  AdminPackage.ReplicateToMSSQL;
end;
begin
  -- Удаление пользователя и роли
  AdminPackage.DeleteUser(1);
  AdminPackage.DeleteRole(3); -- укажи реальный role_id
END;
/
