----------------------------------задаем директорию
CREATE OR REPLACE DIRECTORY JSON_DIR AS 'C:\oracle_json';
GRANT READ, WRITE ON DIRECTORY JSON_DIR TO bookstore_user;
--------------------------------получить директорию
SELECT directory_name, directory_path 
FROM all_directories
WHERE directory_name = 'JSON_DIR';

--------------------------------------экспорт
CREATE OR REPLACE PACKAGE json_export_pkg AS
  PROCEDURE export_books_to_json;
END;
/
CREATE OR REPLACE PACKAGE json_export_pkg AS
  PROCEDURE export_books_to_json;
END;
/

CREATE OR REPLACE PACKAGE BODY json_export_pkg AS

  PROCEDURE export_books_to_json IS
    l_file      UTL_FILE.FILE_TYPE;
    l_json_row  CLOB;
    l_is_first  BOOLEAN := TRUE;
    
    -- Курсор для построчного чтения (включая новые поля)
    CURSOR c_books IS
      SELECT book_id, isbn, title, author, price, stock, category, 
             attributes_json, created_at, 
             discount_percent, price_after_discount
      FROM books;
      
  BEGIN
    -- 1. Открываем файл на запись
    l_file := UTL_FILE.FOPEN('JSON_DIR', 'books_export.json', 'w', 32767);
    
    -- 2. Начинаем JSON массив
    UTL_FILE.PUT_LINE(l_file, '[');
    
    -- 3. Запускаем цикл по строкам
    FOR r IN c_books LOOP
      
      -- Если это не первая строка, ставим запятую перед новой записью
      IF NOT l_is_first THEN
        UTL_FILE.PUT_LINE(l_file, ',');
      ELSE
        l_is_first := FALSE;
      END IF;

      -- 4. Генерируем JSON объект ТОЛЬКО ДЛЯ ОДНОЙ СТРОКИ
      SELECT JSON_OBJECT(
               'book_id'              VALUE r.book_id,
               'isbn'                 VALUE r.isbn,
               'title'                VALUE r.title,
               'author'               VALUE r.author,
               'price'                VALUE r.price,
               'stock'                VALUE r.stock,
               'category'             VALUE r.category,
               'created_at'           VALUE TO_CHAR(r.created_at, 'YYYY-MM-DD HH24:MI:SS'),
               'discount_percent'     VALUE r.discount_percent,       -- Добавлено новое поле
               'price_after_discount' VALUE r.price_after_discount,   -- Добавлено новое поле
               'attributes_json'      VALUE r.attributes_json FORMAT JSON
             )
      INTO l_json_row
      FROM DUAL;

      -- 5. Записываем строку в файл
      -- Если строка очень длинная (CLOB), UTL_FILE.PUT_LINE может упасть, 
      -- поэтому лучше писать частями, но для JSON объекта одной книги обычно хватает:
      UTL_FILE.PUT_LINE(l_file, l_json_row);
      
      -- Сбрасываем буфер записи периодически (опционально, но полезно для больших файлов)
      -- UTL_FILE.FFLUSH(l_file); 
      
    END LOOP;

    -- 6. Закрываем JSON массив
    UTL_FILE.PUT_LINE(l_file, ']');
    
    -- 7. Закрываем файл
    UTL_FILE.FCLOSE(l_file);
    
  EXCEPTION
    WHEN OTHERS THEN
      IF UTL_FILE.IS_OPEN(l_file) THEN
        UTL_FILE.FCLOSE(l_file);
      END IF;
      -- Выводим ошибку в консоль, чтобы вы знали, что случилось
      DBMS_OUTPUT.PUT_LINE('Ошибка экспорта: ' || SQLERRM);
      RAISE;
  END export_books_to_json;

END json_export_pkg;
/


---------------------------------------
BEGIN
  json_export_pkg.export_books_to_json;
END;
/







-----------------------------------------импорт---------------------------------
CREATE OR REPLACE PACKAGE json_import_pkg AS
  PROCEDURE import_books_from_json;
END json_import_pkg;
/
CREATE OR REPLACE PACKAGE BODY json_import_pkg AS

  PROCEDURE import_books_from_json IS
    l_file CLOB;
    f      UTL_FILE.FILE_TYPE;
    l_buf  VARCHAR2(32767);
  BEGIN
    l_file := EMPTY_CLOB();

    -- Открываем JSON-файл
    f := UTL_FILE.FOPEN('JSON_DIR', 'books_export.json', 'r', 32767);

    -- Читаем файл
    LOOP
      BEGIN
        UTL_FILE.GET_LINE(f, l_buf);
        l_file := l_file || l_buf;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          EXIT;
      END;
    END LOOP;
    UTL_FILE.FCLOSE(f);

    
    INSERT INTO books (
        book_id, isbn, title, author, price, stock, category, 
        attributes_json, created_at, discount_percent, price_after_discount
    )
    SELECT 
        book_id, isbn, title, author, price, stock, category, 
        attributes_json, 
        TO_TIMESTAMP(created_at, 'YYYY-MM-DD HH24:MI:SS'),
        discount_percent, 
        price_after_discount
    FROM JSON_TABLE(
           l_file,
           '$[*]' COLUMNS (
             book_id              NUMBER        PATH '$.book_id',
             isbn                 VARCHAR2(20)  PATH '$.isbn',
             title                VARCHAR2(400) PATH '$.title',
             author               VARCHAR2(200) PATH '$.author',
             price                NUMBER(10,2)  PATH '$.price',
             stock                NUMBER        PATH '$.stock',
             category             VARCHAR2(100) PATH '$.category',
             attributes_json      CLOB          PATH '$.attributes_json',
             created_at           VARCHAR2(30)  PATH '$.created_at',
             discount_percent     NUMBER(5,2)   PATH '$.discount_percent',       -- Новое поле
             price_after_discount NUMBER(10,2)  PATH '$.price_after_discount'    -- Новое поле
           )
         );

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      IF UTL_FILE.IS_OPEN(f) THEN
        UTL_FILE.FCLOSE(f);
      END IF;
      DBMS_OUTPUT.PUT_LINE('Ошибка импорта: ' || SQLERRM);
      RAISE;
  END import_books_from_json;

END json_import_pkg;
/


--------------------------------тестирование------------------------------------
DELETE FROM books;
COMMIT;
SELECT COUNT(*) FROM books;
BEGIN
  json_import_pkg.import_books_from_json;
END;
/
SELECT COUNT(*) FROM books;
SELECT * FROM books FETCH FIRST 10 ROWS ONLY;





































CREATE OR REPLACE PROCEDURE ImportBooksFromJSON AS
    v_file    UTL_FILE.FILE_TYPE;
    v_line    VARCHAR2(32767);
    v_json    CLOB := EMPTY_CLOB();
BEGIN
    -- Открываем файл для чтения
    v_file := UTL_FILE.FOPEN('JSON_DIR', 'test_books.json', 'R');

    LOOP
        BEGIN
            UTL_FILE.GET_LINE(v_file, v_line);
            v_json := v_json || v_line;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
        END;
    END LOOP;

    UTL_FILE.FCLOSE(v_file);

    -- Вставляем данные в таблицу BOOKS
    INSERT INTO books (isbn, title, author, price, stock, category, attributes_json)
    SELECT
        jt.isbn,
        jt.title,
        jt.author,
        jt.price,
        jt.stock,
        jt.category,
        jt.json_data
    FROM JSON_TABLE(
        v_json,
        '$[*]'
        COLUMNS (
            isbn      VARCHAR2(50)  PATH '$.isbn',
            title     VARCHAR2(400) PATH '$.title',
            author    VARCHAR2(200) PATH '$.author',
            price     NUMBER        PATH '$.price',
            stock     NUMBER        PATH '$.stock',
            category  VARCHAR2(100) PATH '$.category',
            json_data CLOB          PATH '$'
        )
    ) jt;

    COMMIT;
END;
/


BEGIN
    ImportBooksFromJSON;
END;
/
-----------------------------------
SELECT directory_name, directory_path FROM dba_directories WHERE directory_name = 'JSON_DIR';
DESC BOOKS;
SELECT owner, table_name 
FROM all_tables 
WHERE table_name = 'BOOKS';
GRANT READ, WRITE ON DIRECTORY JSON_DIR TO BOOKSTORE_USER;
SELECT directory_name, directory_path
FROM all_directories
WHERE directory_name = 'JSON_DIR';

