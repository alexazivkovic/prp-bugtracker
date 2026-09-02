USE [BugTracker];
GO
SET NOCOUNT ON;

PRINT N'== referencijalne akcije - dokaz SPI iz tabele 6 ==';
SELECT fk.name AS StraniKljuc, OBJECT_NAME(fk.parent_object_id) AS Iz,
       OBJECT_NAME(fk.referenced_object_id) AS Ka,
       fk.delete_referential_action_desc AS NaBrisanje
FROM sys.foreign_keys fk WHERE SCHEMA_NAME(fk.schema_id) = N'impl';

PRINT N'== indeksi sloja impl (NZ 8 trazi prefiks idx) ==';
SELECT i.name AS Indeks, OBJECT_NAME(i.object_id) AS Tabela, i.type_desc, i.has_filter
FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
WHERE SCHEMA_NAME(t.schema_id) = N'impl' AND i.name LIKE 'idx%';

PRINT N'== negativni testovi - svaki unos MORA biti odbijen ==';
DECLARE @r TABLE (RB INT IDENTITY, Pokusaj NVARCHAR(46), Ishod NVARCHAR(60));

BEGIN TRY INSERT INTO impl.tblGreska (IdProjekta,Poruka,Ozbiljnost,DatumPrijave,StatusGr)
          VALUES (1,N'Тест',9,'2025-01-01',N'Отворена');
          INSERT INTO @r VALUES (N'Ozbiljnost = 9', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Ozbiljnost = 9', N'odbijeno'); END CATCH

BEGIN TRY INSERT INTO impl.tblGreska (IdProjekta,Poruka,Ozbiljnost,DatumPrijave,StatusGr)
          VALUES (1,N'Тест',2,'2025-01-01',N'НепостојећиСтатус');
          INSERT INTO @r VALUES (N'Status van enumeracije', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Status van enumeracije', N'odbijeno'); END CATCH

BEGIN TRY INSERT INTO impl.tblProjekat (Naziv,Opis,Verzija) VALUES (N'WebShop',N'Дупликат',N'1.0');
          INSERT INTO @r VALUES (N'Duplikat naziva (UNIQUE)', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Duplikat naziva (UNIQUE)', N'odbijeno'); END CATCH

BEGIN TRY INSERT INTO impl.tblProjekat (Naziv,Opis,Verzija) VALUES (N'   ',N'Опис',N'1.0');
          INSERT INTO @r VALUES (N'Naziv od samih razmaka', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Naziv od samih razmaka', N'odbijeno'); END CATCH

BEGIN TRY INSERT INTO impl.tblKomentar (IdGreske,SadrzajXML,Autor,DatumKom)
          VALUES (1,N'<kom><opis>нема tekst</opis></kom>',N'Тест','2025-05-01T10:00:00');
          INSERT INTO @r VALUES (N'XML bez <tekst>', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'XML bez <tekst>', N'odbijeno'); END CATCH

BEGIN TRY DELETE FROM impl.tblProjekat WHERE Id = 1;
          INSERT INTO @r VALUES (N'Brisanje projekta sa greskama', N'PROSLO - greska!');
END TRY BEGIN CATCH INSERT INTO @r VALUES (N'Brisanje projekta sa greskama', N'odbijeno (Restrict)'); END CATCH

SELECT * FROM @r ORDER BY RB;

PRINT N'== CASCADE: brisanje greske brise i njene komentare ==';
BEGIN TRAN;
    DECLARE @g INT;
    EXEC spec.upr_PrijaviGresku 1, N'Привремена грешка за тест каскаде', 4, NULL, N'Отворена', @g OUTPUT;
    DECLARE @k INT;
    EXEC spec.upr_DodajKomentar @idGreske=@g, @autor=N'Тест', @tekst=N'Привремени коментар', @idKomentar=@k OUTPUT;
    SELECT N'pre brisanja' AS Faza, (SELECT COUNT(*) FROM impl.tblKomentar WHERE IdGreske=@g) AS BrojKomentara;
    DELETE FROM impl.tblGreska WHERE Id = @g;
    SELECT N'posle brisanja' AS Faza, (SELECT COUNT(*) FROM impl.tblKomentar WHERE IdGreske=@g) AS BrojKomentara;
ROLLBACK;

PRINT N'== triger trgAutoStatusResen: komentar sa <resenje> zatvara gresku ==';
BEGIN TRAN;
    SELECT N'pre' AS Faza, StatusGr FROM impl.tblGreska WHERE Id = 3;
    DECLARE @k2 INT;
    EXEC spec.upr_DodajKomentar @idGreske=3, @autor=N'Тест', @tekst=N'Поправљено',
         @resenje=N'Замењен GPS провајдер', @idKomentar=@k2 OUTPUT;
    SELECT N'posle' AS Faza, StatusGr FROM impl.tblGreska WHERE Id = 3;
ROLLBACK;
GO
