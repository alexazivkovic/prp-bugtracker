-- Arhiviranje promena statusa preko OUTPUT klauzule, zahtev 13.
-- OUTPUT daje pristup pseudo-tabelama inserted i deleted, istim onima koje
-- postoje u trigerima, samo direktno u samoj DML naredbi - deleted drzi stanje
-- pre izmene, inserted posle. Mogao sam ovo i jos jednim trigerom, ali triger
-- je odvojen objekat pa onaj ko cita UPDATE uopste ne vidi da se nesto
-- arhivira; ovako je sve u istoj naredbi i u istom DML koraku, kako zahtev i
-- trazi.
-- Ovde procedura upr_PromeniStatus i triger trgAutoStatusResen dobijaju novu
-- funkcionalnost ali im se zaglavlje ne menja, pa api_dev.PromeniStatus i C#
-- aplikacija ostaju netaknuti. To je najbolji dokaz da slojevi rade posao
-- zbog kog postoje.

USE [BugTracker];
GO

-- ista procedura iz skripte 07, sad sa OUTPUT klauzulom
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
            -- kolone DatumPromene i Korisnik ne navodimo - popunjavaju ih
            -- DEFAULT ogranicenja SYSDATETIME() i SUSER_SNAME() iz skripte 02
            OUTPUT  deleted.Id, deleted.StatusGr, inserted.StatusGr
            INTO    impl.tblHistorijaStatusa (IdGreske, StariStatus, NoviStatus)
            WHERE   Id = @idGreske
              AND   StatusGr <> @noviStatus;   -- ne belezi "promenu" iz X u X

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

-- isti triger iz skripte 03, sad i on arhivira.
-- bez ovoga bi promene koje sistem izvede sam (kad komentar nosi <resenje>)
-- prosle nezabelezeno i istorija bi imala rupe.
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

-- ekran "istorija statusa" u obe aplikacije.
-- LEFT JOIN namerno: istorija NEMA strani kljuc (to zabranjuje OUTPUT INTO),
-- pa red o obrisanoj gresci sme da prezivi. INNER bi ga tiho sakrio,
-- a arhiva to ne sme da radi.
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
