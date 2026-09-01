-- Full-Text katalog i indeksi, infrastruktura za zahteve 6 i 7.
-- Ovo je zamena za LIKE '%rec%'. LIKE ne moze da koristi indeks kad izraz
-- pocinje sa % pa procita celu tabelu, a uz to ne zna granice reci - '%лозинк%'
-- bi nasao i 'безлозинкаст'. Full-Text umesto toga gradi invertovani indeks,
-- rec pa spisak redova u kojima se javlja.

USE [BugTracker];
GO

-- indeksi se rusе PRE kataloga, katalog ne moze da nestane dok ih ima.
-- DROP FULLTEXT INDEX nema IF EXISTS pa proveravamo rucno
IF EXISTS (SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID(N'impl.tblGreska'))
    DROP FULLTEXT INDEX ON impl.tblGreska;
IF EXISTS (SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID(N'impl.tblProjekat'))
    DROP FULLTEXT INDEX ON impl.tblProjekat;
IF EXISTS (SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID(N'impl.tblKomentar'))
    DROP FULLTEXT INDEX ON impl.tblKomentar;
GO

IF EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = N'ftBugTracker')
    DROP FULLTEXT CATALOG ftBugTracker;
GO

-- ACCENT_SENSITIVITY ON da se poklopi sa AS delom kolacije baze
CREATE FULLTEXT CATALOG ftBugTracker WITH ACCENT_SENSITIVITY = ON AS DEFAULT;
GO

-- LANGUAGE 3098 = Serbian (Cyrillic). proverio: sys.fulltext_languages
-- to nije formalnost - word breaker sece tekst na reci, stemmer nalazi
-- oblike iste reci. sa podrazumevanim engleskim (1033) cirilica bi se
-- sekla samo po razmacima.
-- KEY INDEX mora biti jedinstven, NOT NULL i nad JEDNOM kolonom - PK je to.
-- CHANGE_TRACKING AUTO -> server sam osvezava indeks pri svakoj izmeni.
CREATE FULLTEXT INDEX ON impl.tblGreska (Poruka LANGUAGE 3098)
    KEY INDEX PK_Greska ON ftBugTracker WITH CHANGE_TRACKING = AUTO;
GO

CREATE FULLTEXT INDEX ON impl.tblProjekat (Opis LANGUAGE 3098)
    KEY INDEX PK_Projekat ON ftBugTracker WITH CHANGE_TRACKING = AUTO;
GO

-- i XML kolona sme pod Full-Text. server indeksira SADRZAJ elemenata a
-- tagove preskace, pa CONTAINS nalazi rec bilo gde u dokumentu -
-- u <tekst>, u <oznaka>, u <os>... a nodes() posle kaze u kom tacno.
CREATE FULLTEXT INDEX ON impl.tblKomentar (SadrzajXML LANGUAGE 3098)
    KEY INDEX PK_Komentar ON ftBugTracker WITH CHANGE_TRACKING = AUTO;
GO

-- popunjavanje je ASINHRONO - CREATE se vrati odmah a indeksiranje ide u
-- pozadini. bez ovog cekanja prvi CONTAINS vrati prazno i covek pomisli
-- da nista ne radi. PopulateStatus 0 = miruje.
DECLARE @i INT = 0;
WHILE FULLTEXTCATALOGPROPERTY(N'ftBugTracker', 'PopulateStatus') <> 0 AND @i < 90
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @i += 1;
END
GO
