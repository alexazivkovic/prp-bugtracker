-- test zahteva 3: procedure, kastomizovani izuzeci, tblErrorLog
USE [BugTracker];
GO
SET NOCOUNT ON;
DELETE FROM impl.tblErrorLog;

PRINT N'== spec objekti su sifrovani (WITH ENCRYPTION) ==';
SELECT o.name, o.type_desc,
       CASE WHEN OBJECT_DEFINITION(o.object_id) IS NULL THEN N'DA' ELSE N'ne' END AS Sifrovan
FROM sys.objects o WHERE SCHEMA_NAME(o.schema_id) = N'spec' AND o.type IN ('P','FN','IF','V')
ORDER BY o.type_desc, o.name;

PRINT N'== svaka validacija vraca poslovnu poruku iz tabela SPI/VPI ==';
DECLARE @r TABLE (RB INT IDENTITY, Test NVARCHAR(30), Broj INT, Poruka NVARCHAR(90));
DECLARE @x INT;

BEGIN TRY EXEC spec.upr_PrijaviGresku 999,N'Т',2,NULL,N'Отворена',@x OUTPUT;
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Nepostojeci projekat',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH
BEGIN TRY EXEC spec.upr_PrijaviGresku 1,N'   ',2,NULL,N'Отворена',@x OUTPUT;
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Prazna poruka',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH
BEGIN TRY EXEC spec.upr_PrijaviGresku 1,N'Т',7,NULL,N'Отворена',@x OUTPUT;
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Ozbiljnost 7',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH
BEGIN TRY EXEC spec.upr_PrijaviGresku 1,N'Т',2,NULL,N'Чека',@x OUTPUT;
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Los status',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH
BEGIN TRY EXEC spec.upr_PrijaviGresku 1,N'Т',2,'2030-01-01',N'Отворена',@x OUTPUT;
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Datum u buducnosti',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH
BEGIN TRY EXEC spec.upr_DodajKomentar @idGreske=999,@autor=N'А',@tekst=N'т';
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Nepostojeca greska',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH
BEGIN TRY EXEC spec.upr_DodajKomentar @idGreske=1,@autor=N'А',@tekst=N'  ';
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Prazan tekst komentara',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH
BEGIN TRY EXEC spec.upr_PromeniStatus 1,N'Ниједан';
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Promena u los status',ERROR_NUMBER(),ERROR_MESSAGE()); END CATCH

SELECT * FROM @r ORDER BY RB;

PRINT N'== sve je zavrsilo u dnevniku (TRY...CATCH -> tblErrorLog) ==';
SELECT Id, Procedura, BrojGreske, Nivo, Linija, Korisnik FROM impl.tblErrorLog ORDER BY Id;
GO
