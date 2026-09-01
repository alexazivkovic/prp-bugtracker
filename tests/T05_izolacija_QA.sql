-- test zahteva 5, QA strana. pokrenuti kao AppLoginQA.
EXEC sp_setapprole 'DataProviderQA', 'Prp#RoleQa2026!';
GO
SET NOCOUNT ON;
DECLARE @r TABLE (RB INT IDENTITY, Pokusaj NVARCHAR(42), Ishod NVARCHAR(30));
DECLARE @x INT;
PRINT N'uloga aktivna, USER_NAME() = ' + USER_NAME();

BEGIN TRY SELECT TOP 1 Id FROM api_qa.PREGLED_PROJEKATA;
          INSERT INTO @r VALUES (N'SELECT api_qa.PREGLED_PROJEKATA', N'dozvoljeno');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'SELECT api_qa.PREGLED_PROJEKATA', N'odbijeno - GRESKA!'); END CATCH
BEGIN TRY EXEC api_qa.upr_MatricaGresaka;
          INSERT INTO @r VALUES (N'EXEC api_qa.upr_MatricaGresaka', N'dozvoljeno');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'EXEC api_qa.upr_MatricaGresaka', N'odbijeno - GRESKA!'); END CATCH
BEGIN TRY SELECT TOP 1 StatusGr FROM api_qa.DOZVOLJENI_STATUSI();
          INSERT INTO @r VALUES (N'api_qa.DOZVOLJENI_STATUSI (sinonim)', N'dozvoljeno');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'api_qa.DOZVOLJENI_STATUSI (sinonim)', N'odbijeno - GRESKA!'); END CATCH
BEGIN TRY SELECT TOP 1 IdProjekta FROM api_qa.SAZETAK_PROJEKATA;
          INSERT INTO @r VALUES (N'SELECT api_qa.SAZETAK_PROJEKATA (CLR)', N'dozvoljeno');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'SELECT api_qa.SAZETAK_PROJEKATA (CLR)', N'odbijeno - GRESKA!'); END CATCH
BEGIN TRY EXEC api_dev.PrijaviGresku 1, N'QA не сме ово', 3, NULL, N'Отворена', @x OUTPUT;
          INSERT INTO @r VALUES (N'EXEC api_dev.PrijaviGresku', N'PROSLO - GRESKA!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'EXEC api_dev.PrijaviGresku', N'odbijeno - ispravno'); END CATCH
BEGIN TRY SELECT TOP 1 Id FROM impl.tblGreska;
          INSERT INTO @r VALUES (N'SELECT impl.tblGreska', N'PROSLO - GRESKA!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'SELECT impl.tblGreska', N'odbijeno - ispravno'); END CATCH
BEGIN TRY SELECT TOP 1 Id FROM spec.vw_GRESKA;
          INSERT INTO @r VALUES (N'SELECT spec.vw_GRESKA', N'PROSLO - GRESKA!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'SELECT spec.vw_GRESKA', N'odbijeno - ispravno'); END CATCH

SELECT * FROM @r ORDER BY RB;
GO
