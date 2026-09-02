USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== recnik FT indeksa nad XML kolonom ==';
PRINT N'   server indeksira SADRZAJ elemenata a tagove preskace:';
PRINT N'   postoji rec "android", ne postoji rec "os"';
SELECT TOP 10 display_term AS Rec, document_count AS BrojKomentara
FROM sys.dm_fts_index_keywords(DB_ID(N'BugTracker'), OBJECT_ID(N'impl.tblKomentar'))
WHERE display_term <> N'END OF FILE' ORDER BY document_count DESC, display_term;

PRINT N'== "Android" - nema ga ni u jednom <tekst>, samo u <os> ==';
PRINT N'   CONTAINS ga nalazi (indeksira ceo XML), nodes() kaze U KOM elementu';
EXEC api_dev.NadjiPoTerminu @termin = N'Android';

PRINT N'== "регресија" - u <oznaka> ==';
EXEC api_dev.NadjiPoTerminu @termin = N'регресија';

PRINT N'== "пријав" - pogodak i u komentaru i u poruci greske ==';
EXEC api_dev.NadjiPoTerminu @termin = N'пријав';

PRINT N'== prazan termin -> izuzetak 50050 ==';
BEGIN TRY EXEC api_dev.NadjiPoTerminu @termin = N'   ';
END TRY BEGIN CATCH PRINT N'>> ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE(); END CATCH
GO
