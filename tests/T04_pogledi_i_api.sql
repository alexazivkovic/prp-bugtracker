USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== spec.vw_GRESKA - sa nazivom projekta, kako zahtev trazi ==';
SELECT Id, NazivProjekta, Ozbiljnost, OpisOzbiljnosti, StatusGr, BrojKomentara
FROM spec.vw_GRESKA ORDER BY Id;

PRINT N'== spec.vw_KOMENTAR - XML raspakovan u kolone ==';
SELECT Id, Autor, Tekst, Prioritet, OperativniSistem, Pregledac, BrojOznaka
FROM spec.vw_KOMENTAR ORDER BY Id;

PRINT N'== spec.vw_OTVORENE_GRESKE ==';
SELECT Id, NazivProjekta, OpisOzbiljnosti, StatusGr, DanaOtvorena
FROM spec.vw_OTVORENE_GRESKE ORDER BY Ozbiljnost, DatumPrijave;

PRINT N'== isto kroz api slojeve - aplikacija vidi SAMO ovo ==';
SELECT TOP 3 Id, NazivProjekta, StatusGr FROM api_dev.GRESKE ORDER BY Id;
SELECT * FROM api_qa.PREGLED_PROJEKATA ORDER BY Id;

PRINT N'== razlika dve API seme: api_dev.KOMENTARI ima SirovXML, api_qa nema ==';
SELECT N'api_dev' AS Sema, COUNT(*) AS BrojKolona FROM sys.columns
WHERE object_id = OBJECT_ID(N'api_dev.KOMENTARI')
UNION ALL
SELECT N'api_qa', COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(N'api_qa.KOMENTARI');

PRINT N'== popis api objekata (NZ 8: PascalCase procedure, UPPER_CASE pogledi) ==';
SELECT SCHEMA_NAME(schema_id) AS Sema, name AS Objekat, type_desc AS Vrsta
FROM sys.objects WHERE SCHEMA_NAME(schema_id) IN (N'api_dev',N'api_qa')
ORDER BY Sema, Vrsta, Objekat;
GO
