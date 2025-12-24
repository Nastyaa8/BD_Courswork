DELETE FROM books;
COMMIT;

BEGIN
  FOR i IN 1..100000 LOOP
    INSERT INTO books (isbn, title, author, price, stock, category, attributes_json)
    VALUES (
      '978-3-' || LPAD(i,6,'0'),
      'Book Title ' || i,
      'Author ' || MOD(i,100),
      ROUND(DBMS_RANDOM.VALUE(100,1000),2),
      ROUND(DBMS_RANDOM.VALUE(0,50)),
      'Category ' || MOD(i,10),
      '{"pages": ' || ROUND(DBMS_RANDOM.VALUE(100,1000)) || ', "format":"paperback"}'
    );
  END LOOP;
  COMMIT;
END;
/








DECLARE
    -- Определяем тип массива
    TYPE t_arr IS TABLE OF VARCHAR2(100);
    
    -- Словари данных
    v_adj    t_arr := t_arr('Тайный', 'Забытый', 'Вечный', 'Красный', 'Цифровой', 'Великий', 'Железный', 'Золотой', 'Мертвый', 'Тихий', 'Безумный', 'Ночной', 'Солнечный');
    v_noun   t_arr := t_arr('Код', 'Император', 'Лес', 'Океан', 'Сад', 'Меч', 'Дракон', 'Программист', 'Город', 'Замок', 'Человек', 'Воин', 'Ангел');
    v_suffix t_arr := t_arr('Судьбы', 'Времени', 'Хаоса', 'Теней', 'Будущего', 'Власти', 'Смерти', 'Жизни', 'Света', 'Тьмы', 'Данных', 'Java');
    
    v_fname  t_arr := t_arr('Джон', 'Мария', 'Александр', 'Елена', 'Роберт', 'Дэвид', 'Анна', 'Майкл', 'Светлана', 'Дмитрий');
    v_lname  t_arr := t_arr('Смит', 'Джонсон', 'Петров', 'Иванов', 'Кинг', 'Роулинг', 'Мартин', 'Браун', 'Уильямс', 'Сидоров');
    v_cats   t_arr := t_arr('Фантастика', 'Классика', 'Обучение', 'Психология', 'Бизнес', 'История');

    -- Простые переменные для вставки (чтобы SQL не ругался)
    v_isbn        VARCHAR2(20);
    v_title       VARCHAR2(200);
    v_author      VARCHAR2(100);
    v_category    VARCHAR2(50);
    v_price       NUMBER;
    v_stock       NUMBER;
    v_pages       NUMBER;
    v_discount    NUMBER;
    v_final_price NUMBER;
    v_img_url     VARCHAR2(500);
    
    -- Переменная для амперсанда (чтобы не было окна ввода)
    v_amp         VARCHAR2(1) := CHR(38); 

BEGIN
    DBMS_OUTPUT.PUT_LINE('🧹 Очистка таблиц...');
    DELETE FROM BOOKSTORE_USER.ORDER_ITEMS; 
    DELETE FROM BOOKSTORE_USER.BOOKS;       
    
    DBMS_OUTPUT.PUT_LINE('⏳ Генерация 100,000 книг... (Подождите около 20-30 сек)');

    FOR i IN 1..100000 LOOP
        
        -- 1. Сначала вычисляем все значения в PL/SQL (до INSERT)
        v_title := v_adj(ROUND(DBMS_RANDOM.VALUE(1, v_adj.COUNT))) || ' ' || 
                   v_noun(ROUND(DBMS_RANDOM.VALUE(1, v_noun.COUNT))) || ' ' || 
                   v_suffix(ROUND(DBMS_RANDOM.VALUE(1, v_suffix.COUNT)));

        v_author := v_fname(ROUND(DBMS_RANDOM.VALUE(1, v_fname.COUNT))) || ' ' || 
                    v_lname(ROUND(DBMS_RANDOM.VALUE(1, v_lname.COUNT)));
        
        v_category := v_cats(ROUND(DBMS_RANDOM.VALUE(1, v_cats.COUNT)));

        v_isbn := '978-0-' || LPAD(TRUNC(DBMS_RANDOM.VALUE(10,99)),2) || '-' || LPAD(i, 6, '0');
        
        v_price := ROUND(DBMS_RANDOM.VALUE(300, 3000));
        v_stock := ROUND(DBMS_RANDOM.VALUE(0, 100));
        v_pages := ROUND(DBMS_RANDOM.VALUE(100, 900));
        
        v_discount := ROUND(DBMS_RANDOM.VALUE(0, 30));
        v_final_price := v_price * (1 - v_discount / 100);

        -- Формируем ссылку БЕЗ использования символа & в явном виде
        -- Используем переменную v_amp
        v_img_url := 'https://dummyimage.com/400x600/000/fff' || v_amp || 'text=' || REPLACE(v_title, ' ', '+');

        -- 2. Теперь делаем чистый SQL INSERT только с переменными
        INSERT INTO BOOKSTORE_USER.BOOKS (
            isbn, title, author, price, stock, category, attributes_json, 
            image_url, discount_percent, price_after_discount
        ) VALUES (
            v_isbn,
            v_title,
            v_author,
            v_price,
            v_stock,
            v_category,
            '{"pages": ' || v_pages || '}',
            v_img_url,
            v_discount,
            v_final_price
        );

        -- Коммит каждые 5000 строк для скорости
        IF MOD(i, 5000) = 0 THEN 
            COMMIT; 
        END IF;
        
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✅ УСПЕХ: 100,000 книг сгенерированы!');
END;
/







--очистить таблицу 
ALTER TABLE order_items DISABLE CONSTRAINT SYS_C008284;

TRUNCATE TABLE books;

ALTER TABLE order_items ENABLE CONSTRAINT SYS_C008284;
-- Пример генерации тестовых данных
BEGIN
  FOR i IN 1..100000 LOOP
    INSERT INTO books (isbn, title, author, price, stock, category, attributes_json)
    VALUES (
      '978-3-' || LPAD(i,5,'0'),
      'Book Title ' || i,
      'Author ' || MOD(i,100),
      ROUND(DBMS_RANDOM.VALUE(100,1000),2),
      ROUND(DBMS_RANDOM.VALUE(0,50)),
      'Category ' || MOD(i,10),
      '{"pages": ' || ROUND(DBMS_RANDOM.VALUE(100,1000)) || ', "format":"paperback"}'
    );
  END LOOP;
  COMMIT;
END;
/
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS('BOOKSTORE_USER', 'BOOKS');
END;
/

select count(*) from books
--план запроса без индекса 
SELECT *
FROM books
WHERE author = 'Author 10';
SET STATISTICS TIME ON;
SELECT title
FROM books
WHERE author = 'Author 10';

SET STATISTICS TIME OFF

select * from table(dbms_xplan.display_cursor(sql_id=>'a7kd36r1r0yym', format=>'ALLSTATS LAST'));
;

EXPLAIN PLAN FOR
SELECT *
FROM books
WHERE author = 'Author 10';
/

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

EXPLAIN PLAN FOR
SELECT * FROM books WHERE author = 'Author 10';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


CREATE INDEX idx_author ON books(author);









---------------------------------------------------
ALTER SYSTEM FLUSH BUFFER_CACHE;
ALTER SYSTEM FLUSH SHARED_POOL;
DROP INDEX idx_books_author;
DROP INDEX
-- Без индекса
DROP INDEX idx_books_category; -- если создавался
SET TIMING ON;
SELECT title FROM books WHERE category = 'Бестселлер';
SET TIMING OFF;
-- С индексом
CREATE INDEX idx_books_category ON books(category);
SET TIMING ON;
SELECT title FROM books WHERE category = 'Бестселлер';


UPDATE books 
SET category = 'Учебная литература' 
WHERE category = 'Category 3';

SELECT COUNT(*) 
FROM books 
WHERE category = 'Учебная литература';
SET TIMING ON;
SET TIMING OFF;
SELECT title 
FROM books 
WHERE category = 'Учебная литература';

EXPLAIN PLAN FOR
SELECT title FROM books WHERE category = 'Category3';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
SET TIMING ON;
SELECT title 
FROM books
WHERE category = 'Category3';
CREATE INDEX idx_books_category ON books(category);
SET TIMING ON;

SELECT title 
FROM books
WHERE category = 'Category3';
EXPLAIN PLAN FOR
SELECT title 
FROM books
WHERE category = 'Category3';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

SELECT index_name, column_name
FROM user_ind_columns
WHERE table_name = 'BOOKS';
SELECT DISTINCT category FROM books ORDER BY 1;

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => 'BOOKSTORE_USER',
        tabname => 'BOOKS',
        cascade => TRUE
    );
END;
/

CREATE INDEX idx_books_category ON books(category);

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(ownname => USER, tabname => 'BOOKS', cascade => TRUE);
END;
/

SELECT title 
FROM books
WHERE category = 'Учебная литература';

EXPLAIN PLAN FOR
SELECT title 
FROM books
WHERE category = 'Учебная литература';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

EXPLAIN PLAN FOR
SELECT /*+ INDEX(books idx_books_category) */ title
FROM books
WHERE category = 'Учебная литература';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

DROP INDEX idx_books_category;
SET TIMING OFF;
SELECT title 
FROM books
WHERE category = 'Учебная литература';

EXPLAIN PLAN FOR
SELECT title 
FROM books
WHERE category = 'Учебная литература';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

