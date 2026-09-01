-- CLR sklop i agregatna funkcija iz zahteva 8, plus pogled koji je koristi.
-- Agregat spaja poruke gresaka u jedan string; iza njega stoji QA ekran
-- "sazetak po projektu", jedan red po projektu sa svim porukama odjednom.
-- C# izvor je u clr/BugTrackerCLR/SpojPoruke.cs, a pre ove skripte treba
-- pustiti scripts/build-clr-only.sh da napravi DLL i ubaci ga u kontejner.

USE master;
GO

-- clr enabled je napredna opcija pa prvo show advanced options
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
GO

-- od 2017 svaki CLR sklop se tretira kao UNSAFE bez obzira na PERMISSION_SET,
-- pa nepotpisan sklop puca sa Msg 10343.
-- NE gasimo 'clr strict security' (to bi ubilo zastitu za celu instancu),
-- nego upisujemo hes sklopa u spisak poverljivih. ako se sklop promeni,
-- promeni se i hes i poverenje pada - to i jeste poenta.
DECLARE @hes VARBINARY(64) =
(
    SELECT HASHBYTES('SHA2_512', BulkColumn)
    FROM   OPENROWSET(BULK N'/var/opt/mssql/clr/BugTrackerCLR.dll', SINGLE_BLOB) AS bin
);

IF EXISTS (SELECT 1 FROM sys.trusted_assemblies WHERE hash = @hes)
    EXEC sys.sp_drop_trusted_assembly @hash = @hes;

EXEC sys.sp_add_trusted_assembly @hash = @hes,
     @description = N'BugTrackerCLR - UDA SpojPoruke (PRP projekat 10)';
GO

USE [BugTracker];
GO

-- agregat zavisi od sklopa pa se rusi prvi
DROP AGGREGATE IF EXISTS impl.SpojPoruke;
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = N'BugTrackerCLR')
    DROP ASSEMBLY BugTrackerCLR;
GO

-- sklop se FIZICKI kopira u bazu, posle ovoga DLL na disku vise ne treba
-- i sklop putuje uz backup.
-- SAFE = kod sme samo da racuna, bez fajlova/mreze/neupravljanog koda.
CREATE ASSEMBLY BugTrackerCLR
    FROM N'/var/opt/mssql/clr/BugTrackerCLR.dll'
    WITH PERMISSION_SET = SAFE;
GO

-- tip parametra mora da odgovara metodi Accumulate (SqlString -> NVARCHAR),
-- RETURNS metodi Terminate. uglaste zagrade oko klase jer bi ime sa tackom
-- (prostor imena) inace zbunilo parser.
-- agregat ide u impl - to je implementacija, aplikacija ga vidi tek kroz spec.
CREATE AGGREGATE impl.SpojPoruke (@poruka NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
EXTERNAL NAME BugTrackerCLR.[SpojPoruke];
GO

-- ekran koji agregat stvarno koristi: QA "sazetak po projektu".
-- jedan red po projektu sa SVIM porukama u jednom polju, da se stanje vidi
-- na prvi pogled bez otvaranja svake greske.
-- LEFT JOIN da se i projekat bez gresaka pojavi (kardinalnost 0,M)
CREATE OR ALTER VIEW spec.vw_SAZETAK_PROJEKATA
WITH ENCRYPTION
AS
    SELECT  p.Id AS IdProjekta, p.Naziv AS NazivProjekta,
            COUNT(g.Id) AS BrojGresaka,
            impl.SpojPoruke(g.Poruka) AS SvePoruke
    FROM    impl.tblProjekat AS p
    LEFT JOIN impl.tblGreska AS g ON g.IdProjekta = p.Id
    GROUP BY p.Id, p.Naziv;
GO

CREATE OR ALTER VIEW api_qa.SAZETAK_PROJEKATA AS
    SELECT IdProjekta, NazivProjekta, BrojGresaka, SvePoruke FROM spec.vw_SAZETAK_PROJEKATA;
GO

CREATE OR ALTER VIEW api_dev.SAZETAK_PROJEKATA AS
    SELECT IdProjekta, NazivProjekta, BrojGresaka, SvePoruke FROM spec.vw_SAZETAK_PROJEKATA;
GO
