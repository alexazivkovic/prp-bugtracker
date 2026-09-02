USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== NZ 1: naziv baze i cirilicka kolacija ==';
SELECT name AS Baza, collation_name AS Kolacija,
       CASE WHEN name = N'BugTracker' AND collation_name = N'Serbian_Cyrillic_100_CI_AS'
            THEN N'OK' ELSE N'NE VALJA' END AS Provera
FROM sys.databases WHERE name = N'BugTracker';

PRINT N'== NZ 2: hijerarhija sredstava - koliko cega ==';
PRINT N'   (deklarativnih ogranicenja mora biti mnogo vise nego trigera)';
SELECT N'CHECK ogranicenja'  AS Sredstvo, COUNT(*) AS Broj FROM sys.check_constraints
UNION ALL SELECT N'UNIQUE + PK', COUNT(*) FROM sys.key_constraints
UNION ALL SELECT N'strani kljucevi', COUNT(*) FROM sys.foreign_keys
UNION ALL SELECT N'DML trigeri', COUNT(*) FROM sys.triggers WHERE parent_class = 1
UNION ALL SELECT N'upravljacke procedure', COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = N'spec';

PRINT N'== NZ 3: nullable kolone (za njih je u DDL-u eksplicitno napisano NULL) ==';
SELECT OBJECT_NAME(c.object_id) AS Tabela, c.name AS Kolona, t.name AS Tip
FROM sys.columns c JOIN sys.tables tb ON tb.object_id = c.object_id
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE SCHEMA_NAME(tb.schema_id) = N'impl' AND c.is_nullable = 1
ORDER BY Tabela, Kolona;

PRINT N'== NZ 4: prikazi idu kroz poglede - koliko ih ima po sloju ==';
SELECT SCHEMA_NAME(schema_id) AS Sema, COUNT(*) AS BrojPogleda
FROM sys.views WHERE SCHEMA_NAME(schema_id) IN (N'impl',N'spec',N'api_dev',N'api_qa')
GROUP BY SCHEMA_NAME(schema_id) ORDER BY Sema;

PRINT N'== NZ 5: smer zavisnosti mora biti api_ -> spec -> impl ==';
PRINT N'   (a) nijedan api_ objekat ne sme direktno zavisiti od impl';
SELECT OBJECT_SCHEMA_NAME(d.referencing_id) AS IzSeme, OBJECT_NAME(d.referencing_id) AS Objekat,
       d.referenced_schema_name AS ZavisiOdSeme, d.referenced_entity_name AS ZavisiOd
FROM sys.sql_expression_dependencies d
WHERE OBJECT_SCHEMA_NAME(d.referencing_id) LIKE 'api!_%' ESCAPE '!'
  AND d.referenced_schema_name = N'impl';
PRINT N'   (b) nijedan spec objekat ne sme zavisiti od api_ (unazad)';
SELECT OBJECT_SCHEMA_NAME(d.referencing_id) AS IzSeme, OBJECT_NAME(d.referencing_id) AS Objekat,
       d.referenced_schema_name AS ZavisiOdSeme, d.referenced_entity_name AS ZavisiOd
FROM sys.sql_expression_dependencies d
WHERE OBJECT_SCHEMA_NAME(d.referencing_id) = N'spec'
  AND d.referenced_schema_name LIKE 'api!_%' ESCAPE '!';
PRINT N'   (oba upita moraju vratiti 0 redova)';

PRINT N'== NZ 5: spec je enkapsuliran - svaki objekat WITH ENCRYPTION ==';
SELECT COUNT(*) AS UkupnoSpecObjekata,
       SUM(CASE WHEN OBJECT_DEFINITION(object_id) IS NULL THEN 1 ELSE 0 END) AS Sifrovanih
FROM sys.objects WHERE SCHEMA_NAME(schema_id) = N'spec' AND type IN ('P','FN','IF','V');

PRINT N'== NZ 6 i 7: dve API seme, dve aplikacione uloge, prava ==';
SELECT dp.name AS Uloga, pe.state_desc AS Stanje, pe.permission_name AS Pravo,
       SCHEMA_NAME(pe.major_id) AS NadSemom
FROM sys.database_permissions pe
JOIN sys.database_principals dp ON dp.principal_id = pe.grantee_principal_id
WHERE pe.class_desc = N'SCHEMA' AND dp.type_desc = N'APPLICATION_ROLE'
ORDER BY dp.name, pe.state_desc DESC, NadSemom, pe.permission_name;

PRINT N'== NZ 8: imenovanje u impl (tbl / vw / trg / idx) ==';
SELECT N'tabela' AS Vrsta, name AS Objekat,
       CASE WHEN name COLLATE Latin1_General_BIN2 LIKE 'tbl%' THEN N'OK' ELSE N'NE VALJA' END AS Provera
FROM sys.tables WHERE SCHEMA_NAME(schema_id) = N'impl'
UNION ALL
SELECT N'pogled', name, CASE WHEN name COLLATE Latin1_General_BIN2 LIKE 'vw%' THEN N'OK' ELSE N'NE VALJA' END
FROM sys.views WHERE SCHEMA_NAME(schema_id) = N'impl'
UNION ALL
SELECT N'triger', name, CASE WHEN name COLLATE Latin1_General_BIN2 LIKE 'trg%' THEN N'OK' ELSE N'NE VALJA' END
FROM sys.triggers WHERE parent_class = 1 AND OBJECT_SCHEMA_NAME(parent_id) = N'impl'
UNION ALL
SELECT N'indeks', i.name, CASE WHEN i.name COLLATE Latin1_General_BIN2 LIKE 'idx%' THEN N'OK' ELSE N'NE VALJA' END
FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
WHERE SCHEMA_NAME(t.schema_id) = N'impl' AND i.type = 2 AND i.is_unique_constraint = 0
ORDER BY Vrsta, Objekat;

PRINT N'== NZ 8: imenovanje u spec (upr_ / fns_ / fnt_ / vw_) ==';
SELECT o.type_desc AS Vrsta, o.name AS Objekat,
       CASE
         WHEN o.type = 'P'  AND o.name COLLATE Latin1_General_BIN2 LIKE 'upr[_]%' THEN N'OK'
         WHEN o.type = 'FN' AND o.name COLLATE Latin1_General_BIN2 LIKE 'fns[_]%' THEN N'OK'
         WHEN o.type = 'IF' AND o.name COLLATE Latin1_General_BIN2 LIKE 'fnt[_]%' THEN N'OK'
         WHEN o.type = 'V'  AND o.name COLLATE Latin1_General_BIN2 LIKE 'vw[_]%'  THEN N'OK'
         ELSE N'NE VALJA' END AS Provera
FROM sys.objects o WHERE SCHEMA_NAME(o.schema_id) = N'spec' AND o.type IN ('P','FN','IF','V')
ORDER BY o.type_desc, o.name;

PRINT N'== NZ 8: imenovanje u api_ (pogledi UPPER_CASE, procedure PascalCase) ==';
SELECT SCHEMA_NAME(o.schema_id) AS Sema, o.type_desc AS Vrsta, o.name AS Objekat,
       CASE
         WHEN o.type IN ('V','IF','SN')
              AND o.name COLLATE Latin1_General_BIN2 = UPPER(o.name) COLLATE Latin1_General_BIN2 THEN N'OK'
         WHEN o.type = 'P' AND o.name = N'upr_MatricaGresaka' THEN N'svesno odstupanje (zahtev 12)'
         WHEN o.type = 'P'
              AND o.name COLLATE Latin1_General_BIN2 LIKE '[A-Z]%'
              AND o.name COLLATE Latin1_General_BIN2 <> UPPER(o.name) COLLATE Latin1_General_BIN2 THEN N'OK'
         ELSE N'NE VALJA' END AS Provera
FROM sys.objects o WHERE SCHEMA_NAME(o.schema_id) IN (N'api_dev',N'api_qa')
  AND o.type IN ('V','P','IF','SN')
ORDER BY Sema, Vrsta, Objekat;

PRINT N'== NZ 8: parametri u api_ semama moraju biti camelCase ==';
SELECT SCHEMA_NAME(o.schema_id) AS Sema, o.name AS Objekat, p.name AS Parametar,
       CASE WHEN p.name COLLATE Latin1_General_BIN2 LIKE '@[a-z]%' THEN N'OK' ELSE N'NE VALJA' END AS Provera
FROM sys.parameters p JOIN sys.objects o ON o.object_id = p.object_id
WHERE SCHEMA_NAME(o.schema_id) IN (N'api_dev',N'api_qa') AND p.name <> N''
ORDER BY Sema, o.name, p.parameter_id;
GO
