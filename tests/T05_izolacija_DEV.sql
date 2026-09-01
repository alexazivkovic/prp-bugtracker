-- test zahteva 5, DEV strana. pokrenuti POVEZAN KAO AppLoginDEV:
--   sqlcmd -S localhost,1433 -U AppLoginDEV -P 'Prp#Dev2026!' -C -d BugTracker -i tests/T05_izolacija_DEV.sql
SET NOCOUNT ON;
DECLARE @r TABLE (RB INT IDENTITY, Faza NVARCHAR(12), Pokusaj NVARCHAR(40), Ishod NVARCHAR(30));
PRINT N'prijavljen kao ' + SUSER_SNAME() + N', korisnik baze ' + USER_NAME();

-- pre aktivacije uloge login nema NISTA, cak ni sopstveni API
BEGIN TRY SELECT TOP 1 Id FROM impl.tblGreska;
          INSERT INTO @r VALUES (N'pre uloge', N'SELECT impl.tblGreska', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'pre uloge', N'SELECT impl.tblGreska', N'odbijeno'); END CATCH
BEGIN TRY SELECT TOP 1 Id FROM api_dev.GRESKE;
          INSERT INTO @r VALUES (N'pre uloge', N'SELECT api_dev.GRESKE', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'pre uloge', N'SELECT api_dev.GRESKE', N'odbijeno'); END CATCH
SELECT * FROM @r ORDER BY RB;
GO

EXEC sp_setapprole 'DataProviderDEV', 'Prp#RoleDev2026!';
GO

SET NOCOUNT ON;
DECLARE @r2 TABLE (RB INT IDENTITY, Pokusaj NVARCHAR(40), Ishod NVARCHAR(30));
DECLARE @x INT;
PRINT N'uloga aktivna, USER_NAME() = ' + USER_NAME();

BEGIN TRY SELECT TOP 1 Id FROM api_dev.GRESKE;
          INSERT INTO @r2 VALUES (N'SELECT api_dev.GRESKE', N'dozvoljeno');
END TRY BEGIN CATCH INSERT INTO @r2 VALUES (N'SELECT api_dev.GRESKE', N'odbijeno - GRESKA!'); END CATCH
BEGIN TRY EXEC api_dev.PrijaviGresku 1, N'Тест изолације', 4, NULL, N'Отворена', @x OUTPUT;
          INSERT INTO @r2 VALUES (N'EXEC api_dev.PrijaviGresku', N'dozvoljeno');
END TRY BEGIN CATCH INSERT INTO @r2 VALUES (N'EXEC api_dev.PrijaviGresku', N'odbijeno - GRESKA!'); END CATCH
BEGIN TRY EXEC api_dev.MatricaGresaka;
          INSERT INTO @r2 VALUES (N'EXEC api_dev.MatricaGresaka', N'dozvoljeno');
END TRY BEGIN CATCH INSERT INTO @r2 VALUES (N'EXEC api_dev.MatricaGresaka', N'odbijeno - GRESKA!'); END CATCH
BEGIN TRY SELECT TOP 1 Id FROM impl.tblGreska;
          INSERT INTO @r2 VALUES (N'SELECT impl.tblGreska', N'PROSLO - GRESKA!');
END TRY BEGIN CATCH INSERT INTO @r2 VALUES (N'SELECT impl.tblGreska', N'odbijeno - ispravno'); END CATCH
BEGIN TRY SELECT TOP 1 Id FROM spec.vw_GRESKA;
          INSERT INTO @r2 VALUES (N'SELECT spec.vw_GRESKA', N'PROSLO - GRESKA!');
END TRY BEGIN CATCH INSERT INTO @r2 VALUES (N'SELECT spec.vw_GRESKA', N'odbijeno - ispravno'); END CATCH
BEGIN TRY EXEC spec.upr_PromeniStatus 1, N'Решена';
          INSERT INTO @r2 VALUES (N'EXEC spec.upr_PromeniStatus', N'PROSLO - GRESKA!');
END TRY BEGIN CATCH INSERT INTO @r2 VALUES (N'EXEC spec.upr_PromeniStatus', N'odbijeno - ispravno'); END CATCH
BEGIN TRY SELECT TOP 1 Id FROM api_qa.GRESKE;
          INSERT INTO @r2 VALUES (N'SELECT api_qa.GRESKE (tudji API)', N'PROSLO - GRESKA!');
END TRY BEGIN CATCH INSERT INTO @r2 VALUES (N'SELECT api_qa.GRESKE (tudji API)', N'odbijeno - ispravno'); END CATCH

SELECT * FROM @r2 ORDER BY RB;
GO
