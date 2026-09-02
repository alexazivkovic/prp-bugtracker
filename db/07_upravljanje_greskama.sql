USE [BugTracker];
GO

DROP FUNCTION IF EXISTS spec.fns_ValidanStatus;
DROP FUNCTION IF EXISTS spec.fnt_DozvoljeniStatusi;
GO

CREATE FUNCTION spec.fnt_DozvoljeniStatusi ()
RETURNS TABLE
WITH ENCRYPTION, SCHEMABINDING
AS
RETURN
    SELECT N'Отворена'          AS StatusGr, 1 AS Redosled
    UNION ALL SELECT N'УПроцесуРешавања', 2
    UNION ALL SELECT N'Решена',           3
    UNION ALL SELECT N'Затворена',        4;
GO

CREATE FUNCTION spec.fns_ValidanStatus (@status NVARCHAR(20))
RETURNS BIT
WITH ENCRYPTION, SCHEMABINDING
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM spec.fnt_DozvoljeniStatusi()
                             WHERE StatusGr = @status)
                THEN 1 ELSE 0 END;
END
GO

CREATE OR ALTER PROCEDURE spec.upr_PrijaviGresku
    @idProjekta   INT,
    @poruka       NVARCHAR(MAX),
    @ozbiljnost   INT,
    @datumPrijave DATE         = NULL,
    @statusGr     NVARCHAR(20) = N'Отворена',
    @idGreske     INT          = NULL OUTPUT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @datumPrijave = ISNULL(@datumPrijave, CAST(GETDATE() AS DATE));

        IF NOT EXISTS (SELECT 1 FROM impl.tblProjekat WHERE Id = @idProjekta)
            THROW 50010, N'Пројекат не постоји. Није могуће убацити ГРЕШКУ.', 1;

        IF @poruka IS NULL OR LEN(LTRIM(RTRIM(@poruka))) = 0
            THROW 50011, N'Текст грешке не сме бити празан.', 1;

        IF @ozbiljnost IS NULL OR @ozbiljnost NOT BETWEEN 1 AND 5
            THROW 50012, N'Озбиљност мора бити вредност од 1 до 5.', 1;

        IF spec.fns_ValidanStatus(@statusGr) = 0
            THROW 50013, N'Статус мора бити у листи дозвољених вредности.', 1;

        IF @datumPrijave > CAST(GETDATE() AS DATE)
            THROW 50014, N'Датум пријаве не сме бити у будућности.', 1;

        BEGIN TRANSACTION;

            INSERT INTO impl.tblGreska (IdProjekta, Poruka, Ozbiljnost, DatumPrijave, StatusGr)
            VALUES (@idProjekta, @poruka, @ozbiljnost, @datumPrijave, @statusGr);

            SET @idGreske = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();

        EXEC impl.uprLogujGresku N'spec.upr_PrijaviGresku', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;

        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE spec.upr_DodajKomentar
    @idGreske   INT,
    @autor      NVARCHAR(100),
    @tekst      NVARCHAR(MAX),
    @prioritet  NVARCHAR(50)  = NULL,
    @os         NVARCHAR(60)  = NULL,
    @pregledac  NVARCHAR(60)  = NULL,
    @oznake     NVARCHAR(400) = NULL,
    @resenje    NVARCHAR(MAX) = NULL,
    @datumKom   DATETIME      = NULL,
    @idKomentar INT           = NULL OUTPUT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @datumKom = ISNULL(@datumKom, GETDATE());

        IF NOT EXISTS (SELECT 1 FROM impl.tblGreska WHERE Id = @idGreske)
            THROW 50020, N'Не постоји наведена грешка. Коментар не може бити унет.', 1;

        IF @tekst IS NULL OR LEN(LTRIM(RTRIM(@tekst))) = 0
            THROW 50021, N'XML коментара мора садржати елемент <tekst>.', 1;

        IF @autor IS NULL OR LEN(LTRIM(RTRIM(@autor))) = 0
            THROW 50022, N'Аутор коментара не сме бити празан.', 1;

        IF @datumKom > GETDATE()
            THROW 50023, N'Датум коментара не сме бити у будућности.', 1;

        DECLARE @xml XML =
        (
            SELECT  LTRIM(RTRIM(@tekst))     AS 'tekst',
                    NULLIF(LTRIM(RTRIM(ISNULL(@prioritet, N''))), N'') AS 'prioritet',
                    (SELECT @os AS 'os', @pregledac AS 'pregledac'
                     WHERE  @os IS NOT NULL OR @pregledac IS NOT NULL
                     FOR XML PATH('okruzenje'), TYPE),
                    (SELECT LTRIM(RTRIM(s.value)) AS 'oznaka'
                     FROM   STRING_SPLIT(ISNULL(@oznake, N''), ',') AS s
                     WHERE  LEN(LTRIM(RTRIM(s.value))) > 0
                     FOR XML PATH(''), ROOT('oznake'), TYPE),
                    NULLIF(LTRIM(RTRIM(ISNULL(@resenje, N''))), N'') AS 'resenje'
            FOR XML PATH('kom'), TYPE
        );

        IF impl.fnsImaTekst(@xml) = 0
            THROW 50021, N'XML коментара мора садржати елемент <tekst>.', 1;

        BEGIN TRANSACTION;

            INSERT INTO impl.tblKomentar (IdGreske, SadrzajXML, Autor, DatumKom)
            VALUES (@idGreske, @xml, @autor, @datumKom);

            SET @idKomentar = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_DodajKomentar', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
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

CREATE OR ALTER PROCEDURE api_dev.PrijaviGresku
    @idProjekta INT, @poruka NVARCHAR(MAX), @ozbiljnost INT,
    @datumPrijave DATE = NULL, @statusGr NVARCHAR(20) = N'Отворена',
    @idGreske INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC spec.upr_PrijaviGresku @idProjekta, @poruka, @ozbiljnost,
         @datumPrijave, @statusGr, @idGreske OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE api_dev.DodajKomentar
    @idGreske INT, @autor NVARCHAR(100), @tekst NVARCHAR(MAX),
    @prioritet NVARCHAR(50) = NULL, @os NVARCHAR(60) = NULL,
    @pregledac NVARCHAR(60) = NULL, @oznake NVARCHAR(400) = NULL,
    @resenje NVARCHAR(MAX) = NULL, @datumKom DATETIME = NULL,
    @idKomentar INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC spec.upr_DodajKomentar @idGreske, @autor, @tekst, @prioritet, @os,
         @pregledac, @oznake, @resenje, @datumKom, @idKomentar OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE api_dev.PromeniStatus @idGreske INT, @noviStatus NVARCHAR(20)
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_PromeniStatus @idGreske, @noviStatus; END
GO

DROP SYNONYM IF EXISTS api_dev.DOZVOLJENI_STATUSI;
DROP SYNONYM IF EXISTS api_qa.DOZVOLJENI_STATUSI;
GO
CREATE SYNONYM api_dev.DOZVOLJENI_STATUSI FOR spec.fnt_DozvoljeniStatusi;
CREATE SYNONYM api_qa.DOZVOLJENI_STATUSI  FOR spec.fnt_DozvoljeniStatusi;
GO
