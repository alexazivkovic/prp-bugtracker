-- Pretraga kroz komentare, zahtev 11. Iza ovoga je ekran "Nadji po terminu":
-- korisnik ukuca rec i dobije greske plus tacno mesto u komentaru gde se ta
-- rec javlja. Spaja dva mehanizma - CONTAINS i xml.nodes().

USE [BugTracker];
GO

DROP PROCEDURE IF EXISTS api_dev.NadjiPoTerminu;
DROP PROCEDURE IF EXISTS api_qa.NadjiPoTerminu;
DROP PROCEDURE IF EXISTS spec.upr_NadjiPoTerminu;
GO

-- CONTAINS je grubi filter: brz je jer ide preko indeksa, ali zna samo da red
-- sadrzi termin, ne i gde u XML strukturi. nodes() je fini filter i kaze tacno
-- u kom elementu je pogodak, ali sam po sebi mora da prodje kroz svaki red.
-- Zato ih koristim zajedno - prvo suzimo skup, pa onda tacno lociramo.
CREATE OR ALTER PROCEDURE spec.upr_NadjiPoTerminu
    @termin NVARCHAR(200)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @termin IS NULL OR LEN(LTRIM(RTRIM(@termin))) = 0
            THROW 50050, N'Термин претраге не сме бити празан.', 1;

        DECLARE @cist NVARCHAR(200) = LTRIM(RTRIM(@termin));
        -- navodnici unutar stringa su obavezni za oblik sa dzokerom
        DECLARE @ftUpit NVARCHAR(400) = N'"' + @cist + N'*"';

        SELECT  N'Коментар' AS GdePronadjeno,
                g.Id AS IdGreske, p.Naziv AS Projekat, g.StatusGr,
                k.Id AS IdKomentara, k.Autor, k.DatumKom,
                el.cvor.value('local-name(.)', 'NVARCHAR(50)')  AS ElementXML,
                el.cvor.value('.',             'NVARCHAR(400)') AS Sadrzaj
        FROM    impl.tblKomentar AS k
        JOIN    impl.tblGreska   AS g ON g.Id = k.IdGreske
        JOIN    impl.tblProjekat AS p ON p.Id = g.IdProjekta
        -- '/kom//*[not(*)]' = listovi stabla, elementi bez elemenata-dece.
        -- sa '/kom/*' bi <okruzenje> vratio slepljeno "Android 14Chrome Mobile"
        CROSS APPLY k.SadrzajXML.nodes('/kom//*[not(*)]') AS el(cvor)
        WHERE   CONTAINS(k.SadrzajXML, @ftUpit)
          AND   el.cvor.value('.', 'NVARCHAR(400)') LIKE N'%' + @cist + N'%'

        UNION ALL

        -- i pogodak u samoj poruci greske, da korisnik ne mora dvaput da trazi
        SELECT  N'Порука грешке', g.Id, p.Naziv, g.StatusGr,
                NULL, NULL, NULL, N'Poruka', CAST(g.Poruka AS NVARCHAR(400))
        FROM    impl.tblGreska   AS g
        JOIN    impl.tblProjekat AS p ON p.Id = g.IdProjekta
        WHERE   CONTAINS(g.Poruka, @ftUpit)

        ORDER BY IdGreske, GdePronadjeno, IdKomentara;
    END TRY
    BEGIN CATCH
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_NadjiPoTerminu', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
GO

CREATE PROCEDURE api_dev.NadjiPoTerminu @termin NVARCHAR(200)
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_NadjiPoTerminu @termin; END
GO

CREATE PROCEDURE api_qa.NadjiPoTerminu @termin NVARCHAR(200)
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_NadjiPoTerminu @termin; END
GO
