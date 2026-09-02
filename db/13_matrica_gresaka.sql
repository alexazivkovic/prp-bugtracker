USE [BugTracker];
GO

DROP PROCEDURE IF EXISTS api_qa.upr_MatricaGresaka;
DROP PROCEDURE IF EXISTS api_qa.MatricaGresaka;
DROP PROCEDURE IF EXISTS api_dev.MatricaGresaka;
DROP PROCEDURE IF EXISTS spec.upr_MatricaGresaka;
GO

CREATE OR ALTER PROCEDURE spec.upr_MatricaGresaka
    @idProjekta INT = NULL
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @idProjekta IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM impl.tblProjekat WHERE Id = @idProjekta)
            THROW 50060, N'Пројекат не постоји. Матрица не може бити приказана.', 1;

        SELECT  pvt.IdProjekta, pvt.NazivProjekta, pvt.Verzija,
                pvt.[1] AS Kriticnih,
                pvt.[2] AS Visokih,
                pvt.[3] AS Srednjih,
                pvt.[4] AS Niskih,
                pvt.[5] AS Informativnih,
                pvt.[1] + pvt.[2] + pvt.[3] + pvt.[4] + pvt.[5] AS Ukupno
        FROM
        (
            SELECT  p.Id AS IdProjekta, p.Naziv AS NazivProjekta, p.Verzija,
                    g.Ozbiljnost,
                    g.Id AS IdGreske
            FROM    impl.tblProjekat AS p
            LEFT JOIN impl.tblGreska AS g ON g.IdProjekta = p.Id
            WHERE   @idProjekta IS NULL OR p.Id = @idProjekta
        ) AS izvor
        PIVOT
        (
            COUNT(IdGreske) FOR Ozbiljnost IN ([1], [2], [3], [4], [5])
        ) AS pvt
        ORDER BY pvt.IdProjekta;
    END TRY
    BEGIN CATCH
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_MatricaGresaka', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE api_qa.upr_MatricaGresaka @idProjekta INT = NULL
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_MatricaGresaka @idProjekta; END
GO

CREATE PROCEDURE api_qa.MatricaGresaka @idProjekta INT = NULL
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_MatricaGresaka @idProjekta; END
GO

CREATE PROCEDURE api_dev.MatricaGresaka @idProjekta INT = NULL
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_MatricaGresaka @idProjekta; END
GO
