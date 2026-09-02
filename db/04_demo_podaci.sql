USE [BugTracker];
GO

TRUNCATE TABLE impl.tblHistorijaStatusa;
TRUNCATE TABLE impl.tblErrorLog;

DELETE FROM impl.tblKomentar;
DELETE FROM impl.tblGreska;
DELETE FROM impl.tblProjekat;
GO

SET IDENTITY_INSERT impl.tblProjekat ON;
INSERT INTO impl.tblProjekat (Id, Naziv, Opis, Verzija)
VALUES
    (1, N'WebShop',   N'Онлајн продавница за малопродају електронике', N'2.4.1'),
    (2, N'MobileApp', N'Мобилна апликација за праћење поруџбина',      N'1.8.3'),
    (3, N'ERPSystem', N'Систем за управљање пословним процесима',      N'5.2.0');
SET IDENTITY_INSERT impl.tblProjekat OFF;
GO

SET IDENTITY_INSERT impl.tblGreska ON;
INSERT INTO impl.tblGreska (Id, IdProjekta, Poruka, Ozbiljnost, DatumPrijave, StatusGr)
VALUES
    (1, 1, N'Корисник не може да се пријави након ресетовања лозинке', 1, '2025-03-10', N'Отворена'),
    (2, 1, N'Слике производа се не учитавају на Safari прегледачу',    3, '2025-03-15', N'УПроцесуРешавања'),
    (3, 2, N'Апликација се руши при учитавању GPS локације',           1, '2025-04-01', N'Отворена'),
    (4, 3, N'Извоз у PDF не ради за документе преко 100 страна',       2, '2025-02-20', N'Решена');
SET IDENTITY_INSERT impl.tblGreska OFF;
GO

SET IDENTITY_INSERT impl.tblKomentar ON;
INSERT INTO impl.tblKomentar (Id, IdGreske, SadrzajXML, Autor, DatumKom)
VALUES
    (1, 1, N'<kom><tekst>Проблем у JWT токену — истиче превремено</tekst><prioritet>Хитно</prioritet></kom>',
        N'Марко П.', '2025-03-11T09:15:00'),
    (2, 2, N'<kom><tekst>Репродуковано на Safari 17.3 и 17.4</tekst></kom>',
        N'Ана Н.', '2025-03-16T14:00:00'),

    (3, 1, N'<kom><tekst>Токен се обнавља само при поновној пријави</tekst>
              <prioritet>Хитно</prioritet>
              <okruzenje><os>Windows 11</os><pregledac>Chrome 121</pregledac></okruzenje>
              <oznake><oznaka>безбедност</oznaka><oznaka>регресија</oznaka></oznake></kom>',
        N'Марко П.', '2025-03-12T11:30:00'),
    (4, 1, N'<kom><tekst>Потврђено и на мобилној верзији сајта</tekst>
              <okruzenje><os>Android 14</os><pregledac>Chrome Mobile</pregledac></okruzenje>
              <oznake><oznaka>мобилни</oznaka></oznake></kom>',
        N'Ана Н.', '2025-03-13T08:45:00'),
    (5, 2, N'<kom><tekst>Слике се учитавају тек после освежавања стране</tekst>
              <prioritet>Средње</prioritet>
              <okruzenje><os>macOS 14</os><pregledac>Safari 17.4</pregledac></okruzenje>
              <oznake><oznaka>кеш</oznaka><oznaka>регресија</oznaka></oznake></kom>',
        N'Марко П.', '2025-03-17T16:20:00'),
    (6, 3, N'<kom><tekst>Пад се дешава само када је GPS искључен</tekst>
              <prioritet>Хитно</prioritet>
              <okruzenje><os>Android 13</os><pregledac>-</pregledac></okruzenje>
              <oznake><oznaka>пад</oznaka></oznake></kom>',
        N'Ана Н.', '2025-04-02T09:05:00'),
    (7, 3, N'<kom><tekst>Репродуковано на три различита уређаја</tekst>
              <okruzenje><os>Android 14</os><pregledac>-</pregledac></okruzenje>
              <oznake><oznaka>пад</oznaka><oznaka>потврђено</oznaka></oznake></kom>',
        N'Јована С.', '2025-04-03T13:10:00');
SET IDENTITY_INSERT impl.tblKomentar OFF;
GO

DBCC CHECKIDENT ('impl.tblProjekat', RESEED, 3) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('impl.tblGreska',   RESEED, 4) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('impl.tblKomentar', RESEED, 7) WITH NO_INFOMSGS;
GO

PRINT N'--- V1: broj redova mora biti 3 / 4 / 7 ---';
SELECT N'ПРОЈЕКАТ' AS Tabela, COUNT(*) AS Uneto, 3 AS Ocekivano FROM impl.tblProjekat
UNION ALL SELECT N'ГРЕШКА',   COUNT(*), 4 FROM impl.tblGreska
UNION ALL SELECT N'КОМЕНТАР', COUNT(*), 7 FROM impl.tblKomentar;

PRINT N'--- V2: Id-evi moraju biti tacno kao u tabelama 1-3 dokumentacije ---';
SELECT N'ПРОЈЕКАТ' AS Tabela, MIN(Id) AS Najmanji, MAX(Id) AS Najveci FROM impl.tblProjekat
UNION ALL SELECT N'ГРЕШКА', MIN(Id), MAX(Id) FROM impl.tblGreska;

PRINT N'--- V3: strani kljucevi vezuju prave projekte ---';
SELECT g.Id, p.Naziv AS Projekat, g.Ozbiljnost, g.StatusGr, g.DatumPrijave
FROM   impl.tblGreska g JOIN impl.tblProjekat p ON p.Id = g.IdProjekta ORDER BY g.Id;

PRINT N'--- V4: XML je ispravno smesten i cita se ---';
SELECT k.Id, k.Autor, k.SadrzajXML.value('(//tekst)[1]','NVARCHAR(120)') AS Tekst
FROM   impl.tblKomentar k ORDER BY k.Id;

PRINT N'--- V5: nema sirocadi (oba broja moraju biti 0) ---';
SELECT (SELECT COUNT(*) FROM impl.tblGreska g
        WHERE NOT EXISTS (SELECT 1 FROM impl.tblProjekat p WHERE p.Id = g.IdProjekta)) AS GreskeBezProjekta,
       (SELECT COUNT(*) FROM impl.tblKomentar k
        WHERE NOT EXISTS (SELECT 1 FROM impl.tblGreska g WHERE g.Id = k.IdGreske))     AS KomentariBezGreske;

PRINT N'--- V6: cirilica se sortira po srpskoj azbuci (О, Р, У) - dokaz kolacije ---';
SELECT DISTINCT StatusGr FROM impl.tblGreska ORDER BY StatusGr;

PRINT N'--- V7: svaki status iz podataka mora biti u dozvoljenoj listi ---';
SELECT g.StatusGr, COUNT(*) AS Broj,
       CASE WHEN g.StatusGr IN (N'Отворена', N'УПроцесуРешавања', N'Решена', N'Затворена')
            THEN N'OK' ELSE N'NEDOZVOLJEN' END AS Provera
FROM   impl.tblGreska g GROUP BY g.StatusGr;
GO
