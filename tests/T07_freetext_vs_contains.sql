-- test zahteva 7: FREETEXT naspram CONTAINS, isti termini
-- ovo su dva rezima koja aplikacija nudi: 'C' napredna, 'F' slobodna
USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== jedna tacna rec - oba rezima daju isto ==';
EXEC api_dev.PretraziGreske @upit = N'ресетовања', @rezim = 'C';
EXEC api_dev.PretraziGreske @upit = N'ресетовања', @rezim = 'F';

PRINT N'== visecalni niz: CONTAINS puca, FREETEXT radi ==';
-- kroz sp_executesql jer je Msg 7630 greska KOMPILACIJE, a TRY...CATCH
-- hvata samo greske izvrsavanja. dinamicki SQL se kompajlira kao zaseban
-- paket u trenutku izvrsavanja pa je njegova greska uhvatljiva.
BEGIN TRY
    EXEC sp_executesql N'EXEC api_dev.PretraziGreske @upit = N''корисник лозинка пријава'', @rezim = ''C'';';
END TRY
BEGIN CATCH
    PRINT N'>> CONTAINS odbio: ' + ERROR_MESSAGE();
END CATCH

EXEC api_dev.PretraziGreske @upit = N'корисник лозинка пријава', @rezim = 'F';

PRINT N'== rangiranje: FREETEXTTABLE razlikuje stepen podudaranja ==';
SELECT ft.[RANK] AS Relevantnost, g.Id, g.Poruka
FROM   FREETEXTTABLE(impl.tblGreska, Poruka, N'корисник не може да се пријави') AS ft
JOIN   impl.tblGreska g ON g.Id = ft.[KEY]
ORDER BY ft.[RANK] DESC;

PRINT N'== isti upit kroz CONTAINSTABLE ==';
SELECT ct.[RANK] AS Relevantnost, g.Id, g.Poruka
FROM   CONTAINSTABLE(impl.tblGreska, Poruka, N'лозинке OR GPS OR Safari') AS ct
JOIN   impl.tblGreska g ON g.Id = ct.[KEY]
ORDER BY ct.[RANK] DESC;
GO
