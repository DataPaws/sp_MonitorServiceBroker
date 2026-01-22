# sp_MonitorServiceBroker
This is a free tool from **[DataPaws Consulting](https://datapawsconsulting.com)** for SQL Server Database Administrators to monitor the status of Service Broker enabled databases. 
It’s designed to detect if Service Broker is disabled, log the results, and optionally attempt to automatically re-enable it.

# What does sp_MonitorServiceBroker do?
  • Review the Service Broker status of your SQL Server databases quickly and easily <br>
  • Automatically log database status to a configurable table for historical tracking <br>
  • Generate alerts when databases have Service Broker disabled <br>
  • Optionally attempt to re-enable Service Broker if it's disabled <br>

# Alerting
If @DefaultAlerting = 1, the procedure will raise an error containing the database(s) that have Service Broker disabled. This allows SQL Server Agent or monitoring tools to capture the alert automatically.

# Example Usage
The tool is designed to run as part of a scheduled SQL Agent Job that runs on a reoccurring basis, typically every 5 - 15 minutes.
  • Basic Monitoring
```
EXEC dbo.sp_MonitorServiceBroker
    @Databases = 'Database1, Database2';
```
  • Enable Broker Automatically
```
EXEC dbo.sp_MonitorServiceBroker
    @Databases = 'Database1, Database2',
    @EnableBroker = 1;
```
  • Logging Enabled with 90-Day Retention
```
EXEC dbo.sp_MonitorServiceBroker
    @Databases = 'Database1, Database2',
    @LoggingTable = 'dbo.MonitorServiceBroker',
    @Retention = 90;
```
  • Debug Mode
```
EXEC dbo.sp_MonitorServiceBroker
    @Databases = 'Database1, Database2',
    @Debug = 1;
```
