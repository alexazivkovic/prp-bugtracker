USE [BugTracker];
GO

DROP PROCEDURE IF EXISTS api_dev.DetaljiGreske;
DROP PROCEDURE IF EXISTS api_qa.IzvestajAktivnostiXml;
DROP VIEW      IF EXISTS api_dev.AKTIVNOST_AUTORA;
DROP VIEW      IF EXISTS api_qa.AKTIVNOST_AUTORA;
DROP FUNCTION  IF EXISTS api_dev.OZNAKE_GRESKE;
DROP FUNCTION  IF EXISTS api_dev.OKRUZENJA_GRESKE;
DROP FUNCTION  IF EXISTS api_qa.GRESKE_PO_SISTEMU;
DROP PROCEDURE IF EXISTS spec.upr_DetaljiGreske;
DROP FUNCTION  IF EXISTS spec.fnt_AktivnostAutora;
DROP FUNCTION  IF EXISTS spec.fns_AktivnostAutoraXml;
DROP FUNCTION  IF EXISTS spec.fnt_GreskePoSistemu;
DROP FUNCTION  IF EXISTS spec.fnt_OkruzenjaGreske;
DROP FUNCTION  IF EXISTS spec.fnt_OznakeGreske;
GO

CREATE FUNCTION spec.fnt_OznakeGreske (@idGreske INT)
RETURNS TABLE
WITH ENCRYPTION
AS
RETURN
    SELECT  k.Id    AS IdKomentara,
            k.Autor,
            o.cvor.value('.', 'NVARCHAR(60)') AS Oznaka
    FROM    impl.tblKomentar AS k
    CROSS APPLY k.SadrzajXML.nodes('/descendant-or-self::node()/child::oznaka') AS o(cvor)
    WHERE   k.IdGreske = @idGreske;
GO

CREATE FUNCTION spec.fnt_OkruzenjaGreske (@idGreske INT)
RETURNS TABLE
WITH ENCRYPTION
AS
RETURN
    SELECT  k.Id    AS IdKomentara,
            k.Autor,
            k.DatumKom,
            o.cvor.value('(child::os)[1]',        'NVARCHAR(60)') AS OperativniSistem,
            o.cvor.value('(child::pregledac)[1]', 'NVARCHAR(60)') AS Pregledac
    FROM    impl.tblKomentar AS k
    CROSS APPLY k.SadrzajXML.nodes('/descendant::os/parent::okruzenje') AS o(cvor)
    WHERE   k.IdGreske = @idGreske;
GO

CREATE FUNCTION spec.fnt_GreskePoSistemu (@obrazacOS NVARCHAR(60))
RETURNS TABLE
WITH ENCRYPTION
AS
RETURN
    SELECT  g.Id           AS IdGreske,
            p.Naziv        AS NazivProjekta,
            g.Poruka,
            g.StatusGr,
            g.Ozbiljnost,
            k.Autor,
            o.cvor.value('(child::os)[1]',        'NVARCHAR(60)') AS OperativniSistem,
            o.cvor.value('(child::pregledac)[1]', 'NVARCHAR(60)') AS Pregledac
    FROM    impl.tblKomentar AS k
    JOIN    impl.tblGreska   AS g ON g.Id = k.IdGreske
    JOIN    impl.tblProjekat AS p ON p.Id = g.IdProjekta
    CROSS APPLY k.SadrzajXML.nodes('/descendant::os/parent::okruzenje') AS o(cvor)
    WHERE   o.cvor.value('(child::os)[1]', 'NVARCHAR(60)') LIKE N'%' + @obrazacOS + N'%';
GO

CREATE FUNCTION spec.fns_AktivnostAutoraXml ()
RETURNS XML
WITH ENCRYPTION
AS
BEGIN
    DECLARE @svi XML =
    (
        SELECT  k.Autor                                AS '@autor',
                CONVERT(NVARCHAR(30), k.DatumKom, 126) AS '@datum',
                d.Tekst                                AS 'tekst'
        FROM    impl.tblKomentar        AS k
        JOIN    impl.vwKomentarDetalji  AS d ON d.IdKomentara = k.Id
        FOR XML PATH('kom'), ROOT('komentari'), TYPE
    );

    RETURN @svi.query('
      <izvestaj>
      {
        (: kljucevi grupa :)
        for $a in distinct-values(/komentari/kom/@autor)
        let $g := /komentari/kom[@autor = $a]
        order by count($g) descending, $a
        return
          <autor ime="{$a}" broj="{count($g)}">
          {
            for $k in $g
            order by string(($k/@datum)[1]) descending
            return <komentar datum="{string(($k/@datum)[1])}">{string(($k/tekst)[1])}</komentar>
          }
          </autor>
      }
      </izvestaj>');
END
GO

CREATE FUNCTION spec.fnt_AktivnostAutora ()
RETURNS TABLE
WITH ENCRYPTION
AS
RETURN
    SELECT  a.cvor.value('@ime',  'NVARCHAR(100)')                      AS Autor,
            a.cvor.value('@broj', 'INT')                                AS BrojKomentara,
            a.cvor.value('(child::komentar/@datum)[1]', 'NVARCHAR(30)') AS PoslednjiKomentar,
            a.cvor.value('(child::komentar)[1]', 'NVARCHAR(300)')       AS PoslednjiTekst
    FROM    (SELECT spec.fns_AktivnostAutoraXml() AS x) AS izvor
    CROSS APPLY izvor.x.nodes('/izvestaj/autor') AS a(cvor);
GO

CREATE OR ALTER PROCEDURE spec.upr_DetaljiGreske
    @idGreske INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM impl.tblGreska WHERE Id = @idGreske)
            THROW 50040, N'Не постоји наведена грешка.', 1;

        SELECT Id, IdProjekta, NazivProjekta, VerzijaProjekta, Poruka,
               Ozbiljnost, OpisOzbiljnosti, DatumPrijave, StatusGr, BrojKomentara
        FROM   spec.vw_GRESKA WHERE Id = @idGreske;

        SELECT Id, Autor, DatumKom, Tekst, Prioritet, OperativniSistem, Pregledac, BrojOznaka
        FROM   spec.vw_KOMENTAR WHERE IdGreske = @idGreske ORDER BY DatumKom DESC;

        SELECT IdKomentara, Autor, Oznaka FROM spec.fnt_OznakeGreske(@idGreske);

        SELECT IdKomentara, Autor, DatumKom, OperativniSistem, Pregledac
        FROM   spec.fnt_OkruzenjaGreske(@idGreske);

        SELECT Id, StariStatus, NoviStatus, DatumPromene, Korisnik
        FROM   spec.vw_ISTORIJA_STATUSA WHERE IdGreske = @idGreske ORDER BY DatumPromene;
    END TRY
    BEGIN CATCH
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_DetaljiGreske', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
GO

CREATE FUNCTION api_dev.OZNAKE_GRESKE (@idGreske INT)
RETURNS TABLE AS RETURN SELECT * FROM spec.fnt_OznakeGreske(@idGreske);
GO

CREATE FUNCTION api_dev.OKRUZENJA_GRESKE (@idGreske INT)
RETURNS TABLE AS RETURN SELECT * FROM spec.fnt_OkruzenjaGreske(@idGreske);
GO

CREATE FUNCTION api_qa.GRESKE_PO_SISTEMU (@obrazacOs NVARCHAR(60))
RETURNS TABLE AS RETURN
    SELECT IdGreske, NazivProjekta, Poruka, StatusGr, Ozbiljnost,
           Autor, OperativniSistem, Pregledac
    FROM   spec.fnt_GreskePoSistemu(@obrazacOs);
GO

CREATE VIEW api_dev.AKTIVNOST_AUTORA AS
    SELECT Autor, BrojKomentara, PoslednjiKomentar, PoslednjiTekst
    FROM   spec.fnt_AktivnostAutora();
GO

CREATE VIEW api_qa.AKTIVNOST_AUTORA AS
    SELECT Autor, BrojKomentara, PoslednjiKomentar, PoslednjiTekst
    FROM   spec.fnt_AktivnostAutora();
GO

CREATE PROCEDURE api_dev.DetaljiGreske @idGreske INT
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_DetaljiGreske @idGreske; END
GO

CREATE PROCEDURE api_qa.IzvestajAktivnostiXml
AS BEGIN SET NOCOUNT ON; SELECT spec.fns_AktivnostAutoraXml() AS Izvestaj; END
GO
