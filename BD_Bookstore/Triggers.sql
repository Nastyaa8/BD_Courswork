CREATE OR REPLACE TRIGGER trg_prevent_admin_user
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    IF :NEW.username = 'admin' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Невозможно создать пользователя с username = admin');
    END IF;
END;
/
