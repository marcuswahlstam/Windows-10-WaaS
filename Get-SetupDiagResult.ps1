<#
This script will gather the information that SetupDiag puts in the registry and write that to a log file and/or a Database (not tested yet).

Create DB table "CompatScanFailures" in DB "W10WAAS":

USE W10WAAS;
CREATE TABLE CompatScanFailures (
    Computername varchar(255),
    ErrorCode varchar(255),
    KnownErrorMSG varchar(255),
    FailureData varchar(255),
    FailureDetails varchar(255),
    ProfileName varchar(255),
    Remediation varchar(255),
    RunTime varchar(255),
    FailureCount varchar(255)
);

#>

# Database logging or not, $true or $false (NOT IMPLEMENTED YET)
$databaseLogging = $false

# Database server, database and table
$databaseServer = "SQL.contoso.com"
$databaseDB = "W10WAAS"
$databaseTable = "CompatScanFailures"

# Central file based logging or not, $true or $false
$centralLogging = $true

# Set the location of central logfile (only relevant if $centralLogging = $true)
$centralLogFile = "\\server\Win10UpgradeLogs$\SetupDiag\$env:COMPUTERNAME" + ".log"

# Get returncode from CompatScan and convert to hex value
$CompatScanResultHex = "{0:x8}" -f (Get-ItemPropertyValue -Path HKLM:\SYSTEM\Setup\MoSetup\Volatile -Name BoxResult -ErrorAction SilentlyContinue)

# Check if return code is c1900210 (success)
if ($CompatScanResultHex -eq "c1900210")
{
    "CompatScan shows no issues"
    exit
}
else
{
    # Set the location of the local logfile. Comment out if you don't want a local log file
    $localLogFile = "$env:SystemRoot\Temp\Get-SetupDiagResult.log"

    # Hex to message translation for known error codes
    # https://support.microsoft.com/en-us/help/10587/windows-10-get-help-with-upgrade-installation-errors
    switch ($CompatScanResultHex) {
        "c1900223" {$CompatScanKnownError = "Unable to get update"}
        "c1900208" {$CompatScanKnownError = "Incompatible application (McAfee? - DOH!)"}
        "80073712" {$CompatScanKnownError = "Missing or corrupt file"}
        "c1900200" {$CompatScanKnownError = "Minimum requirement not met"}
        "c1900202" {$CompatScanKnownError = "Minimum requirement not met"}
        "800F0923" {$CompatScanKnownError = "Incompatible driver"}
        "80070070" {$CompatScanKnownError = "Not enough disk space"}
        "c1900101" {$CompatScanKnownError = "Incompatible driver or Anti Virus (McAfee? - DOH!)"}
        "800700B7" {$CompatScanKnownError = "Another process is blocking the upgrade"}
        "c1900107" {$CompatScanKnownError = "Cleanup from previous attempt is pending. Restart Required."}
        Default {$CompatScanKnownError = "Unknown error"}
    }

    # Get data that SetupDiag writes to the registry and remove any line breaks/newlines
    $failureData = (Get-ItemPropertyValue -Path HKLM:\SYSTEM\Setup\MoSetup\Volatile\SetupDiag -Name FailureData -ErrorAction SilentlyContinue) -replace "`n|`r"
    $failureDetails = (Get-ItemPropertyValue -Path HKLM:\SYSTEM\Setup\MoSetup\Volatile\SetupDiag -Name FailureDetails -ErrorAction SilentlyContinue) -replace "`n|`r"
    $profileName = (Get-ItemPropertyValue -Path HKLM:\SYSTEM\Setup\MoSetup\Volatile\SetupDiag -Name ProfileName -ErrorAction SilentlyContinue) -replace "`n|`r"
    $remediation = (Get-ItemPropertyValue -Path HKLM:\SYSTEM\Setup\MoSetup\Volatile\SetupDiag -Name Remediation -ErrorAction SilentlyContinue) -replace "`n|`r"
    $runTime = (Get-ItemPropertyValue -Path HKLM:\SYSTEM\Setup\MoSetup\Volatile\SetupDiag -Name DateTime -ErrorAction SilentlyContinue) -replace "`n|`r"
    $failureCount = Get-ItemPropertyValue -Path HKLM:\SYSTEM\Setup\MoSetup\Tracking -Name FailureCount -ErrorAction SilentlyContinue

    # Create a custom PSObject to hold the information and then add the info
    $logContent = New-Object -TypeName psobject
    $logContent | Add-Member -MemberType NoteProperty -Name ComputerName -Value $env:COMPUTERNAME
    $logContent | Add-Member -MemberType NoteProperty -Name FailureData -Value $failureData
    $logContent | Add-Member -MemberType NoteProperty -Name FailureDetails -Value $failureDetails
    $logContent | Add-Member -MemberType NoteProperty -Name ProfileName -Value $profileName
    $logContent | Add-Member -MemberType NoteProperty -Name Remediation -Value $remediation
    $logContent | Add-Member -MemberType NoteProperty -Name RunTime -Value $runTime
    $logContent | Add-Member -MemberType NoteProperty -Name CompatScanResultHex -Value $CompatScanResultHex
    $logContent | Add-Member -MemberType NoteProperty -Name CompatScanKnownError -Value $CompatScanKnownError
    $logContent | Add-Member -MemberType NoteProperty -Name CompatScanKnownError -Value $failureCount

    # Output the information to the log files specified
    if ($centralLogging)
    {
        $logContent | ConvertTo-Csv | Out-File $centralLogFile
    }

    if ($localLogFile)
    {
        $logContent | ConvertTo-Html | Out-File $localLogFile
    }

    if ($databaseLogging)
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $sqlConnection.ConnectionString = "Server=$databaseServer;Database=$databaseDB;Integrated Security=True;"
        $sqlConnection.Open()
    
        $query= "begin tran
                if exists (SELECT * FROM $databaseTable WITH (updlock,serializable) WHERE Computername='"+$env:COMPUTERNAME+"')
                begin
                    UPDATE $databaseTable SET Computername='"+$env:COMPUTERNAME+"', ErrorCode='"+$CompatScanResultHex+"', KnownErrorMSG='"+$CompatScanKnownError+"', FailureData='"+$failureData+"', FailureDetails='"+$failureDetails+"', ProfileName='"+$profileName+"', Remediation='"+$remediation+"', RunTime='"+$runTime+"', FailureCount='"+$failureCount+"'
                    WHERE Computername = '"+$env:COMPUTERNAME+"'
                end
                else
                begin
                    INSERT INTO $databaseTable (Computername, ErrorCode, KnownErrorMSG, FailureData, FailureDetails, ProfileName, Remediation, RunTime, FailureCount)
                    VALUES ('"+$env:COMPUTERNAME+"', '"+$CompatScanResultHex+"', '"+$CompatScanKnownError+"', '"+$failureData+"', '"+$failureDetails+"', '"+$profileName+"', '"+$remediation+"', '"+$runTime+"', '"+$failureCount+"')
                end
                commit tran"
    
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($query,$sqlConnection)
        $sqlDS = New-Object System.Data.DataSet
        $sqlDA = New-Object System.Data.SqlClient.SqlDataAdapter($sqlCommand)
        [void]$sqlDA.Fill($sqlDS)
    
        $sqlConnection.Close()
    }
}
