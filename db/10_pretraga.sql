USE [BugTracker];
GO

DROP PROCEDURE IF EXISTS api_dev.PretraziGreske;
DROP PROCEDURE IF EXISTS api_qa.PretraziGreske;
DROP FUNCTION  IF EXISTS spec.fnt_GreskeContains;
DROP FUNCTION  IF EXISTS spec.fnt_GreskeFreetext;
DROP FUNCTION  IF EXISTS spec.fnt_ProjektiContains;
GO

CREATE FUNCTION spec.fnt_GreskeContains (@upit NVARCHAR(1000))
RETURNS TABLE
WITH ENCRYPTION
AS
RETURN
    SELECT  g.Id, p.Naziv AS NazivProjekta, g.Poruka, g.Ozbiljnost,
            g.StatusGr, g.DatumPrijave, ct.[RANK] AS Relevantnost
    FROM    CONTAINSTABLE(impl.tblGreska, Poruka, @upit) AS ct
    JOIN    impl.tblGreska   AS g ON g.Id = ct.[KEY]
    JOIN    impl.tblProjekat AS p ON p.Id = g.IdProjekta;
GO

CREATE FUNCTION spec.fnt_GreskeFreetext (@upit NVARCHAR(1000))
RETURNS TABLE
WITH ENCRYPTION
AS
RETURN
    SELECT  g.Id, p.Naziv AS NazivProjekta, g.Poruka, g.Ozbiljnost,
            g.StatusGr, g.DatumPrijave, ft.[RANK] AS Relevantnost
    FROM    FREETEXTTABLE(impl.tblGreska, Poruka, @upit) AS ft
    JOIN    impl.tblGreska   AS g ON g.Id = ft.[KEY]
    JOIN    impl.tblProjekat AS p ON p.Id = g.IdProjekta;
GO

CREATE FUNCTION spec.fnt_ProjektiContains (@upit NVARCHAR(1000))
RETURNS TABLE
WITH ENCRYPTION
AS
RETURN
    SELECT  p.Id, p.Naziv, p.Opis, p.Verzija, ct.[RANK] AS Relevantnost
    FROM    CONTAINSTABLE(impl.tblProjekat, Opis, @upit) AS ct
    JOIN    impl.tblProjekat AS p ON p.Id = ct.[KEY];
GO

CREATE OR ALTER PROCEDURE spec.upr_PretraziGreske
    @upit  NVARCHAR(1000),
    @rezim CHAR(1) = 'C'
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @upit IS NULL OR LEN(LTRIM(RTRIM(@upit))) = 0
            THROW 50041, N'Услов претраге не сме бити празан.', 1;

        IF @rezim NOT IN ('C', 'F')
            THROW 50042, N'Режим претраге мора бити ''C'' (напредна) или ''F'' (слободна).', 1;

        IF @rezim = 'C'
            SELECT Id, NazivProjekta, Poruka, Ozbiljnost, StatusGr, DatumPrijave, Relevantnost
            FROM   spec.fnt_GreskeContains(@upit) ORDER BY Relevantnost DESC, Id;
        ELSE
            SELECT Id, NazivProjekta, Poruka, Ozbiljnost, StatusGr, DatumPrijave, Relevantnost
            FROM   spec.fnt_GreskeFreetext(@upit) ORDER BY Relevantnost DESC, Id;
    END TRY
    BEGIN CATCH
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_PretraziGreske', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE api_dev.PretraziGreske @upit NVARCHAR(1000), @rezim CHAR(1) = 'C'
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_PretraziGreske @upit, @rezim; END
GO

CREATE OR ALTER PROCEDURE api_qa.PretraziGreske @upit NVARCHAR(1000), @rezim CHAR(1) = 'C'
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_PretraziGreske @upit, @rezim; END
GO
