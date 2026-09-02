USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== izvestaj kao XML - ono sto aplikacija snima u .xml fajl ==';
EXEC api_qa.IzvestajAktivnostiXml;

PRINT N'== isti izvestaj rasclanjen u redove - ono sto meni prikazuje ==';
SELECT * FROM api_qa.AKTIVNOST_AUTORA ORDER BY BrojKomentara DESC, Autor;

PRINT N'== provera: broj iz FLWOR count() mora da se poklopi sa obicnim COUNT ==';
SELECT a.Autor, a.BrojKomentara AS IzFLWOR,
       (SELECT COUNT(*) FROM impl.tblKomentar k WHERE k.Autor = a.Autor) AS IzSQL
FROM spec.fnt_AktivnostAutora() a ORDER BY a.Autor;

PRINT N'== FLWOR sa WHERE - samo autori sa 2+ komentara ==';
DECLARE @svi XML = (
    SELECT k.Autor AS '@autor', d.Tekst AS 'tekst'
    FROM impl.tblKomentar k JOIN impl.vwKomentarDetalji d ON d.IdKomentara = k.Id
    FOR XML PATH('kom'), ROOT('komentari'), TYPE);
SELECT @svi.query('
  <aktivni>
  {
    for $a in distinct-values(/komentari/kom/@autor)
    let $g := /komentari/kom[@autor = $a]
    where count($g) > 1
    order by count($g) descending
    return <autor ime="{$a}" broj="{count($g)}"/>
  }
  </aktivni>') AS AutoriSaViseKomentara;
GO
