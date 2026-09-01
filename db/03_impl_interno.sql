-- Tri interne stvari koje aplikacija nikad ne vidi ali ih koriste gornji
-- slojevi: pogled koji rasclanjuje XML komentara na kolone, procedura koja
-- upisuje uhvacene greske u dnevnik, i triger iz zahteva 2.

USE [BugTracker];
GO

-- Jedino mesto gde se XML komentara rasclanjuje na kolone, da XPath putanje
-- ne bi stajale prekucane na tri mesta. Odavde cita i spec.vw_KOMENTAR i
-- procedura za detalje greske.
-- Putanje su namerno pisane punim osama a ne skracenicama. child:: je ovde
-- bas ono sto hocu, samo direktna deca <kom>, pa neki <tekst> ugnezdjen dublje
-- ne moze da me prevari. Za <os> i <pregledac> ide descendant-or-self:: jer
-- se <okruzenje> moze pojaviti i dublje ako neko posalje slozeniji komentar.
-- Skracenice / i // rade isto ali se iz njih ne vidi namera.
CREATE OR ALTER VIEW impl.vwKomentarDetalji
AS
    SELECT  k.Id        AS IdKomentara,
            k.IdGreske,
            k.Autor,
            k.DatumKom,
            -- [1] je obavezan, .value mora da dobije tacno jedan cvor
            k.SadrzajXML.value('(/child::kom/child::tekst)[1]',      'NVARCHAR(MAX)') AS Tekst,
            k.SadrzajXML.value('(/child::kom/child::prioritet)[1]',  'NVARCHAR(50)')  AS Prioritet,
            k.SadrzajXML.value('(/descendant-or-self::node()/child::os)[1]',
                               'NVARCHAR(60)')  AS OperativniSistem,
            k.SadrzajXML.value('(/descendant-or-self::node()/child::pregledac)[1]',
                               'NVARCHAR(60)')  AS Pregledac,
            k.SadrzajXML.value('count(/descendant-or-self::node()/child::oznaka)',
                               'INT')           AS BrojOznaka,
            k.SadrzajXML
    FROM    impl.tblKomentar AS k;
GO

-- uprLogujGresku - zove se iz CATCH blokova spec procedura.
-- stoji u impl a ne u spec zato sto NIJE operacija ATP-a, nego infrastruktura.
-- u spec ide samo ono sto cini javni ugovor baze.
CREATE OR ALTER PROCEDURE impl.uprLogujGresku
    @procedura  NVARCHAR(256),
    @brojGreske INT,
    @nivo       INT,
    @stanje     INT,
    @linija     INT,
    @poruka     NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    -- Id, DatumVreme i Korisnik popunjavaju IDENTITY i DEFAULT-ovi
    INSERT INTO impl.tblErrorLog (Procedura, BrojGreske, Nivo, Stanje, Linija, Poruka)
    VALUES (@procedura, @brojGreske, @nivo, @stanje, @linija, @poruka);
END
GO

-- trgAutoStatusResen (zahtev 2)
-- poslovno pravilo: kad programer u aplikaciji doda komentar i popuni polje
-- "resenje", greska automatski prelazi u 'Решена'. Aplikacija taj komentar
-- salje kao <kom>...<resenje>tekst</resenje></kom>, pa baza sama zatvara
-- gresku - korisnik ne mora posebno da menja status.
-- zasto triger a ne CHECK: CHECK ume samo da ODBIJE red. ovde povodom izmene
-- u JEDNOJ tabeli (KOMENTAR) treba promeniti DRUGU (GRESKA), a to deklarativno
-- ne moze. tacno po NZ 2: deklarativno -> triger -> procedura.
-- NAPOMENA: skripta 09 (zahtev 13) ovaj triger prosiruje OUTPUT klauzulom,
-- da i promene koje sistem izvede sam zavrse u arhivi.
CREATE OR ALTER TRIGGER impl.trgAutoStatusResen
ON impl.tblKomentar
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;   -- inace "(1 row affected)" iz trigera zbuni ADO.NET

    -- XML metode NE SMEJU direktno nad inserted/deleted (te pseudo-tabele
    -- se citaju iz loga i nemaju XML infrastrukturu), pa prvo prepis
    DECLARE @novi TABLE (IdGreske INT NOT NULL, Sadrzaj XML NOT NULL);

    INSERT INTO @novi (IdGreske, Sadrzaj)
    SELECT i.IdGreske, i.SadrzajXML FROM inserted AS i;

    IF NOT EXISTS (SELECT 1 FROM @novi AS n WHERE n.Sadrzaj.exist('//resenje') = 1)
        RETURN;   -- nista za nas, izlazi pre skupog UPDATE-a

    -- pisano skupovno! triger se okida JEDNOM PO NAREDBI, ne po redu.
    -- ako aplikacija posalje 20 komentara odjednom, inserted ima svih 20.
    UPDATE  g
    SET     g.StatusGr = N'Решена'
    FROM    impl.tblGreska AS g
    WHERE   g.StatusGr NOT IN (N'Решена', N'Затворена')   -- ne vracaj unazad
      AND   EXISTS (SELECT 1 FROM @novi AS n
                    WHERE n.IdGreske = g.Id AND n.Sadrzaj.exist('//resenje') = 1);
END
GO
