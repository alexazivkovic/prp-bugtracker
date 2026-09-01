-- test zahteva 8: CLR agregatna funkcija
USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== sklop je ucitan, dozvole SAFE ==';
SELECT name AS Sklop, permission_set_desc AS Dozvole, clr_name FROM sys.assemblies WHERE name = N'BugTrackerCLR';
SELECT SCHEMA_NAME(schema_id) + N'.' + name AS Agregat, type_desc FROM sys.objects WHERE type = 'AF';

PRINT N'== zastita NIJE ugasena - sklop je ucitan preko hesa ==';
SELECT name, CAST(value_in_use AS INT) AS Vrednost FROM sys.configurations
WHERE name IN ('clr enabled','clr strict security');
SELECT LEFT(CONVERT(NVARCHAR(200), hash, 1), 22) + N'...' AS SHA2_512, description
FROM sys.trusted_assemblies;

PRINT N'== agregat u stvarnoj upotrebi - QA ekran "sazetak po projektu" ==';
SELECT * FROM api_qa.SAZETAK_PROJEKATA ORDER BY IdProjekta;

PRINT N'== prazna grupa vraca NULL (IsNullIfEmpty = true) ==';
SELECT impl.SpojPoruke(Poruka) AS Rezultat FROM impl.tblGreska WHERE 1 = 0;

PRINT N'== NULL i prazni nizovi se preskacu (IsInvariantToNulls = true) ==';
SELECT impl.SpojPoruke(v.T) AS Rezultat
FROM (VALUES (N'прва'), (NULL), (N'друга'), (N'   '), (N'трећа')) AS v(T);

PRINT N'== bez GROUP BY, preko cele tabele ==';
SELECT impl.SpojPoruke(Poruka) AS SveGreske FROM impl.tblGreska;
GO
