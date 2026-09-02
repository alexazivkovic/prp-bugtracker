USE master;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
GO

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

DROP AGGREGATE IF EXISTS impl.SpojPoruke;
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = N'BugTrackerCLR')
    DROP ASSEMBLY BugTrackerCLR;
GO

CREATE ASSEMBLY BugTrackerCLR
    FROM N'/var/opt/mssql/clr/BugTrackerCLR.dll'
    WITH PERMISSION_SET = SAFE;
GO

CREATE AGGREGATE impl.SpojPoruke (@poruka NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
EXTERNAL NAME BugTrackerCLR.[SpojPoruke];
GO

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
