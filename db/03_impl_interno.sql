USE [BugTracker];
GO

CREATE OR ALTER VIEW impl.vwKomentarDetalji
AS
    SELECT  k.Id        AS IdKomentara,
            k.IdGreske,
            k.Autor,
            k.DatumKom,
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
    INSERT INTO impl.tblErrorLog (Procedura, BrojGreske, Nivo, Stanje, Linija, Poruka)
    VALUES (@procedura, @brojGreske, @nivo, @stanje, @linija, @poruka);
END
GO

CREATE OR ALTER TRIGGER impl.trgAutoStatusResen
ON impl.tblKomentar
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @novi TABLE (IdGreske INT NOT NULL, Sadrzaj XML NOT NULL);

    INSERT INTO @novi (IdGreske, Sadrzaj)
    SELECT i.IdGreske, i.SadrzajXML FROM inserted AS i;

    IF NOT EXISTS (SELECT 1 FROM @novi AS n WHERE n.Sadrzaj.exist('//resenje') = 1)
        RETURN;

    UPDATE  g
    SET     g.StatusGr = N'Решена'
    FROM    impl.tblGreska AS g
    WHERE   g.StatusGr NOT IN (N'Решена', N'Затворена')
      AND   EXISTS (SELECT 1 FROM @novi AS n
                    WHERE n.IdGreske = g.Id AND n.Sadrzaj.exist('//resenje') = 1);
END
GO
