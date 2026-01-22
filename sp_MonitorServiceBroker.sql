USE [DBAdmin]
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_MonitorServiceBroker]
    @Databases NVARCHAR(MAX),
    @LoggingTable NVARCHAR(4000) = 'dbo.MonitorServiceBroker',
    @EnableBroker BIT = 0,
    @DefaultAlerting BIT = 1,
    @Retention INT = 90,
    @Debug BIT = 0
AS
BEGIN
/*
sp_MonitorServiceBroker by DataPaws
Documentation: https://datapawsconsulting.com/sp_MonitorServiceBroker
Version: 01/22/2026 18:03
GitHub: https://github.com/DataPaws/sp_MonitorServiceBroker

Description:
    This procedure monitors the status of service broker and will alert when service broker is disabled,
    and attempt to automatically resolve issues.

Parameters:
    @Databases						Specify the list of databases to target, default is all query store enabled databases - Example: @Databases = 'Database1, Database2, Database3'
    @LoggingTable					NULL = Disabled, Specify a table to enable logging of actions and query store failures - Table can be specified in one, two, or three-part format
    @EnableBroker			        0 = Disabled, 1 = Attempts to automatically re-enable service broker
    @DefaultAlerting				0 = Disabled, 1 = Uses built-in SQL Alerts on Severity 16 that write to the error log to notify for failures
    @Retention				        Number of days to retain data in the Logging Table
*/
BEGIN TRY

    SET NOCOUNT ON;

    DECLARE 
            @SQL NVARCHAR(MAX),
            @ErrorMessage NVARCHAR(1000);

    IF @Databases IS NULL
    BEGIN
        RAISERROR('No databases were specified.', 16, 1);
        RETURN;
    END

    CREATE TABLE #DatabaseList (DatabaseName NVARCHAR(128) PRIMARY KEY);

    INSERT INTO #DatabaseList (DatabaseName)
    SELECT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@Databases, ',')
    WHERE LTRIM(RTRIM(value)) <> '';

    SELECT @Databases =
    STRING_AGG(d.[name], ', ')
    FROM sys.databases d
    JOIN #DatabaseList db ON db.DatabaseName = d.[name]
    WHERE d.is_broker_enabled = 0
          AND d.state_desc = 'ONLINE'
          AND d.user_access = 0
		  AND d.is_read_only <> 1
		  AND d.database_id > 4;

    IF @LoggingTable IS NOT NULL
	BEGIN
		SET @LoggingTable =
			COALESCE(QUOTENAME(PARSENAME(@LoggingTable, 3)) + '.', '') +
			COALESCE(QUOTENAME(PARSENAME(@LoggingTable, 2)) + '.', '') +
			COALESCE(QUOTENAME(PARSENAME(@LoggingTable, 1)), '');
		   
		IF COALESCE(RTRIM(@LoggingTable), '') = ''
		BEGIN;
			RAISERROR('The Logging table input parameter is not properly formatted.', 16, 1);
			RETURN;
		END;
		
		IF OBJECT_ID (@LoggingTable) IS NULL
		BEGIN
            SET @SQL = N'
                CREATE TABLE ' + @LoggingTable + ' (
				    DatabaseName NVARCHAR(128) NOT NULL,
                    BrokerStatus BIT NOT NULL,
                    CollectionTime DATETIME NOT NULL
			    );';

            IF @Debug = 1
            BEGIN
                PRINT @SQL;
            END
            ELSE
            BEGIN
                EXEC sp_executesql @SQL;
            END

            SET @SQL = N'
                CREATE CLUSTERED INDEX CX_CollectionTime ON ' + @LoggingTable + '(CollectionTime ASC)';

            IF @Debug = 1
            BEGIN
                PRINT @SQL;
            END
            ELSE
            BEGIN
                EXEC sp_executesql @SQL;
            END

        END
        ELSE
        BEGIN
            SET @SQL = N'
                INSERT INTO ' + @LoggingTable + ' (DatabaseName, BrokerStatus, CollectionTime)
                SELECT
                    d.[name],
                    d.is_broker_enabled,
                    GETDATE()
                FROM sys.databases d
                JOIN #DatabaseList db ON db.DatabaseName = d.[name]
                WHERE d.state_desc = ''ONLINE''
                  AND d.user_access = 0
                  AND d.is_read_only <> 1
                  AND d.database_id > 4;';

            IF @Debug = 1
            BEGIN
                PRINT @SQL;
            END
            ELSE
            BEGIN
                EXEC sp_executesql @SQL;
            END

            SET @SQL = N'
                DELETE FROM ' + @LoggingTable + '
                WHERE CollectionTime < DATEADD(DAY, -' + CAST(@Retention AS NVARCHAR(10)) + ', GETDATE());';
            
            IF @Debug = 1
            BEGIN
                PRINT @SQL;
            END
            ELSE
            BEGIN
                EXEC sp_executesql @SQL;
            END

        END;
    END;

    IF @Databases IS NULL
    BEGIN
        PRINT 'All specified databases have Service Broker enabled.'
        RETURN;
    END
    ELSE
    BEGIN
        IF @EnableBroker = 1
        BEGIN
            SELECT @SQL =
                STRING_AGG(
                    N'ALTER DATABASE ' + QUOTENAME(d.[name]) + N' SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE;',
                    CHAR(13) + CHAR(10)
                )
            FROM sys.databases d
            JOIN #DatabaseList db ON db.DatabaseName = d.[name]
            WHERE d.is_broker_enabled = 0
                  AND d.state_desc = 'ONLINE'
                  AND d.user_access = 0
		          AND d.is_read_only <> 1
		          AND d.database_id > 4;

            IF @SQL IS NOT NULL
            BEGIN
                IF @Debug = 1
                BEGIN
                    PRINT @SQL;
                END
                ELSE
                BEGIN
                    EXEC sp_executesql @SQL;
                END
            END
        END

        IF @DefaultAlerting = 1
        BEGIN
            SET @ErrorMessage = N'Databases with Service Broker disabled: ' + @Databases;
            RAISERROR (@ErrorMessage, 16, 1) WITH LOG;
        END

    END;
END TRY
BEGIN CATCH

		SELECT  ERROR_NUMBER() AS ErrorNumber,
			    ERROR_SEVERITY() AS ErrorSeverity,
			    ERROR_STATE() AS ErrorState,
			    ERROR_PROCEDURE() AS ErrorProcedure,
			    ERROR_LINE() AS ErrorLine,
			    ERROR_MESSAGE() AS ErrorMessage;
		THROW;

END CATCH
END;
GO
