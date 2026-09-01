-- Matrica gresaka preko PIVOT-a, zahtev 12. Ovo je pocetni izvestaj QA
-- aplikacije - red po projektu, kolona po ozbiljnosti od 1 do 5, i zbir.
-- PIVOT vrednosti iz jedne kolone pretvara u zaglavlja kolona, uz agregaciju.

USE [BugTracker];
GO

DROP PROCEDURE IF EXISTS api_qa.upr_MatricaGresaka;
DROP PROCEDURE IF EXISTS api_qa.MatricaGresaka;
DROP PROCEDURE IF EXISTS api_dev.MatricaGresaka;
DROP PROCEDURE IF EXISTS spec.upr_MatricaGresaka;
GO

-- Staticki PIVOT, jer je skup ozbiljnosti fiksiran CHECK ogranicenjem na 1-5.
-- dinamicki (sklapanje kolona u string + sp_executesql) bio bi potreban samo
-- da vrednosti nisu unapred poznate.
-- !!! PIVOT implicitno grupise po SVIM kolonama izvora koje nisu ni
-- agregaciona ni FOR kolona. zato izvor sme da vuce samo ove kolone -
-- da sam povukao i DatumPrijave dobio bih red po datumu i matrica se raspada.
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
                pvt.[1] AS Kriticnih,          -- 1 = kriticna
                pvt.[2] AS Visokih,
                pvt.[3] AS Srednjih,
                pvt.[4] AS Niskih,
                pvt.[5] AS Informativnih,
                pvt.[1] + pvt.[2] + pvt.[3] + pvt.[4] + pvt.[5] AS Ukupno
        FROM
        (
            SELECT  p.Id AS IdProjekta, p.Naziv AS NazivProjekta, p.Verzija,
                    g.Ozbiljnost,           -- FOR kolona
                    g.Id AS IdGreske        -- agregaciona kolona
            FROM    impl.tblProjekat AS p
            -- LEFT: projekat bez gresaka mora da se vidi sa nulama.
            -- za takav red je Ozbiljnost NULL, ne upada ni u jednu kolonu,
            -- a COUNT(NULL) = 0
            LEFT JOIN impl.tblGreska AS g ON g.IdProjekta = p.Id
            WHERE   @idProjekta IS NULL OR p.Id = @idProjekta
        ) AS izvor
        PIVOT
        (
            -- imena kolona [1]..[5] moraju u uglaste zagrade, identifikator
            -- ne sme poceti cifrom
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

-- zahtev 12 doslovno kaze "procedura upr_MatricaGresaka u api_qa", a NZ 8
-- trazi PascalCase u api_ semama. dokumentacija je tu sama sa sobom u sukobu,
-- pa stoje oba imena - oba samo zovu spec, nema duplirane logike.
CREATE PROCEDURE api_qa.upr_MatricaGresaka @idProjekta INT = NULL
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_MatricaGresaka @idProjekta; END
GO

CREATE PROCEDURE api_qa.MatricaGresaka @idProjekta INT = NULL
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_MatricaGresaka @idProjekta; END
GO

CREATE PROCEDURE api_dev.MatricaGresaka @idProjekta INT = NULL
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_MatricaGresaka @idProjekta; END
GO
