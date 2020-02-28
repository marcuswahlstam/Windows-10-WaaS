<#
This script will gather the information that SetupDiag puts in the registry and write that to a log file.
You must change the $centralLogFile variable to a shared folder on the network
#>

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

    # Set the location of central logfile
    $centralLogFile = "\\server\Win10UpgradeLogs$\SetupDiag\$env:COMPUTERNAME" + ".log"

    # Database logging or not (NOT IMPLEMENTED YET)
    $databaseLog = $false

    # Hex to message translation for known error codes
    # https://support.microsoft.com/en-us/help/10587/windows-10-get-help-with-upgrade-installation-errors
    switch ($CompatScanResultHex) {
        "c1900223" {$CompatScanKnownError = "Unable to get update"}
        "c1900208" {$CompatScanKnownError = "Incompatible application"}
        "80073712" {$CompatScanKnownError = "Missing or corrupt file"}
        "c1900200" {$CompatScanKnownError = "Minimum requirement not met"}
        "c1900202" {$CompatScanKnownError = "Minimum requirement not met"}
        "800F0923" {$CompatScanKnownError = "Incompatible driver"}
        "80070070" {$CompatScanKnownError = "Not enough disk space"}
        "c1900101" {$CompatScanKnownError = "Incompatible driver or Anti Virus"}
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
    $logContent | ConvertTo-Csv | Out-File $centralLogFile
    if ($localLogFile)
    {
        $logContent | ConvertTo-Html | Out-File $localLogFile
    }
}
