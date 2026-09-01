-- Tri procedure koje dokumentacija imenuje u zahtevu 3: upr_PrijaviGresku,
-- upr_DodajKomentar i upr_PromeniStatus. Iza njih stoje ekrani "Prijavi
-- gresku", "Dodaj komentar" i "Promeni status" u DEV aplikaciji.
-- Sve tri idu istim redom: prvo NOCOUNT i XACT_ABORT, pa TRY sa validacijama
-- koje bacaju izuzetak sa porukom iz dokumentacije, pa transakcija, pa CATCH
-- koji ponisti sta treba, upise gresku u dnevnik i prosledi je dalje.
-- Neko ce pitati zasto proveravam isto sto vec proverava CHECK. Zato sto CHECK
-- vazi bez obzira kojim putem podaci stizu, ali daje tehnicku poruku na
-- engleskom; procedura vraca poslovnu poruku koju aplikacija moze da prikaze
-- korisniku. Treba mi i jedno i drugo.

USE [BugTracker];
GO

-- fns_ValidanStatus je SCHEMABINDING i drzi fnt_DozvoljeniStatusi, pa bi
-- CREATE OR ALTER pukao (Msg 3729). rusi se obrnutim redom zavisnosti.
DROP FUNCTION IF EXISTS spec.fns_ValidanStatus;
DROP FUNCTION IF EXISTS spec.fnt_DozvoljeniStatusi;
GO

-- statusi. jedno mesto istine - koristi ih i validacija u procedurama i
-- padajuca lista u aplikaciji. Redosled je LOGICKI (otvorena->zatvorena),
-- ne azbucni, jer se tako prikazuje u meniju.
-- inline tabelarna funkcija: telo je jedan SELECT, bez BEGIN/END.
-- optimizator je ulepi u upit koji je zove, za razliku od multistatement
-- varijante koja mu je crna kutija.
CREATE FUNCTION spec.fnt_DozvoljeniStatusi ()
RETURNS TABLE
WITH ENCRYPTION, SCHEMABINDING
AS
RETURN
    SELECT N'Отворена'          AS StatusGr, 1 AS Redosled
    UNION ALL SELECT N'УПроцесуРешавања', 2
    UNION ALL SELECT N'Решена',           3
    UNION ALL SELECT N'Затворена',        4;
GO

CREATE FUNCTION spec.fns_ValidanStatus (@status NVARCHAR(20))
RETURNS BIT
WITH ENCRYPTION, SCHEMABINDING
AS
BEGIN
    -- ELSE 0 je bitan: bez njega bi CASE vratio NULL, a poredjenje
    -- NULL = 0 u proceduri daje UNKNOWN pa bi provera propustila los status
    RETURN CASE WHEN EXISTS (SELECT 1 FROM spec.fnt_DozvoljeniStatusi()
                             WHERE StatusGr = @status)
                THEN 1 ELSE 0 END;
END
GO

-- prijava nove greske. ekran "Prijavi gresku" u DEV aplikaciji.
CREATE OR ALTER PROCEDURE spec.upr_PrijaviGresku
    @idProjekta   INT,
    @poruka       NVARCHAR(MAX),
    @ozbiljnost   INT,
    @datumPrijave DATE         = NULL,          -- NULL -> danas
    @statusGr     NVARCHAR(20) = N'Отворена',   -- nova greska je uvek otvorena
    @idGreske     INT          = NULL OUTPUT    -- aplikacija odmah otvori detalje
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    -- bez XACT_ABORT neke greske samo preskoce naredbu i idu dalje ->
    -- baza ostane u polovicnom stanju
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @datumPrijave = ISNULL(@datumPrijave, CAST(GETDATE() AS DATE));

        -- SPI tabela 6: GRESKA/Insert -> Restrict
        IF NOT EXISTS (SELECT 1 FROM impl.tblProjekat WHERE Id = @idProjekta)
            THROW 50010, N'Пројекат не постоји. Није могуће убацити ГРЕШКУ.', 1;

        -- VPI tabela 8
        IF @poruka IS NULL OR LEN(LTRIM(RTRIM(@poruka))) = 0
            THROW 50011, N'Текст грешке не сме бити празан.', 1;

        IF @ozbiljnost IS NULL OR @ozbiljnost NOT BETWEEN 1 AND 5
            THROW 50012, N'Озбиљност мора бити вредност од 1 до 5.', 1;

        IF spec.fns_ValidanStatus(@statusGr) = 0
            THROW 50013, N'Статус мора бити у листи дозвољених вредности.', 1;

        IF @datumPrijave > CAST(GETDATE() AS DATE)
            THROW 50014, N'Датум пријаве не сме бити у будућности.', 1;

        BEGIN TRANSACTION;

            INSERT INTO impl.tblGreska (IdProjekta, Poruka, Ozbiljnost, DatumPrijave, StatusGr)
            VALUES (@idProjekta, @poruka, @ozbiljnost, @datumPrijave, @statusGr);

            -- SCOPE_IDENTITY a ne @@IDENTITY! @@IDENTITY bi vratio vrednost
            -- koju je generisao neki triger, iz drugog opsega
            SET @idGreske = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- XACT_STATE: 1 ok, 0 nema transakcije, -1 doomed.
        -- rollback IDE PRE logovanja, inace bi i upis u dnevnik bio ponisten
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        -- parametar procedure sme biti samo konstanta ili promenljiva,
        -- NIKAD poziv funkcije -> Msg 8114. zato prvo u promenljive.
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();

        EXEC impl.uprLogujGresku N'spec.upr_PrijaviGresku', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;

        THROW;   -- bez argumenata = prosledi ORIGINALNU gresku pozivaocu
    END CATCH
END
GO

-- dodavanje komentara. ekran "Dodaj komentar" u DEV aplikaciji.
-- aplikacija salje POLJA FORME, ne XML - baza sama sklapa dokument.
-- tako je <tekst> garantovano prisutan (CHECK ga trazi), a escapovanje
-- specijalnih znakova radi FOR XML umesto nas.
-- polje "resenje" u formi je ono sto okida trgAutoStatusResen i automatski
-- zatvara gresku.
CREATE OR ALTER PROCEDURE spec.upr_DodajKomentar
    @idGreske   INT,
    @autor      NVARCHAR(100),
    @tekst      NVARCHAR(MAX),
    @prioritet  NVARCHAR(50)  = NULL,
    @os         NVARCHAR(60)  = NULL,
    @pregledac  NVARCHAR(60)  = NULL,
    @oznake     NVARCHAR(400) = NULL,   -- iz forme, razdvojene zarezom
    @resenje    NVARCHAR(MAX) = NULL,   -- ako je popunjeno -> greska se zatvara
    @datumKom   DATETIME      = NULL,
    @idKomentar INT           = NULL OUTPUT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @datumKom = ISNULL(@datumKom, GETDATE());

        -- SPI tabela 6: KOMENTAR/Insert -> Restrict
        IF NOT EXISTS (SELECT 1 FROM impl.tblGreska WHERE Id = @idGreske)
            THROW 50020, N'Не постоји наведена грешка. Коментар не може бити унет.', 1;

        IF @tekst IS NULL OR LEN(LTRIM(RTRIM(@tekst))) = 0
            THROW 50021, N'XML коментара мора садржати елемент <tekst>.', 1;

        IF @autor IS NULL OR LEN(LTRIM(RTRIM(@autor))) = 0
            THROW 50022, N'Аутор коментара не сме бити празан.', 1;

        IF @datumKom > GETDATE()
            THROW 50023, N'Датум коментара не сме бити у будућности.', 1;

        -- sklapanje XML-a.
        -- FOR XML PATH izostavlja NULL kolone, pa se neobavezni elementi
        -- prosto ne pojave. WHERE bez FROM je dozvoljen i sluzi da se ceo
        -- <okruzenje> preskoci kad korisnik nije popunio ta polja.
        DECLARE @xml XML =
        (
            SELECT  LTRIM(RTRIM(@tekst))     AS 'tekst',
                    NULLIF(LTRIM(RTRIM(ISNULL(@prioritet, N''))), N'') AS 'prioritet',
                    (SELECT @os AS 'os', @pregledac AS 'pregledac'
                     WHERE  @os IS NOT NULL OR @pregledac IS NOT NULL
                     FOR XML PATH('okruzenje'), TYPE),
                    (SELECT LTRIM(RTRIM(s.value)) AS 'oznaka'
                     FROM   STRING_SPLIT(ISNULL(@oznake, N''), ',') AS s
                     WHERE  LEN(LTRIM(RTRIM(s.value))) > 0
                     FOR XML PATH(''), ROOT('oznake'), TYPE),
                    NULLIF(LTRIM(RTRIM(ISNULL(@resenje, N''))), N'') AS 'resenje'
            FOR XML PATH('kom'), TYPE
        );

        -- pojas i tregeri: isti omotac koji koristi i CHECK ogranicenje
        IF impl.fnsImaTekst(@xml) = 0
            THROW 50021, N'XML коментара мора садржати елемент <tekst>.', 1;

        BEGIN TRANSACTION;

            -- ovaj INSERT okida trgAutoStatusResen ako XML nosi <resenje>
            INSERT INTO impl.tblKomentar (IdGreske, SadrzajXML, Autor, DatumKom)
            VALUES (@idGreske, @xml, @autor, @datumKom);

            SET @idKomentar = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_DodajKomentar', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
GO

-- promena statusa. ekran "Promeni status" u DEV aplikaciji.
-- OUTPUT klauzula (zahtev 13) arhivira promenu u ISTOM DML koraku -
-- nije triger, vidi se u samoj naredbi da se arhivira.
CREATE OR ALTER PROCEDURE spec.upr_PromeniStatus
    @idGreske   INT,
    @noviStatus NVARCHAR(20)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM impl.tblGreska WHERE Id = @idGreske)
            THROW 50030, N'Не постоји наведена грешка. Статус не може бити промењен.', 1;

        IF spec.fns_ValidanStatus(@noviStatus) = 0
            THROW 50031, N'Статус мора бити у листи дозвољених вредности.', 1;

        BEGIN TRANSACTION;

            -- NAPOMENA: skripta 09 (zahtev 13) ovaj UPDATE prosiruje OUTPUT
            -- klauzulom koja promenu arhivira. zaglavlje procedure se pri tom
            -- NE menja, pa ni api_dev ni C# aplikacija ne osete razliku.
            UPDATE  impl.tblGreska
            SET     StatusGr = @noviStatus
            WHERE   Id = @idGreske
              AND   StatusGr <> @noviStatus;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @eBroj INT = ERROR_NUMBER(), @eNivo INT = ERROR_SEVERITY(),
                @eStanje INT = ERROR_STATE(), @eLinija INT = ERROR_LINE(),
                @ePoruka NVARCHAR(MAX) = ERROR_MESSAGE();
        EXEC impl.uprLogujGresku N'spec.upr_PromeniStatus', @eBroj, @eNivo, @eStanje, @eLinija, @ePoruka;
        THROW;
    END CATCH
END
GO

-- api_dev omotaci za ove tri operacije.
-- nemaju nijednu proveru - samo prosledjuju. to je poenta sloja: kad se
-- spec promeni, ovde i u aplikaciji se ne dira nista.
-- NZ 8: PascalCase procedure, camelCase parametri.

CREATE OR ALTER PROCEDURE api_dev.PrijaviGresku
    @idProjekta INT, @poruka NVARCHAR(MAX), @ozbiljnost INT,
    @datumPrijave DATE = NULL, @statusGr NVARCHAR(20) = N'Отворена',
    @idGreske INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- rec OUTPUT mora i ovde u pozivu, ne samo u definiciji
    EXEC spec.upr_PrijaviGresku @idProjekta, @poruka, @ozbiljnost,
         @datumPrijave, @statusGr, @idGreske OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE api_dev.DodajKomentar
    @idGreske INT, @autor NVARCHAR(100), @tekst NVARCHAR(MAX),
    @prioritet NVARCHAR(50) = NULL, @os NVARCHAR(60) = NULL,
    @pregledac NVARCHAR(60) = NULL, @oznake NVARCHAR(400) = NULL,
    @resenje NVARCHAR(MAX) = NULL, @datumKom DATETIME = NULL,
    @idKomentar INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC spec.upr_DodajKomentar @idGreske, @autor, @tekst, @prioritet, @os,
         @pregledac, @oznake, @resenje, @datumKom, @idKomentar OUTPUT;
END
GO

CREATE OR ALTER PROCEDURE api_dev.PromeniStatus @idGreske INT, @noviStatus NVARCHAR(20)
AS BEGIN SET NOCOUNT ON; EXEC spec.upr_PromeniStatus @idGreske, @noviStatus; END
GO

-- sinonim - treca kutija iz dijagrama DB API sloja ("stabilna imena").
-- aplikacije odavde pune padajucu listu statusa
DROP SYNONYM IF EXISTS api_dev.DOZVOLJENI_STATUSI;
DROP SYNONYM IF EXISTS api_qa.DOZVOLJENI_STATUSI;
GO
CREATE SYNONYM api_dev.DOZVOLJENI_STATUSI FOR spec.fnt_DozvoljeniStatusi;
CREATE SYNONYM api_qa.DOZVOLJENI_STATUSI  FOR spec.fnt_DozvoljeniStatusi;
GO
