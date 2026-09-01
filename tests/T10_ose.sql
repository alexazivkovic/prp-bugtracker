-- test zahteva 10: axis specifiers u objektima koje aplikacija stvarno zove
USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== child:: i descendant-or-self:: u impl.vwKomentarDetalji ==';
PRINT N'   (taj pogled hrani spec.vw_KOMENTAR, tj. ekran "komentari")';
SELECT IdKomentara, Autor, Tekst, Prioritet, OperativniSistem, Pregledac, BrojOznaka
FROM impl.vwKomentarDetalji ORDER BY IdKomentara;

PRINT N'== descendant-or-self:: u api_dev.OZNAKE_GRESKE - ekran "detalji/oznake" ==';
SELECT * FROM api_dev.OZNAKE_GRESKE(1);

PRINT N'== parent:: u api_dev.OKRUZENJA_GRESKE - ekran "detalji/okruzenja" ==';
PRINT N'   cvor nalazimo po <os>, a treba nam i brat <pregledac>;';
PRINT N'   put do brata ide preko roditelja, a SQL Server od obrnutih osa';
PRINT N'   podrzava SAMO parent:: (nema ancestor::, nema preceding-sibling::)';
SELECT * FROM api_dev.OKRUZENJA_GRESKE(3);

PRINT N'== parent:: sa filterom - QA ekran "greske po sistemu" ==';
SELECT IdGreske, NazivProjekta, Autor, OperativniSistem, Pregledac
FROM api_qa.GRESKE_PO_SISTEMU(N'Android');

PRINT N'== dokaz da je // samo precica za descendant-or-self::node()/child:: ==';
SELECT k.Id,
       k.SadrzajXML.value('count(//oznaka)', 'INT')                                  AS Skraceno,
       k.SadrzajXML.value('count(/descendant-or-self::node()/child::oznaka)', 'INT') AS PunOblik
FROM impl.tblKomentar k WHERE k.Id >= 3 ORDER BY k.Id;

PRINT N'== koje ose SQL Server uopste podrzava ==';
SELECT N'child, descendant, descendant-or-self, parent, attribute, self' AS Podrzane,
       N'ancestor, ancestor-or-self, following-sibling, preceding-sibling' AS NisuPodrzane;
GO
