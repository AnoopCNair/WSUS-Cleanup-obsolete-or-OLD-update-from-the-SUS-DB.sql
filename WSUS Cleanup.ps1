\\.\pipe\MICROSOFT##WID\tsql\query

Step 1: - Run the below query to get the number of superseded updates.
 
SELECT UpdateID FROM vwMinimalUpdate WHERE IsSuperseded = 1 AND Declined = 0
 
Step 2: - Run below query to decline all the superseded updates.
 
DECLARE @var1 uniqueidentifier
DECLARE @msg nvarchar(100)
DECLARE DU Cursor
FOR
SELECT UpdateID FROM vwMinimalUpdate WHERE IsSuperseded = 1 AND Declined = 0
Open DU
FETCH NEXT FROM DU INTO @var1
WHILE (@@FETCH_STATUS > -1)
BEGIN
RAISERROR(@msg,0,1) WITH NOWAIT exec spDeclineUpdate @updateID=@var1,@adminName=N'domain\user',@failIfReplica=1
FETCH NEXT FROM DU INTO @var1
END
CLOSE DU
DEALLOCATE DU
 
Step 3: - To check no. of obsolete updates.
 
exec spGetObsoleteUpdatesToCleanup  
 
Step 4: - To delete Obsolete Updates.
 
DECLARE @var1 INT
DECLARE @msg nvarchar(100)
CREATE TABLE #results (Col1 INT)
INSERT INTO #results(Col1) EXEC spGetObsoleteUpdatesToCleanup
DECLARE WC Cursor
FOR
SELECT Col1 FROM #results
OPEN WC
FETCH NEXT FROM WC
INTO @var1
WHILE (@@FETCH_STATUS > -1)
BEGIN SET @msg = 'Deleting ' + CONVERT(varchar(10), @var1)
RAISERROR(@msg,0,1) WITH NOWAIT EXEC spDeleteUpdate @localUpdateID=@var1
FETCH NEXT FROM WC INTO @var1 END
CLOSE WC
DEALLOCATE WC
DROP TABLE #results

Step 5: - To check no. of Hidden updates.

SELECT * FROM tbUpdate WHERE isHidden = 1

Step 6: - To delete Hidden Updates. Please run all queries in one go on WSUS database.

delete from tbrevisionlanguage where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbLocalizedPropertyForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbFileForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbInstalledUpdateSufficientForPrerequisite where prerequisiteid in (select Prerequisiteid from tbPreRequisite where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 )))
delete from tbPreRequisite where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbDeployment where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbXml where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbPreComputedLocalizedProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbDriver where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbFlattenedRevisionInCategory where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbRevisionInCategory where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbMoreInfoURLForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbBundleAtLeastOne where bundledid in (select bundledid from tbBundleAll where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)))
delete from tbBundleAll where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbSecurityBulletinForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbKBArticleForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbRevisionSupersedesUpdate where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbBundleAtLeastOne where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbEulaProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)
delete from tbUpdateSummaryForAllComputers where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)
delete from tbInstalledUpdateSufficientForPrerequisite where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)
delete from tbUpdate where ishidden = 1

Step 7: - Please perform the following Query on the SUSDB.  (Detection logic update has XML length (Amount of data for metadata – its size))   Windows 10 update XML size keep on growing every month.

A: - Run the below query, to know no. of updates for XML length 50000 or more.
Select
  u.UpdateID,
  r.RevisionNumber,
  r.RevisionID,
  lp.Title,
  pr.ExplicitlyDeployable as ED,
  pr.UpdateType,
  pr.CreationDate
 from
  tbUpdate u
  inner join tbRevision r on u.LocalUpdateID = r.LocalUpdateID
  inner join tbProperty pr on pr.RevisionID = r.RevisionID
  inner join tbLocalizedPropertyForRevision lpr on r.RevisionID = lpr.RevisionID
  inner join tbLocalizedProperty lp on lpr.LocalizedPropertyID = lp.LocalizedPropertyID
 where
  lpr.LanguageID = 1033
  and r.RevisionID in (
select
  t1.RevisionID
from
  tbBundleAll t1
  inner join tbBundleAtLeastOne t2 on t1.BundledID=t2.BundledID
where
  t2.RevisionID in(SELECT dbo.tbXml.RevisionID FROM dbo.tbXml
INNER JOIN dbo.tbProperty ON dbo.tbXml.RevisionID = dbo.tbProperty.RevisionID
where ISNULL(datalength(dbo.tbXml.RootElementXmlCompressed), 0) > 50000) and ishidden=0 and  pr.ExplicitlyDeployable=1)

B: - If there are updates present then we decline them with the following cursor:

DECLARE @UpdateID nvarchar(100)
DECLARE @msg nvarchar(100)

CREATE TABLE #Updates (UpdateID nvarchar(100))
 
INSERT INTO #Updates(UpdateID)
select
  u.UpdateID
  from
  tbUpdate u
  inner join tbRevision r on u.LocalUpdateID = r.LocalUpdateID
  inner join tbProperty pr on pr.RevisionID = r.RevisionID
  inner join tbLocalizedPropertyForRevision lpr on r.RevisionID = lpr.RevisionID
  inner join tbLocalizedProperty lp on lpr.LocalizedPropertyID = lp.LocalizedPropertyID
 where
  lpr.LanguageID = 1033
  and r.RevisionID in (
select
  t1.RevisionID
from
  tbBundleAll t1
  inner join tbBundleAtLeastOne t2 on t1.BundledID=t2.BundledID
where
  t2.RevisionID in(SELECT dbo.tbXml.RevisionID FROM dbo.tbXml
INNER JOIN dbo.tbProperty ON dbo.tbXml.RevisionID = dbo.tbProperty.RevisionID
where ISNULL(datalength(dbo.tbXml.RootElementXmlCompressed), 0) > 50000) and ishidden=0 and  pr.ExplicitlyDeployable=1)
DECLARE UC Cursor
FOR
SELECT UpdateID FROM #Updates

OPEN UC
FETCH NEXT FROM UC
INTO @UpdateID
WHILE(@@FETCH_STATUS > -1)
BEGIN SET @msg = 'Declining ' + @UpdateID
RAISERROR(@msg,0,1) WITH NOWAIT EXEC spDeclineUpdate @updateID=@UpdateID,@adminName=N'mach14\administrator',@failIfReplica=1
 
FETCH NEXT FROM UC INTO @UpdateID END
CLOSE UC

DEALLOCATE UC
DROP TABLE #Updates

Step 8: - Delete decline superseded updates

delete from tbrevisionlanguage where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbLocalizedPropertyForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbFileForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbInstalledUpdateSufficientForPrerequisite where prerequisiteid in (select Prerequisiteid from tbPreRequisite where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 )))
delete from tbPreRequisite where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbDeployment where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbXml where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbPreComputedLocalizedProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1 ))
delete from tbDriver where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbFlattenedRevisionInCategory where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbRevisionInCategory where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbMoreInfoURLForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbBundleAtLeastOne where bundledid in (select bundledid from tbBundleAll where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)))
delete from tbBundleAll where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbSecurityBulletinForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbKBArticleForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbRevisionSupersedesUpdate where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbBundleAtLeastOne where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbEulaProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1))
delete from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)
delete from tbUpdateSummaryForAllComputers where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)
delete from tbInstalledUpdateSufficientForPrerequisite where LocalUpdateId in (select LocalUpdateId from tbUpdate where ishidden=1)
delete from tbUpdate where ishidden = 1

Step 9: - Delete the Drivers.

Determine GUID of the Driver Update Type

Open a new query window and run the following two queries:

USE SUSDB
GO        
SELECT UpdateTypeID FROM tbUpdateType WHERE Name = 'Driver'
GO

The above query gives you the GUID that you will need to substitute in all subsequent queries (if the GUID you get is not the same as what I have in subsequent statements). In my case, it is D2CB599A-FA9F-4AE9-B346-94AD54EE0629. Execute the below queries one by one.

delete from tbrevisionlanguage where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))
 
delete from tbProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbLocalizedPropertyForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbFileForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbInstalledUpdateSufficientForPrerequisite where prerequisiteid in (select Prerequisiteid from tbPreRequisite where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629')))

delete from tbPreRequisite where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbDeployment where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbXml where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbPreComputedLocalizedProperty where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbDriver where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbFlattenedRevisionInCategory where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbRevisionInCategory where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbMoreInfoURLForRevision where revisionid in (select revisionid from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'))

delete from tbRevision where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629')

delete from tbUpdateSummaryForAllComputers where LocalUpdateId in (select LocalUpdateId from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629')

delete from tbUpdate where UpdateTypeID = 'D2CB599A-FA9F-4AE9-B346-94AD54EE0629'

Step 10: - Run below query to re index WSUS database.

USE SUSDB;
GO
SET NOCOUNT ON;
 
-- Rebuild or reorganize indexes based on their fragmentation levels
DECLARE @work_to_do TABLE (
    objectid int
    , indexid int
    , pagedensity float
    , fragmentation float
    , numrows int
)
 
DECLARE @objectid int;
DECLARE @indexid int;
DECLARE @schemaname nvarchar(130);  
DECLARE @objectname nvarchar(130);  
DECLARE @indexname nvarchar(130);  
DECLARE @numrows int
DECLARE @density float;
DECLARE @fragmentation float;
DECLARE @command nvarchar(4000);  
DECLARE @fillfactorset bit
DECLARE @numpages int
 
-- Select indexes that need to be defragmented based on the following
-- * Page density is low
-- * External fragmentation is high in relation to index size
PRINT 'Estimating fragmentation: Begin. ' + convert(nvarchar, getdate(), 121)  
INSERT @work_to_do
SELECT
    f.object_id
    , index_id
    , avg_page_space_used_in_percent
    , avg_fragmentation_in_percent
    , record_count
FROM  
    sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'SAMPLED') AS f
WHERE
    (f.avg_page_space_used_in_percent < 85.0 and f.avg_page_space_used_in_percent/100.0 * page_count < page_count - 1)
    or (f.page_count > 50 and f.avg_fragmentation_in_percent > 15.0)
    or (f.page_count > 10 and f.avg_fragmentation_in_percent > 80.0)
 
PRINT 'Number of indexes to rebuild: ' + cast(@@ROWCOUNT as nvarchar(20))
 
PRINT 'Estimating fragmentation: End. ' + convert(nvarchar, getdate(), 121)
 
SELECT @numpages = sum(ps.used_page_count)
FROM
    @work_to_do AS fi
    INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
    INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id
 
-- Declare the cursor for the list of indexes to be processed.
DECLARE curIndexes CURSOR FOR SELECT * FROM @work_to_do
 
-- Open the cursor.
OPEN curIndexes
 
-- Loop through the indexes
WHILE (1=1)
BEGIN
    FETCH NEXT FROM curIndexes
    INTO @objectid, @indexid, @density, @fragmentation, @numrows;
    IF @@FETCH_STATUS < 0 BREAK;
 
    SELECT  
        @objectname = QUOTENAME(o.name)
        , @schemaname = QUOTENAME(s.name)
    FROM  
        sys.objects AS o
        INNER JOIN sys.schemas as s ON s.schema_id = o.schema_id
    WHERE  
        o.object_id = @objectid;
 
    SELECT  
        @indexname = QUOTENAME(name)
        , @fillfactorset = CASE fill_factor WHEN 0 THEN 0 ELSE 1 END
    FROM  
        sys.indexes
    WHERE
        object_id = @objectid AND index_id = @indexid;
 
    IF ((@density BETWEEN 75.0 AND 85.0) AND @fillfactorset = 1) OR (@fragmentation < 30.0)
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REORGANIZE';
    ELSE IF @numrows >= 5000 AND @fillfactorset = 0
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD WITH (FILLFACTOR = 90)';
    ELSE
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD';
    PRINT convert(nvarchar, getdate(), 121) + N' Executing: ' + @command;
    EXEC (@command);
    PRINT convert(nvarchar, getdate(), 121) + N' Done.';
END
 
-- Close and deallocate the cursor.
CLOSE curIndexes;
DEALLOCATE curIndexes;
 
IF EXISTS (SELECT * FROM @work_to_do)
BEGIN
    PRINT 'Estimated number of pages in fragmented indexes: ' + cast(@numpages as nvarchar(20))
    SELECT @numpages = @numpages - sum(ps.used_page_count)
    FROM
        @work_to_do AS fi
        INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
        INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id
 
    PRINT 'Estimated number of pages freed: ' + cast(@numpages as nvarchar(20))
END
GO