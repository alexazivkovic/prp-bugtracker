-- test zahteva 12: PIVOT matrica. QA pocetni izvestaj.
USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== normalizovan prikaz, PRE pivotiranja ==';
SELECT p.Naziv AS Projekat, g.Ozbiljnost, COUNT(g.Id) AS Broj
FROM impl.tblProjekat p LEFT JOIN impl.tblGreska g ON g.IdProjekta = p.Id
GROUP BY p.Naziv, g.Ozbiljnost ORDER BY p.Naziv, g.Ozbiljnost;

PRINT N'== matrica za sve projekte (ime iz dokumentacije) ==';
EXEC api_qa.upr_MatricaGresaka;

PRINT N'== isto pod PascalCase imenom koje trazi NZ 8 ==';
EXEC api_qa.MatricaGresaka;

PRINT N'== jedan projekat ==';
EXEC api_qa.MatricaGresaka @idProjekta = 1;

PRINT N'== nepostojeci projekat -> izuzetak 50060 ==';
BEGIN TRY EXEC api_qa.MatricaGresaka @idProjekta = 999;
END TRY BEGIN CATCH PRINT N'>> ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE(); END CATCH

PRINT N'== UNPIVOT - obrnuta operacija, dokaz da matrica ne gubi podatke ==';
SELECT NazivProjekta, Nivo, Broj FROM
(
    SELECT p.Naziv AS NazivProjekta,
           SUM(CASE WHEN g.Ozbiljnost = 1 THEN 1 ELSE 0 END) AS Kriticnih,
           SUM(CASE WHEN g.Ozbiljnost = 2 THEN 1 ELSE 0 END) AS Visokih,
           SUM(CASE WHEN g.Ozbiljnost = 3 THEN 1 ELSE 0 END) AS Srednjih
    FROM impl.tblProjekat p LEFT JOIN impl.tblGreska g ON g.IdProjekta = p.Id
    GROUP BY p.Naziv
) AS siroko
UNPIVOT (Broj FOR Nivo IN (Kriticnih, Visokih, Srednjih)) AS uzano
WHERE Broj > 0 ORDER BY NazivProjekta, Nivo;
GO
