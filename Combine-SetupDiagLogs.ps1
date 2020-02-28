<#
This script will combine the CSV's it can find into one CSV and one HTML report 
#>

# Where to find logs
$centralLogFilesLocation = "\\server\Win10UpgradeLogs$\SetupDiag\"

# Find the logs based on file name pattern
$logFiles = Get-ChildItem $centralLogFilesLocation -Depth 0 -Include 'W10*.log' -File

# Where to save the reports HTML and CSV
$combinedHTMLReport = "\\server\Win10UpgradeLogs$\SetupDiag\CombinedLogFile.html"
$combinedCSVReport = "\\server\Win10UpgradeLogs$\SetupDiag\CombinedLogFile.csv"

# Create array and read all the log files content
$combinedResult = @()
foreach ($logFile in $logFiles)
{
    $logFileContent = Get-Content $($logFile.FullName) | ConvertFrom-Csv
    $combinedResult += $logFileContent
}

# Output the result to HTML and CSV
$combinedResult | ConvertTo-Html | Out-File $combinedHTMLReport
$combinedResult | ConvertTo-Csv | Out-File $combinedCSVReport
