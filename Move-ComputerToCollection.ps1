# This script is dependent of the WebService available at scconfigmgr.com

# Decides if script should move to Success or Failure collection (Set to "Success" or "Failure")
$Scriptmode = "Success"

# WebService-secret
$Secret = "11111111-2222-3333-4444-555555555555"

# CollectionID of collection for failed computers
$CollectionIdFail = "PS100002"

# CollectionID of collection for success computers
$CollectionIdSuccess = "PS100003"

# URI to the WebService
$URI = "https://memcm.contoso.com/ConfigMgrWebService/ConfigMgr.asmx"


# Construct web service proxy
try {
    $WebService = New-WebServiceProxy -Uri $URI -ErrorAction Stop
}
catch [System.Exception] {
    Write-Warning -Message "An error occured while attempting to calling web service. Error message: $($_.Exception.Message)" ; exit 2
}

if ($Scriptmode -eq "Failure")
{
    $AddToCollection = $CollectionIdFail
    $RemoveFromCollection = $CollectionIdSuccess
}
elseif ($Scriptmode -eq "Success")
{
    $AddToCollection = $CollectionIdSuccess
    $RemoveFromCollection = $CollectionIdFail
}

# Add computer to collection and remove it from the success/failure collection
$Invocation = $WebService.AddCMComputerToCollection($Secret, $env:COMPUTERNAME, $AddToCollection)
switch ($Invocation) {
    $true {
        $CollectionMember = $WebService.GetCMCollectionsForDeviceByName($Secret, $env:COMPUTERNAME) | where {$_.CollectionID -eq "$RemoveFromCollection"}
        if ($CollectionMember)
        {
            $WebService.RemoveCMDeviceFromCollection($Secret, $env:COMPUTERNAME, $RemoveFromCollection)
        }
        exit 0
    }
    $false {
        exit 1
    }
}
