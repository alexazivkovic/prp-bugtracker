-- PRP projekat 10, BugTracker.
-- Ovo je prva skripta i sve ostalo zavisi od nje - pravi bazu sa cirilickom
-- kolacijom, cetiri seme koje cine slojeve, i naloge kojima ce se aplikacije
-- prijavljivati. Zahtev 1 iz tabele, a usput i NZ 1, 5, 6 i 7.

USE master;
GO

-- bez ove kolacije nema smisla ici dalje - cirilica bi se sortirala po
-- Unicode kodovima umesto po azbuci, pa bi ORDER BY bio besmislen
IF NOT EXISTS (SELECT 1 FROM sys.fn_helpcollations()
               WHERE name = N'Serbian_Cyrillic_100_CI_AS')
    THROW 50001, N'Колација Serbian_Cyrillic_100_CI_AS није доступна на овој инстанци.', 1;
GO

-- SINGLE_USER + ROLLBACK IMMEDIATE izbacuje sve ostale sesije,
-- inace DROP puca ako je aplikacija jos zakacena
IF DB_ID(N'BugTracker') IS NOT NULL
BEGIN
    ALTER DATABASE [BugTracker] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [BugTracker];
END
GO

-- CI = ne razlikuje mala/velika, AS = razlikuje akcente
CREATE DATABASE [BugTracker] COLLATE Serbian_Cyrillic_100_CI_AS;
GO

ALTER DATABASE [BugTracker] SET RECOVERY SIMPLE;   -- razvojna baza, log ne treba da raste
GO

USE [BugTracker];
GO

-- Cetiri seme su cetiri sloja. U impl idu tabele, trigeri, indeksi i interne
-- procedure i to niko spolja ne vidi. U spec idu operacije ATP-a, sifrovane.
-- api_dev i api_qa su interfejsi za dve aplikacije. Smer je uvek api_ pa spec
-- pa impl, nikad obrnuto.
-- AUTHORIZATION dbo mora da stoji. Isti vlasnik svih sema znaci ownership
-- chaining, tj. kad api_ pogled cita impl tabelu server uopste ne proverava
-- dozvole nad tom tabelom. Bez toga bih morao da dam prava nad impl i cela
-- prica o enkapsulaciji bi pala u vodu.
CREATE SCHEMA impl    AUTHORIZATION dbo;
GO
CREATE SCHEMA spec    AUTHORIZATION dbo;
GO
CREATE SCHEMA api_dev AUTHORIZATION dbo;
GO
CREATE SCHEMA api_qa  AUTHORIZATION dbo;
GO

-- logini i korisnici
-- namerno NEMAJU nikakva prava nad podacima - samo se povezu.
-- prava dobijaju tek kroz sp_setapprole (vidi 12_dozvole.sql)
USE master;
GO
IF SUSER_ID(N'AppLoginDEV') IS NOT NULL DROP LOGIN AppLoginDEV;
IF SUSER_ID(N'AppLoginQA')  IS NOT NULL DROP LOGIN AppLoginQA;
GO

-- CHECK_POLICY OFF jer pod Linuxom nema Windows politike lozinki
CREATE LOGIN AppLoginDEV WITH PASSWORD = N'Prp#Dev2026!', CHECK_POLICY = OFF, DEFAULT_DATABASE = [BugTracker];
CREATE LOGIN AppLoginQA  WITH PASSWORD = N'Prp#Qa2026!',  CHECK_POLICY = OFF, DEFAULT_DATABASE = [BugTracker];
GO

USE [BugTracker];
GO
CREATE USER AppUserDEV FOR LOGIN AppLoginDEV WITH DEFAULT_SCHEMA = api_dev;
CREATE USER AppUserQA  FOR LOGIN AppLoginQA  WITH DEFAULT_SCHEMA = api_qa;
GO

-- aplikaciona uloga nema svog korisnika. aktivira se iz koda:
--    EXEC sp_setapprole 'DataProviderDEV', 'lozinka'
-- posle toga sesija GUBI svoja prava i dobija samo ova.
CREATE APPLICATION ROLE DataProviderDEV WITH PASSWORD = N'Prp#RoleDev2026!', DEFAULT_SCHEMA = api_dev;
CREATE APPLICATION ROLE DataProviderQA  WITH PASSWORD = N'Prp#RoleQa2026!',  DEFAULT_SCHEMA = api_qa;
GO
