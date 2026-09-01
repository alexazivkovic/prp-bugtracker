-- Tabele u impl semi sa svim ogranicenjima i indeksima, zahtev 2.
-- Strukturna pravila iz tabele 6 dokumentacije su ovde strani kljucevi, a
-- vrednosna iz tabele 8 su CHECK ogranicenja - sve deklarativno, kako NZ 2 i
-- trazi. Kreira se roditelj pa dete, rusi obrnuto, inace strani kljuc puca.

USE [BugTracker];
GO

DROP TABLE IF EXISTS impl.tblHistorijaStatusa;
DROP TABLE IF EXISTS impl.tblErrorLog;
DROP TABLE IF EXISTS impl.tblKomentar;
DROP TABLE IF EXISTS impl.tblGreska;
DROP TABLE IF EXISTS impl.tblProjekat;
GO
DROP FUNCTION IF EXISTS impl.fnsImaTekst;
GO

-- omotac za XML proveru.
-- probao sam prvo direktno u CHECK-u: CHECK (SadrzajXML.exist('//tekst')=1)
-- server odbija -> Msg 423 "Xml data type methods are not supported in check
-- constraints. Create a scalar user-defined function to wrap the method"
-- pa eto funkcije. SCHEMABINDING da se ne moze obrisati ispod ogranicenja.
CREATE FUNCTION impl.fnsImaTekst (@sadrzaj XML)
RETURNS BIT
WITH SCHEMABINDING
AS
BEGIN
    -- exist vraca NULL za NULL ulaz, a NULL bi u CHECK-u PROSAO (UNKNOWN),
    -- zato CASE svodi na 0
    RETURN CASE WHEN @sadrzaj.exist('//tekst') = 1 THEN 1 ELSE 0 END;
END
GO

-- Prvo PROJEKAT jer se sve ostalo naslanja na njega.
CREATE TABLE impl.tblProjekat
(
    Id      INT           IDENTITY(1,1) NOT NULL,   -- negovoreca sifra
    Naziv   NVARCHAR(200) NOT NULL,
    Opis    NVARCHAR(MAX) NOT NULL,                 -- ide pod Full-Text indeks
    Verzija NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_Projekat         PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Projekat_Naziv   UNIQUE (Naziv),          -- ogranicenje 1
    CONSTRAINT CK_Projekat_Id      CHECK (Id > 0),          -- ogranicenje 7

    -- LTRIM+RTRIM da i string od samih razmaka padne.
    -- (LEN inace ne broji prateće razmake ali broji vodece, pa LTRIM mora)
    CONSTRAINT CK_Projekat_Naziv   CHECK (LEN(LTRIM(RTRIM(Naziv)))   > 0),
    CONSTRAINT CK_Projekat_Opis    CHECK (LEN(LTRIM(RTRIM(Opis)))    > 0),
    CONSTRAINT CK_Projekat_Verzija CHECK (LEN(LTRIM(RTRIM(Verzija))) > 0)
);
GO

-- GRESKA. Ovde su dva reda iz SPI tabele pokrivena jednim stranim kljucem,
-- pa obrati paznju na komentar uz FK_Greska_Projekat.
CREATE TABLE impl.tblGreska
(
    Id           INT           IDENTITY(1,1) NOT NULL,
    IdProjekta   INT           NOT NULL,   -- NOT NULL = strukturno ogr. DG=1
    Poruka       NVARCHAR(MAX) NOT NULL,   -- Full-Text
    Ozbiljnost   INT           NOT NULL,   -- 1 = kriticna ... 5
    DatumPrijave DATE          NOT NULL,
    StatusGr     NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_Greska PRIMARY KEY CLUSTERED (Id),

    -- SPI tabela 6, dva reda odjednom:
    --  GRESKA/Insert -> Restrict (nema projekta = nema unosa)
    --  PROJEKAT/Delete -> Restrict (projekat sa greskama se ne brise)
    -- NO ACTION je i podrazumevano, pisem ga da se vidi da je namerno
    CONSTRAINT FK_Greska_Projekat FOREIGN KEY (IdProjekta)
        REFERENCES impl.tblProjekat (Id) ON DELETE NO ACTION ON UPDATE NO ACTION,

    CONSTRAINT CK_Greska_Id           CHECK (Id > 0),
    CONSTRAINT CK_Greska_IdProjekta   CHECK (IdProjekta > 0),
    CONSTRAINT CK_Greska_Poruka       CHECK (LEN(LTRIM(RTRIM(Poruka))) > 0),
    CONSTRAINT CK_Greska_Ozbiljnost   CHECK (Ozbiljnost BETWEEN 1 AND 5),  -- BETWEEN je inkluzivan
    CONSTRAINT CK_Greska_DatumPrijave CHECK (DatumPrijave <= CAST(GETDATE() AS DATE)),

    -- enumeracija, prekucati tacno ovako
    CONSTRAINT CK_Greska_StatusGr     CHECK (StatusGr IN (N'Отворена',
                                                          N'УПроцесуРешавања',
                                                          N'Решена',
                                                          N'Затворена'))
);
GO

-- KOMENTAR. Jedina tabela sa pravim XML tipom i jedina sa kaskadnim brisanjem.
CREATE TABLE impl.tblKomentar
(
    Id         INT           IDENTITY(1,1) NOT NULL,
    IdGreske   INT           NOT NULL,
    -- pravi XML tip, ne NVARCHAR! samo tako imamo .exist .value .query .nodes
    -- (i server usput proverava da li je dokument well-formed)
    SadrzajXML XML           NOT NULL,
    Autor      NVARCHAR(100) NOT NULL,
    DatumKom   DATETIME      NOT NULL,

    CONSTRAINT PK_Komentar PRIMARY KEY CLUSTERED (Id),

    -- SPI: GRESKA/Delete -> Cascade.
    -- komentar bez greske nema smisla, a greska bez projekta se NE brise
    -- (gore je NO ACTION) - asimetrija je namerna
    CONSTRAINT FK_Komentar_Greska FOREIGN KEY (IdGreske)
        REFERENCES impl.tblGreska (Id) ON DELETE CASCADE ON UPDATE NO ACTION,

    CONSTRAINT CK_Komentar_Id       CHECK (Id > 0),
    CONSTRAINT CK_Komentar_IdGreske CHECK (IdGreske > 0),
    CONSTRAINT CK_Komentar_Autor    CHECK (LEN(LTRIM(RTRIM(Autor))) > 0),
    CONSTRAINT CK_Komentar_DatumKom CHECK (DatumKom <= GETDATE()),
    CONSTRAINT CK_Komentar_Sadrzaj  CHECK (impl.fnsImaTekst(SadrzajXML) = 1)  -- FZ 7
);
GO

-- Ove dve nisu poslovni entiteti pa ih s pravom nema u DER-u, to je i odgovor
-- ako neko pita zasto model ima tri tabele a baza pet.

-- dnevnik za CATCH blokove (zahtev 3). ime tblErrorLog je iz dokumentacije.
CREATE TABLE impl.tblErrorLog
(
    Id         INT           IDENTITY(1,1) NOT NULL,
    DatumVreme DATETIME2(3)  NOT NULL CONSTRAINT DF_ErrorLog_Datum    DEFAULT (SYSDATETIME()),
    Korisnik   SYSNAME       NOT NULL CONSTRAINT DF_ErrorLog_Korisnik DEFAULT (SUSER_SNAME()),
    Procedura  NVARCHAR(256) NULL,      -- NZ 3: null kolone pisemo eksplicitno
    BrojGreske INT           NULL,
    Nivo       INT           NULL,
    Stanje     INT           NULL,
    Linija     INT           NULL,
    Poruka     NVARCHAR(MAX) NULL,
    CONSTRAINT PK_ErrorLog PRIMARY KEY CLUSTERED (Id)
);
GO

-- arhiva promena statusa (zahtev 13).
-- ime tblHistorijaStatusa je DOSLOVNO iz dokumentacije, zato ostaje takvo
-- iako bi na srpskom bilo "istorija" - ne diram imena koja spec propisuje.
-- !!! ova tabela je odrediste OUTPUT ... INTO klauzule, a takva tabela
-- NE SME imati: ukljucene trigere, ucesce ni na jednom kraju FK, ni CHECK.
-- zato ovde NEMA FK ka tblGreska iako logicki upucuje na nju. nije propust.
-- DEFAULT je dozvoljen pa njega koristimo.
CREATE TABLE impl.tblHistorijaStatusa
(
    Id           INT          IDENTITY(1,1) NOT NULL,
    IdGreske     INT          NOT NULL,          -- namerno bez FK, vidi gore
    StariStatus  NVARCHAR(20) NULL,              -- NULL kod prvog upisa
    NoviStatus   NVARCHAR(20) NOT NULL,
    DatumPromene DATETIME2(3) NOT NULL CONSTRAINT DF_Istorija_Datum    DEFAULT (SYSDATETIME()),
    Korisnik     SYSNAME      NOT NULL CONSTRAINT DF_Istorija_Korisnik DEFAULT (SUSER_SNAME()),
    CONSTRAINT PK_HistorijaStatusa PRIMARY KEY CLUSTERED (Id)
);
GO

-- indeksi (NZ 8 trazi prefiks idx u impl)
-- svi su nad kolonama po kojima api_ slojevi stvarno filtriraju

-- greske jednog projekta - koristi ga api_dev.GRESKE i PIVOT matrica
CREATE NONCLUSTERED INDEX idxGreskaProjekat
    ON impl.tblGreska (IdProjekta)
    INCLUDE (StatusGr, Ozbiljnost, DatumPrijave);
GO

-- lista otvorenih gresaka - najcesci ekran u obe aplikacije.
-- filtriran indeks, jer nas zanimaju samo dva statusa od cetiri
CREATE NONCLUSTERED INDEX idxGreskaStatus
    ON impl.tblGreska (StatusGr, Ozbiljnost, DatumPrijave)
    INCLUDE (IdProjekta)
    WHERE StatusGr IN (N'Отворена', N'УПроцесуРешавања');
GO

-- komentari jedne greske (ekran "detalji greske")
CREATE NONCLUSTERED INDEX idxKomentarGreska
    ON impl.tblKomentar (IdGreske, DatumKom DESC)
    INCLUDE (Autor);
GO

-- istorija jedne greske
CREATE NONCLUSTERED INDEX idxIstorijaGreska
    ON impl.tblHistorijaStatusa (IdGreske, DatumPromene DESC);
GO
