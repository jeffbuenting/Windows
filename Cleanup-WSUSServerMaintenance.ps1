<#
    .Source
        Performs WSUS Clean up Maintenance

    .Description
        Following WSUS best practice, the clean up wizard should be run periodically.  Also a SQL reindex should be perfromed after the clean up.  This script automates these steps

    .Parameter ComputerName
        WSUS Server Name.

    .Parameter SQLServer
        Name of the SQL server that hosts the SUSDB

    .Parameter Port
        WSUS port

    .Links
        https://blogs.technet.microsoft.com/configurationmgr/2016/01/26/the-complete-guide-to-microsoft-wsus-and-configuration-manager-sup-maintenance/

    .Links
        https://technet.microsoft.com/itpro/powershell/windows/wsus/invoke-wsusservercleanup

    .Links
        Reindex SQL SUSDB

        https://gallery.technet.microsoft.com/scriptcenter/6f8cde49-5c52-4abd-9820-f1d270ddea61
#>


[CmdletBinding()]
Param (
    [String]$ComputerName = $env:COMPUTERNAME,

    [String]$SQLServer,

    [Int]$Port = 8530
)

# ----- Check if WSUSCleanup source exists : http://stackoverflow.com/questions/28196488/how-to-check-if-event-log-with-certain-source-name-exists
if ( [System.Diagnostics.Eventlog]::SourceExists( "WSUSCleanup" ) -eq $False ) {
    New-EventLog -LogName Application -Source "WSUSCleanup"
}

# ----- WSUS Cleanup
Try {
    Write-Verbose "Running WSUS Cleanup Wizard"
    $CleanupLog = Get-WSUSServer -Name $ComputerName -PortNumber $Port | Invoke-WsusServerCleanup -CleanupObsoleteUpdates -CleanupObsoleteComputers -CleanupUnneededContentFiles -Verbose 4>&1
}
Catch {
    $EXceptionMessage = $_.Exception.Message
    $ExceptionType = $_.exception.GetType().fullname
    Write-EventLog -LogName Application -Source WSUSCleanup -EventID 9999 -EntryType Error -Message "Problem running WSUS Cleanup Wizard .`n`n     $ExceptionMessage`n`n     Exception : $ExceptionType"

    Throw "Problem running WSUS Cleanup Wizard .`n`n     $ExceptionMessage`n`n     Exception : $ExceptionType"
}

# ----- Reindex SQL Server
$Reindex = @"
/******************************************************************************
This sample T-SQL script performs basic maintenance tasks on SUSDB
1. Identifies indexes that are fragmented and defragments them. For certain
   tables, a fill-factor is set in order to improve insert performance.
   Based on MSDN sample at http://msdn2.microsoft.com/en-us/library/ms188917.aspx
   and tailored for SUSDB requirements
2. Updates potentially out-of-date table statistics.
******************************************************************************/

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


--Update all statistics
PRINT 'Updating all statistics.' + convert(nvarchar, getdate(), 121) 
EXEC sp_updatestats
PRINT 'Done updating statistics.' + convert(nvarchar, getdate(), 121) 
GO
"@


# ----- Because I don't feel like installing SSMS on this server just so I can have the SQLPS module, I will run the reindex remotely from the SQL Server

$ReindexLog = invoke-Command -ComputerName $SQLServer -ScriptBlock {

    $Location = Get-Location
    import-module sqlps -disablenamechecking
    #Redirect verbose to output stream
    invoke-sqlcmd -serverInstance $Using:SQLServer -query $Using:Reindex -Verbose 4>&1
}

# ----- Write To Log


Write-EventLog -LogName Application -Source WSUSCleanup -EventID 9999 -EntryType Information -Message "WSUSCleanup has Completed : `n`n`n$($CleanupLog | Out-String)`n`n`n$($ReindexLog | Out-String)"