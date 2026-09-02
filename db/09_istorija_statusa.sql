USE [BugTracker];
GO

CREATE OR ALTER PROCEDURE spec.upr_PromeniStatus
    @idGreske   INT,
    @noviStatus NVARCHAR(20)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM impl.tblGreska WHERE Id = @idGreske)
            THROW 50030, N'Не постоји наведена грешка. Статус не може бити промењен.', 1;

        IF spec.fns_ValidanStatus(@noviStatus) = 0
            THROW 50031, N'Статус мора бити у листи дозвољених вредности.', 1;

        BEGIN TRANSACTION;

            UPDATE  impl.tblGreska
            SET     StatusGr = @noviStatus
            OUTPUT  deleted.Id, deleted.StatusGr, inserted.StatusGr
            INTO    impl.tblHistorijaStatusa (IdGreske, StariStatus, NoviStatus)
            WHERE   Id = @idGreske
              AND   StatusGr <> @noviStatus;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_PromeniStatus', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER TRIGGER impl.trgAutoStatusResen
ON impl.tblKomentar
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @novi TABLE (IdGreske INT NOT NULL, Sadrzaj XML NOT NULL);

    INSERT INTO @novi (IdGreske, Sadrzaj)
    SELECT i.IdGreske, i.SadrzajXML FROM inserted AS i;

    IF NOT EXISTS (SELECT 1 FROM @novi AS n WHERE n.Sadrzaj.exist('//resenje') = 1)
        RETURN;

    UPDATE  g
    SET     g.StatusGr = N'Решена'
    OUTPUT  deleted.Id, deleted.StatusGr, inserted.StatusGr
    INTO    impl.tblHistorijaStatusa (IdGreske, StariStatus, NoviStatus)
    FROM    impl.tblGreska AS g
    WHERE   g.StatusGr NOT IN (N'Решена', N'Затворена')
      AND   EXISTS (SELECT 1 FROM @novi AS n
                    WHERE n.IdGreske = g.Id AND n.Sadrzaj.exist('//resenje') = 1);
END
GO

CREATE OR ALTER VIEW spec.vw_ISTORIJA_STATUSA
WITH ENCRYPTION
AS
    SELECT  h.Id, h.IdGreske,
            p.Naziv AS NazivProjekta,
            g.Poruka,
            h.StariStatus, h.NoviStatus, h.DatumPromene, h.Korisnik
    FROM    impl.tblHistorijaStatusa AS h
    LEFT JOIN impl.tblGreska   AS g ON g.Id = h.IdGreske
    LEFT JOIN impl.tblProjekat AS p ON p.Id = g.IdProjekta;
GO

CREATE OR ALTER VIEW api_dev.ISTORIJA_STATUSA AS
    SELECT Id, IdGreske, NazivProjekta, Poruka, StariStatus, NoviStatus, DatumPromene, Korisnik
    FROM   spec.vw_ISTORIJA_STATUSA;
GO

CREATE OR ALTER VIEW api_qa.ISTORIJA_STATUSA AS
    SELECT Id, IdGreske, NazivProjekta, Poruka, StariStatus, NoviStatus, DatumPromene, Korisnik
    FROM   spec.vw_ISTORIJA_STATUSA;
GO
