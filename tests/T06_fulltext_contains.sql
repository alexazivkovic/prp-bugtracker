-- test zahteva 6: CONTAINS sa AND / OR / AND NOT / NEAR
-- ovo su tacno oni izrazi koje korisnik kuca u polje "napredna pretraga"
USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== indeksi: jezik mora biti Serbian (Cyrillic) ==';
SELECT OBJECT_NAME(fi.object_id) AS Tabela, c.name AS Kolona, l.name AS Jezik,
       fi.change_tracking_state_desc AS ChangeTracking
FROM sys.fulltext_indexes fi
JOIN sys.fulltext_index_columns fic ON fic.object_id = fi.object_id
JOIN sys.columns c ON c.object_id = fic.object_id AND c.column_id = fic.column_id
JOIN sys.fulltext_languages l ON l.lcid = fic.language_id;

PRINT N'== recnik invertovanog indeksa - dokaz da cirilicki word breaker radi ==';
SELECT TOP 10 display_term AS Rec, document_count AS BrojGresaka
FROM sys.dm_fts_index_keywords(DB_ID(N'BugTracker'), OBJECT_ID(N'impl.tblGreska'))
WHERE display_term <> N'END OF FILE' ORDER BY document_count DESC, display_term;

PRINT N'== jedna rec ==';
EXEC api_dev.PretraziGreske @upit = N'лозинке', @rezim = 'C';

PRINT N'== prefiks "учита*" - navodnici unutar stringa su obavezni ==';
EXEC api_dev.PretraziGreske @upit = N'"учита*"', @rezim = 'C';

PRINT N'== AND ==';
EXEC api_dev.PretraziGreske @upit = N'Safari AND слике', @rezim = 'C';

PRINT N'== OR ==';
EXEC api_dev.PretraziGreske @upit = N'лозинке OR GPS', @rezim = 'C';

PRINT N'== AND NOT (samostalno NOT ne postoji u Full-Text jeziku) ==';
EXEC api_dev.PretraziGreske @upit = N'"учита*" AND NOT Safari', @rezim = 'C';

PRINT N'== NEAR - najvise 3 reci izmedju, bilo kojim redom ==';
EXEC api_dev.PretraziGreske @upit = N'NEAR((Апликација, руши), 3, FALSE)', @rezim = 'C';

PRINT N'== NEAR sa razmakom 0 - mora vratiti prazno iako obe reci postoje ==';
EXEC api_dev.PretraziGreske @upit = N'NEAR((Апликација, локације), 0, FALSE)', @rezim = 'C';

PRINT N'== pretraga po opisu projekta (druga indeksirana kolona) ==';
SELECT Id, Naziv, Opis, Relevantnost FROM spec.fnt_ProjektiContains(N'продавница OR систем');

PRINT N'== CONTAINS(*, ...) - bilo koja indeksirana kolona tabele ==';
SELECT Id, Naziv FROM impl.tblProjekat WHERE CONTAINS(*, N'електронике');
GO
