USE [Database]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[SP_SearchDuplicateRows] as
			   
/***********************************************************************************************************************************
OBJECT NAME:		Validation - Find any full row duplicates on tables that have a column named: ReportPublication

EXECUTION PLAN:		Manually

CHILD OBJECTS:		n/a

DESCRIPTION:		This will parse a list tables and look for any full row duplicates.

HISTORY:
> 10/09/17 - YS created
***********************************************************************************************************************************/







-------------------------------------------------------------------------------------------------
-- 1. SET UP PARAMETERS
-------------------------------------------------------------------------------------------------

SET NOCOUNT ON;

DECLARE @sql VARCHAR(MAX);
DECLARE @col VARCHAR(MAX);
DECLARE @tbl VARCHAR(250);

IF OBJECT_ID('tempdb..#process') IS NOT NULL DROP TABLE #process;
	
	
	
	
	
	
	
	
-------------------------------------------------------------------------------------------------
--2. SET UP LIST OF TABLES TO WALKTHROUGH
-------------------------------------------------------------------------------------------------


	-- 2.1  Select only samller tables, less 1gb (can set this to be anything) 
	-----------------------------------------------------------------------
	SELECT t.NAME AS TblName, 0 AS IsDone, 0 AS RowCnt
	INTO  #process
	FROM   sys.tables t
		   INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
		   INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
		   INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
		   INNER JOIN sys.schemas s ON t.schema_id = s.schema_id AND s.name = 'dbo'
	GROUP BY t.Name, p.Rows
	HAVING SUM(a.used_pages)*8 < 100000
	ORDER BY 1 desc



-------------------------------------------------------------------------------------------------
--3. LOOP THROUGH TABLE, CHECK IF ANY FULL ROW DUPLICATES
-------------------------------------------------------------------------------------------------

	WHILE (SELECT COUNT (*) FROM #process WHERE IsDone = 0) > 0
	BEGIN
	
	
			--3.1 Set unproccessed table
			-----------------------------------------------------------------
			SET @tbl = (SELECT TOP 1 TblName FROM #process WHERE IsDone = 0)


			--3.2 Set this tables current columns
			-----------------------------------------------------------------
			SET @col = ''
				SELECT @col = @col + '['+name+']' + ', ' 
				FROM sys.columns 
				WHERE OBJECT_ID = OBJECT_ID(@tbl)
				
				
			--3.3 Set dynamic duplicate sql
			-----------------------------------------------------------------
			SELECT @sql = 
			  'SELECT ' + '''' + @tbl + '''' + ' as TBL, '				+ CHAR(13)+CHAR(10)
			+ SUBSTRING(@col, 0, LEN(@col))	+ ','						+ CHAR(13)+CHAR(10)
			+ 'COUNT(*)CNT '											+ CHAR(13)+CHAR(10) 
			+ 'FROM ' + @tbl											+ CHAR(13)+CHAR(10)
			+ 'GROUP BY ' + SUBSTRING(@col, 0, LEN(@col))				+ CHAR(13)+CHAR(10)
			+ 'HAVING COUNT(*) > 1'

			
			--3.3 Set dynamic duplicate sql
			-----------------------------------------------------------------
			PRINT '---------------------------------------------------------'+ CHAR(13)+CHAR(10)+
				  'PROCESSING: ' + @tbl 
			
			EXECUTE(@sql)
			
			UPDATE #process SET RowCnt = @@ROWCOUNT WHERE TblName = @tbl
			
			
			
			--3.4 Check if table has duplicates
			-----------------------------------------------------------------
			IF (SELECT RowCnt FROM #process WHERE TblName = @tbl) > 1
				BEGIN
					PRINT @tbl + ':'
					RAISERROR('**found duplicates**' ,11,0)
				END
			ELSE 
				BEGIN
					PRINT 'no duplicates'
				END;


			--3.4 Set completed table, to restart loop
			-----------------------------------------------------------------
			
			UPDATE #process SET IsDone = 1 WHERE TblName = @tbl
	    
	END











