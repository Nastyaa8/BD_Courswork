INSERT INTO BOOKS (ISBN, TITLE, PRICE, STOCK, CATEGORY) 
VALUES ('TEST-001', 'Секретная Книга для Курсовой', 9999.99, 10, 'Test');

COMMIT; -- Обязательно! Без этого SQL Server не увидит изменения.

INSERT INTO BOOKS (ISBN, TITLE, PRICE, STOCK, CATEGORY) 
VALUES ('NEW-2025', 'Стивен Кинг', 1200, 10, 'Test');

COMMIT; -- Обязательно нажми эту кнопку или выполни команду!


INSERT INTO BOOKS (ISBN, TITLE, PRICE, STOCK, CATEGORY) 
VALUES ('213', 'Лев Толстой', 1200, 10, 'Test');

COMMIT; -- Обязательно нажми эту кнопку или выполни команду!