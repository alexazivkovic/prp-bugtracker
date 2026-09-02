USE [BugTracker];
GO
PRINT N'== kolacija baze (mora Serbian_Cyrillic_100_CI_AS) ==';
SELECT name, collation_name FROM sys.databases WHERE name = N'BugTracker';

PRINT N'== cetiri seme, sve u vlasnistvu dbo (uslov za ownership chaining) ==';
SELECT s.name AS Sema, USER_NAME(s.principal_id) AS Vlasnik FROM sys.schemas s
WHERE s.name IN (N'impl',N'spec',N'api_dev',N'api_qa');

PRINT N'== korisnici i aplikacione uloge ==';
SELECT name, type_desc, default_schema_name FROM sys.database_principals
WHERE name IN (N'AppUserDEV',N'AppUserQA',N'DataProviderDEV',N'DataProviderQA');

PRINT N'== demo podaci - mora 3 / 4 / 7 ==';
SELECT N'ПРОЈЕКАТ' AS Tabela, COUNT(*) AS Uneto FROM impl.tblProjekat
UNION ALL SELECT N'ГРЕШКА', COUNT(*) FROM impl.tblGreska
UNION ALL SELECT N'КОМЕНТАР', COUNT(*) FROM impl.tblKomentar;

PRINT N'== sortiranje po srpskoj azbuci (O, R, U) - dokaz kolacije ==';
SELECT DISTINCT StatusGr FROM impl.tblGreska ORDER BY StatusGr;
GO
