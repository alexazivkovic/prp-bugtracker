USE [BugTracker];
GO

DROP VIEW IF EXISTS api_dev.PROJEKTI;
DROP VIEW IF EXISTS api_dev.GRESKE;
DROP VIEW IF EXISTS api_dev.OTVORENE_GRESKE;
DROP VIEW IF EXISTS api_dev.KOMENTARI;
DROP VIEW IF EXISTS api_qa.PREGLED_PROJEKATA;
DROP VIEW IF EXISTS api_qa.GRESKE;
DROP VIEW IF EXISTS api_qa.OTVORENE_GRESKE;
DROP VIEW IF EXISTS api_qa.KOMENTARI;
GO
DROP VIEW IF EXISTS spec.vw_PREGLED_PROJEKATA;
DROP VIEW IF EXISTS spec.vw_OTVORENE_GRESKE;
DROP VIEW IF EXISTS spec.vw_KOMENTAR;
DROP VIEW IF EXISTS spec.vw_GRESKA;
GO

CREATE VIEW spec.vw_GRESKA
WITH ENCRYPTION
AS
    SELECT  g.Id,
            g.IdProjekta,
            p.Naziv   AS NazivProjekta,
            p.Verzija AS VerzijaProjekta,
            g.Poruka,
            g.Ozbiljnost,
            CASE g.Ozbiljnost WHEN 1 THEN N'Критична'
                              WHEN 2 THEN N'Висока'
                              WHEN 3 THEN N'Средња'
                              WHEN 4 THEN N'Ниска'
                              ELSE        N'Информативна' END AS OpisOzbiljnosti,
            g.DatumPrijave,
            g.StatusGr,
            (SELECT COUNT(*) FROM impl.tblKomentar AS k WHERE k.IdGreske = g.Id) AS BrojKomentara
    FROM    impl.tblGreska   AS g
    JOIN    impl.tblProjekat AS p ON p.Id = g.IdProjekta;
GO

CREATE VIEW spec.vw_KOMENTAR
WITH ENCRYPTION
AS
    SELECT  d.IdKomentara AS Id,
            d.IdGreske,
            g.Poruka   AS PorukaGreske,
            g.StatusGr AS StatusGreske,
            p.Naziv    AS NazivProjekta,
            d.Autor,
            d.DatumKom,
            d.Tekst,
            d.Prioritet,
            d.OperativniSistem,
            d.Pregledac,
            d.BrojOznaka,
            d.SadrzajXML AS SirovXML
    FROM    impl.vwKomentarDetalji AS d
    JOIN    impl.tblGreska   AS g ON g.Id = d.IdGreske
    JOIN    impl.tblProjekat AS p ON p.Id = g.IdProjekta;
GO

CREATE VIEW spec.vw_OTVORENE_GRESKE
WITH ENCRYPTION
AS
    SELECT  v.Id, v.IdProjekta, v.NazivProjekta, v.VerzijaProjekta,
            v.Poruka, v.Ozbiljnost, v.OpisOzbiljnosti,
            v.DatumPrijave, v.StatusGr, v.BrojKomentara,
            DATEDIFF(DAY, v.DatumPrijave, CAST(GETDATE() AS DATE)) AS DanaOtvorena
    FROM    spec.vw_GRESKA AS v
    WHERE   v.StatusGr IN (N'Отворена', N'УПроцесуРешавања');
GO

CREATE VIEW spec.vw_PREGLED_PROJEKATA
WITH ENCRYPTION
AS
    SELECT  p.Id, p.Naziv AS NazivProjekta, p.Verzija,
            COUNT(g.Id) AS UkupnoGresaka,
            SUM(CASE WHEN g.StatusGr IN (N'Отворена', N'УПроцесуРешавања') THEN 1 ELSE 0 END) AS Nereseno,
            SUM(CASE WHEN g.Ozbiljnost = 1 THEN 1 ELSE 0 END) AS Kriticnih
    FROM    impl.tblProjekat AS p
    LEFT JOIN impl.tblGreska AS g ON g.IdProjekta = p.Id
    GROUP BY p.Id, p.Naziv, p.Verzija;
GO

CREATE VIEW api_dev.PROJEKTI AS
    SELECT Id, NazivProjekta, Verzija, UkupnoGresaka, Nereseno, Kriticnih
    FROM   spec.vw_PREGLED_PROJEKATA;
GO

CREATE VIEW api_dev.GRESKE AS
    SELECT Id, IdProjekta, NazivProjekta, VerzijaProjekta, Poruka,
           Ozbiljnost, OpisOzbiljnosti, DatumPrijave, StatusGr, BrojKomentara
    FROM   spec.vw_GRESKA;
GO

CREATE VIEW api_dev.OTVORENE_GRESKE AS
    SELECT Id, IdProjekta, NazivProjekta, Poruka, Ozbiljnost, OpisOzbiljnosti,
           DatumPrijave, StatusGr, BrojKomentara, DanaOtvorena
    FROM   spec.vw_OTVORENE_GRESKE;
GO

CREATE VIEW api_dev.KOMENTARI AS
    SELECT Id, IdGreske, PorukaGreske, StatusGreske, NazivProjekta, Autor,
           DatumKom, Tekst, Prioritet, OperativniSistem, Pregledac, BrojOznaka, SirovXML
    FROM   spec.vw_KOMENTAR;
GO

CREATE VIEW api_qa.PREGLED_PROJEKATA AS
    SELECT Id, NazivProjekta, Verzija, UkupnoGresaka, Nereseno, Kriticnih
    FROM   spec.vw_PREGLED_PROJEKATA;
GO

CREATE VIEW api_qa.GRESKE AS
    SELECT Id, NazivProjekta, VerzijaProjekta, Poruka, Ozbiljnost,
           OpisOzbiljnosti, DatumPrijave, StatusGr, BrojKomentara
    FROM   spec.vw_GRESKA;
GO

CREATE VIEW api_qa.OTVORENE_GRESKE AS
    SELECT Id, NazivProjekta, Poruka, Ozbiljnost, OpisOzbiljnosti,
           DatumPrijave, StatusGr, BrojKomentara, DanaOtvorena
    FROM   spec.vw_OTVORENE_GRESKE;
GO

CREATE VIEW api_qa.KOMENTARI AS
    SELECT Id, IdGreske, PorukaGreske, StatusGreske, NazivProjekta, Autor,
           DatumKom, Tekst, Prioritet, OperativniSistem, Pregledac, BrojOznaka
    FROM   spec.vw_KOMENTAR;
GO
