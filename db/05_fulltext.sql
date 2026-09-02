USE [BugTracker];
GO

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

CREATE FULLTEXT CATALOG ftBugTracker WITH ACCENT_SENSITIVITY = ON AS DEFAULT;
GO

CREATE FULLTEXT INDEX ON impl.tblGreska (Poruka LANGUAGE 3098)
    KEY INDEX PK_Greska ON ftBugTracker WITH CHANGE_TRACKING = AUTO;
GO

CREATE FULLTEXT INDEX ON impl.tblProjekat (Opis LANGUAGE 3098)
    KEY INDEX PK_Projekat ON ftBugTracker WITH CHANGE_TRACKING = AUTO;
GO

CREATE FULLTEXT INDEX ON impl.tblKomentar (SadrzajXML LANGUAGE 3098)
    KEY INDEX PK_Komentar ON ftBugTracker WITH CHANGE_TRACKING = AUTO;
GO

DECLARE @i INT = 0;
WHILE FULLTEXTCATALOGPROPERTY(N'ftBugTracker', 'PopulateStatus') <> 0 AND @i < 90
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @i += 1;
END
GO
