-- Dozvole i izolacija slojeva, zahtev 5. Princip je minimalna privilegija:
-- uloga dobije tacno ono sto joj treba za svoje ekrane, i izricito joj se
-- oduzme sve ostalo, pa i tudja API sema.

USE [BugTracker];
GO

-- GRANT na nivou SEME vazi i za objekte koji tek budu napravljeni, pa ne
-- moramo da diramo ovu skriptu svaki put kad dodamo pogled.
-- VIEW DEFINITION = sme da vidi DA objekat postoji (spisak u alatu),
-- ne daje pravo citanja podataka.
GRANT SELECT, EXECUTE, VIEW DEFINITION ON SCHEMA::api_dev TO DataProviderDEV;
GRANT SELECT, EXECUTE, VIEW DEFINITION ON SCHEMA::api_qa  TO DataProviderQA;
GO

-- DENY je jaci od GRANT-a. uloge ionako nemaju GRANT nad impl/spec, ali
-- eksplicitan DENY cini nameru nedvosmislenom i cuva od kasnijih gresaka.
-- treci red: dva API-ja se medjusobno NE vide.
DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::impl    TO DataProviderDEV;
DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::spec    TO DataProviderDEV;
DENY SELECT, EXECUTE                         ON SCHEMA::api_qa  TO DataProviderDEV;

DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::impl    TO DataProviderQA;
DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::spec    TO DataProviderQA;
DENY SELECT, EXECUTE                         ON SCHEMA::api_dev TO DataProviderQA;
GO

-- logini smeju SAMO da se poveze. odbijeni su i nad sopstvenim API-jem -
-- prava dobijaju tek kroz sp_setapprole. ukradena lozinka logina ne vredi nista.
GRANT CONNECT TO AppUserDEV;
GRANT CONNECT TO AppUserQA;
GO

DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::impl    TO AppUserDEV, AppUserQA;
DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::spec    TO AppUserDEV, AppUserQA;
DENY SELECT, EXECUTE ON SCHEMA::api_dev TO AppUserDEV, AppUserQA;
DENY SELECT, EXECUTE ON SCHEMA::api_qa  TO AppUserDEV, AppUserQA;
GO
