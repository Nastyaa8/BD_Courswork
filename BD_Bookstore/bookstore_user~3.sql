
Explained.


PL/SQL procedure successfully completed.


Explained.


Error starting at line : 102 in command -
ALTER SYSTEM FLUSH BUFFER_CACHE
Error report -
ORA-01031: привилегий недостаточно

https://docs.oracle.com/error-help/db/ora-01031/01031. 00000 -  "insufficient privileges"
*Document: YES
*Cause:    A database operation was attempted without the required
           privilege(s).
*Action:   Ask your database administrator or security administrator to grant
           you the required privilege(s).

Error starting at line : 103 in command -
ALTER SYSTEM FLUSH SHARED_POOL
Error report -
ORA-01031: привилегий недостаточно

https://docs.oracle.com/error-help/db/ora-01031/01031. 00000 -  "insufficient privileges"
*Document: YES
*Cause:    A database operation was attempted without the required
           privilege(s).
*Action:   Ask your database administrator or security administrator to grant
           you the required privilege(s).

System altered.


System altered.


Index IDX_BOOKS_CATEGORY created.

Elapsed: 00:00:00.295
SP2-0158: unknown SET option beginning "statistics..."
SP2-0158: unknown SET option beginning "statistics..."

Index IDX_BOOKS_AUTHOR dropped.

Elapsed: 00:00:00.264
>>Query Run In:Query Result
Elapsed: 00:00:00.563

Error starting at line : 111 in command -
CREATE INDEX idx_books_category ON books(category)
Error report -
ORA-00955: имя уже задействовано для существующего объекта

https://docs.oracle.com/error-help/db/ora-00955/00955. 00000 -  "name is already used by an existing object"
*Cause:    An attempt was made to create a database object (such
           as a table, view, cluster, index, or synonym) that already
           existed. A user's database objects must have distinct names.
*Action:   Enter a unique name for the database object or modify
           or drop the existing object so it can be reused.
Elapsed: 00:00:00.027

Error starting at line : 104 in command -
DROP INDEX idx_books_author
Error report -
ORA-01418: заданного индекса не существует

https://docs.oracle.com/error-help/db/ora-01418/01418. 00000 -  "specified index does not exist"
*Cause:    An ALTER INDEX, DROP INDEX, or VALIDATE INDEX statement
           specified the name of an index that did not exist. Only
           existing indexes can be altered, dropped, or validated.
           Existing indexes may be listed by querying the data
           dictionary.
*Action:   Specify the name of an existing index in the ALTER
           INDEX, DROP INDEX, or VALIDATE INDEX statement.
Elapsed: 00:00:00.025

Index IDX_BOOKS_CATEGORY dropped.

Elapsed: 00:00:00.015
>>Query Run In:Query Result 1
Elapsed: 00:00:00.381

Index IDX_BOOKS_CATEGORY created.

Elapsed: 00:00:00.131

Error starting at line : 112 in command -
CREATE INDEX idx_books_category ON books(category)
Error report -
ORA-00955: имя уже задействовано для существующего объекта

https://docs.oracle.com/error-help/db/ora-00955/00955. 00000 -  "name is already used by an existing object"
*Cause:    An attempt was made to create a database object (such
           as a table, view, cluster, index, or synonym) that already
           existed. A user's database objects must have distinct names.
*Action:   Enter a unique name for the database object or modify
           or drop the existing object so it can be reused.
Elapsed: 00:00:00.028

Index IDX_BOOKS_CATEGORY dropped.

Elapsed: 00:00:00.018

10 000 rows updated.

