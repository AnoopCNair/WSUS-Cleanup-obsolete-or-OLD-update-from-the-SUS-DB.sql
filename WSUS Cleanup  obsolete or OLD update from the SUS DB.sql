DECLARE @var1 INT
DECLARE @msg nvarchar(100)
DECLARE @count BIGINT
CREATE TABLE #results (Col1 INT)
INSERT INTO #results(Col1) EXEC spGetObsoleteUpdatesToCleanup
Select @count=count(Col1) From #results
DECLARE WC Cursor
FOR
SELECT Col1 FROM #results
OPEN WC
FETCH NEXT FROM WC
INTO @var1
WHILE (@@FETCH_STATUS > -1)
BEGIN SET @msg = 'Deleting ' + CONVERT(varchar(10), @var1) + ' Remaining rows:' + convert (varchar(10),@count)
RAISERROR(@msg,0,1) WITH NOWAIT EXEC spDeleteUpdate @localUpdateID=@var1
Set @count=@count -1
FETCH NEXT FROM WC INTO @var1 END
CLOSE WC
DEALLOCATE WC
DROP TABLE #results