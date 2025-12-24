SHOW USER;
SELECT ROLE FROM DBA_ROLES WHERE ROLE = 'RLADMIN';
-- ===== Роль и пользователь администратора =====
CREATE ROLE RLAdmin;
GRANT EXECUTE ON AdminPackage TO RLAdmin;

CREATE USER AdminUser IDENTIFIED BY "Qwerty12345";
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
