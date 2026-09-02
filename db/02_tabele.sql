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

CREATE FUNCTION impl.fnsImaTekst (@sadrzaj XML)
RETURNS BIT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE WHEN @sadrzaj.exist('//tekst') = 1 THEN 1 ELSE 0 END;
END
GO

CREATE TABLE impl.tblProjekat
(
    Id      INT           IDENTITY(1,1) NOT NULL,
    Naziv   NVARCHAR(200) NOT NULL,
    Opis    NVARCHAR(MAX) NOT NULL,
    Verzija NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_Projekat         PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT UQ_Projekat_Naziv   UNIQUE (Naziv),
    CONSTRAINT CK_Projekat_Id      CHECK (Id > 0),

    CONSTRAINT CK_Projekat_Naziv   CHECK (LEN(LTRIM(RTRIM(Naziv)))   > 0),
    CONSTRAINT CK_Projekat_Opis    CHECK (LEN(LTRIM(RTRIM(Opis)))    > 0),
    CONSTRAINT CK_Projekat_Verzija CHECK (LEN(LTRIM(RTRIM(Verzija))) > 0)
);
GO

CREATE TABLE impl.tblGreska
(
    Id           INT           IDENTITY(1,1) NOT NULL,
    IdProjekta   INT           NOT NULL,
    Poruka       NVARCHAR(MAX) NOT NULL,
    Ozbiljnost   INT           NOT NULL,
    DatumPrijave DATE          NOT NULL,
    StatusGr     NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_Greska PRIMARY KEY CLUSTERED (Id),

    CONSTRAINT FK_Greska_Projekat FOREIGN KEY (IdProjekta)
        REFERENCES impl.tblProjekat (Id) ON DELETE NO ACTION ON UPDATE NO ACTION,

    CONSTRAINT CK_Greska_Id           CHECK (Id > 0),
    CONSTRAINT CK_Greska_IdProjekta   CHECK (IdProjekta > 0),
    CONSTRAINT CK_Greska_Poruka       CHECK (LEN(LTRIM(RTRIM(Poruka))) > 0),
    CONSTRAINT CK_Greska_Ozbiljnost   CHECK (Ozbiljnost BETWEEN 1 AND 5),
    CONSTRAINT CK_Greska_DatumPrijave CHECK (DatumPrijave <= CAST(GETDATE() AS DATE)),

    CONSTRAINT CK_Greska_StatusGr     CHECK (StatusGr IN (N'Отворена',
                                                          N'УПроцесуРешавања',
                                                          N'Решена',
                                                          N'Затворена'))
);
GO

CREATE TABLE impl.tblKomentar
(
    Id         INT           IDENTITY(1,1) NOT NULL,
    IdGreske   INT           NOT NULL,
    SadrzajXML XML           NOT NULL,
    Autor      NVARCHAR(100) NOT NULL,
    DatumKom   DATETIME      NOT NULL,

    CONSTRAINT PK_Komentar PRIMARY KEY CLUSTERED (Id),

    CONSTRAINT FK_Komentar_Greska FOREIGN KEY (IdGreske)
        REFERENCES impl.tblGreska (Id) ON DELETE CASCADE ON UPDATE NO ACTION,

    CONSTRAINT CK_Komentar_Id       CHECK (Id > 0),
    CONSTRAINT CK_Komentar_IdGreske CHECK (IdGreske > 0),
    CONSTRAINT CK_Komentar_Autor    CHECK (LEN(LTRIM(RTRIM(Autor))) > 0),
    CONSTRAINT CK_Komentar_DatumKom CHECK (DatumKom <= GETDATE()),
    CONSTRAINT CK_Komentar_Sadrzaj  CHECK (impl.fnsImaTekst(SadrzajXML) = 1)
);
GO

CREATE TABLE impl.tblErrorLog
(
    Id         INT           IDENTITY(1,1) NOT NULL,
    DatumVreme DATETIME2(3)  NOT NULL CONSTRAINT DF_ErrorLog_Datum    DEFAULT (SYSDATETIME()),
    Korisnik   SYSNAME       NOT NULL CONSTRAINT DF_ErrorLog_Korisnik DEFAULT (SUSER_SNAME()),
    Procedura  NVARCHAR(256) NULL,
    BrojGreske INT           NULL,
    Nivo       INT           NULL,
    Stanje     INT           NULL,
    Linija     INT           NULL,
    Poruka     NVARCHAR(MAX) NULL,
    CONSTRAINT PK_ErrorLog PRIMARY KEY CLUSTERED (Id)
);
GO

CREATE TABLE impl.tblHistorijaStatusa
(
    Id           INT          IDENTITY(1,1) NOT NULL,
    IdGreske     INT          NOT NULL,
    StariStatus  NVARCHAR(20) NULL,
    NoviStatus   NVARCHAR(20) NOT NULL,
    DatumPromene DATETIME2(3) NOT NULL CONSTRAINT DF_Istorija_Datum    DEFAULT (SYSDATETIME()),
    Korisnik     SYSNAME      NOT NULL CONSTRAINT DF_Istorija_Korisnik DEFAULT (SUSER_SNAME()),
    CONSTRAINT PK_HistorijaStatusa PRIMARY KEY CLUSTERED (Id)
);
GO

CREATE NONCLUSTERED INDEX idxGreskaProjekat
    ON impl.tblGreska (IdProjekta)
    INCLUDE (StatusGr, Ozbiljnost, DatumPrijave);
GO

CREATE NONCLUSTERED INDEX idxGreskaStatus
    ON impl.tblGreska (StatusGr, Ozbiljnost, DatumPrijave)
    INCLUDE (IdProjekta)
    WHERE StatusGr IN (N'Отворена', N'УПроцесуРешавања');
GO

CREATE NONCLUSTERED INDEX idxKomentarGreska
    ON impl.tblKomentar (IdGreske, DatumKom DESC)
    INCLUDE (Autor);
GO

CREATE NONCLUSTERED INDEX idxIstorijaGreska
    ON impl.tblHistorijaStatusa (IdGreske, DatumPromene DESC);
GO
