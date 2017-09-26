# Windows

## Windows Module

### Version
  - 1.0

### Functions
- **Get-Session** 
  - Gets a list of Sessions on a computer
  
  - **`[String[]]`ComputerName** : Name of the computer to get the sessions 

## Misc Windows Powershell Cmdlets

Get-LoggedOnUser ------ Gets a list of logged on user Sessions

### .Net Functions
- **Get-DotNetHotfixes**
  - Retrieves a list of .Net hotfixes
  
### WSUS Scripts

- **Cleanup-WSUSServerMaintenance.ps1**
  - Description 
     Performs WSUS recommended cleanup maintenance
	 
  - Parameters
    - **ComputerName** : WSUS Server Name.  Defaults to the local host.
	- **SQLServer** : Name of the SQL Server that hosts the SUSDB.
	- **Port** : Port number that WSUS listens on.
	
	
