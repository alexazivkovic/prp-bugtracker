-- test zahteva 13: OUTPUT klauzula i arhiva statusa
USE [BugTracker];
GO
SET NOCOUNT ON;
TRUNCATE TABLE impl.tblHistorijaStatusa;

PRINT N'== promene kroz api_dev.PromeniStatus (omotac se NIJE menjao) ==';
EXEC api_dev.PromeniStatus @idGreske = 1, @noviStatus = N'УПроцесуРешавања';
EXEC api_dev.PromeniStatus @idGreske = 1, @noviStatus = N'Решена';
EXEC api_dev.PromeniStatus @idGreske = 2, @noviStatus = N'Затворена';
SELECT Id, IdGreske, StariStatus, NoviStatus, Korisnik FROM api_dev.ISTORIJA_STATUSA ORDER BY Id;

PRINT N'== isto u isto se NE belezi ==';
DECLARE @pre INT = (SELECT COUNT(*) FROM impl.tblHistorijaStatusa);
EXEC api_dev.PromeniStatus @idGreske = 1, @noviStatus = N'Решена';
SELECT @pre AS PreBroj, (SELECT COUNT(*) FROM impl.tblHistorijaStatusa) AS PosleBroj;

PRINT N'== i promena koju izvede TRIGER se arhivira - nema rupa u istoriji ==';
DECLARE @k INT;
EXEC api_dev.DodajKomentar @idGreske = 3, @autor = N'Тест Аутор',
     @tekst = N'Исправљено у 1.8.5', @resenje = N'Замењен GPS провајдер', @idKomentar = @k OUTPUT;
SELECT Id, IdGreske, StariStatus, NoviStatus FROM api_dev.ISTORIJA_STATUSA WHERE IdGreske = 3;

PRINT N'== OUTPUT bez INTO - vracanje redova pozivaocu ==';
UPDATE impl.tblGreska SET StatusGr = N'Отворена'
OUTPUT deleted.Id AS Greska, deleted.StatusGr AS PreIzmene, inserted.StatusGr AS PosleIzmene
WHERE Id = 2;

PRINT N'== zasto tblHistorijaStatusa nema CHECK ni strani kljuc ==';
BEGIN TRY
    ALTER TABLE impl.tblHistorijaStatusa ADD CONSTRAINT CK_Proba CHECK (LEN(NoviStatus) > 0);
    EXEC sp_executesql N'
        UPDATE impl.tblGreska SET StatusGr = N''Затворена''
        OUTPUT deleted.Id, deleted.StatusGr, inserted.StatusGr
        INTO   impl.tblHistorijaStatusa (IdGreske, StariStatus, NoviStatus)
        WHERE  Id = 4;';
    PRINT N'>> PROSLO - neocekivano!';
END TRY
BEGIN CATCH PRINT N'>> odbijeno: ' + ERROR_MESSAGE(); END CATCH
ALTER TABLE impl.tblHistorijaStatusa DROP CONSTRAINT IF EXISTS CK_Proba;
GO
