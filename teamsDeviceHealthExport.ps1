param (
    [string]$tenantID = "",
    [string]$clientID = "",
    [string]$clientSecret = "",
    [string]$csvExportPath = "",
    [string]$scope = "https://graph.microsoft.com/.default",
    [string]$tokenEndpoint = "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token"
)

$body = @{
    client_id     = $clientID
    scope         = $scope
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

# authenticate to graph endpoint
$authResponse = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $body
$accessToken = $authResponse.access_token

$headers = @{
    Authorization = "Bearer $accessToken"
}

# get all devices before drilling into health endpoint

$allDevices = @()

$uri = "https://graph.microsoft.com/beta/teamwork/devices"

do {
    $dataResponse = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

    $allDevices += $dataResponse

    $uri = $dataResponse.'@odata.nextLink'
} while ($uri -ne $null)

$newList = @()
foreach ($batch in $allDevices) {
    $newList += $batch.Value
}

# drill into health endpoint

$allHealth = @()

foreach ($deviceId in $newList) {
    $uri = "https://graph.microsoft.com/beta/teamwork/devices/$($deviceId.id)/health"
    $allHealth += Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
}

# export report of current health

$flattenedHealthData = @()

foreach ($item in $allHealth) {
    
    # make custom obj for all relevant statuses and versions
    $softwareUpdate = [PSCustomObject]@{
        Id                              = $item.id
        AdminAgentStatus                = $item.softwareUpdateHealth.adminAgentSoftwareUpdateStatus.softwareFreshness
        AdminAgentCurrentVersion        = $item.softwareUpdateHealth.adminAgentSoftwareUpdateStatus.currentVersion
        AdminAgentAvailableVersion      = $item.softwareUpdateHealth.adminAgentSoftwareUpdateStatus.availableVersion
        CompanyPortalStatus             = $item.softwareUpdateHealth.companyPortalSoftwareUpdateStatus.softwareFreshness
        CompanyPortalCurrentVersion     = $item.softwareUpdateHealth.companyPortalSoftwareUpdateStatus.currentVersion
        CompanyPortalAvailableVersion   = $item.softwareUpdateHealth.companyPortalSoftwareUpdateStatus.availableVersion
        TeamsClientStatus               = $item.softwareUpdateHealth.teamsClientSoftwareUpdateStatus.softwareFreshness
        TeamsClientCurrentVersion       = $item.softwareUpdateHealth.teamsClientSoftwareUpdateStatus.currentVersion
        TeamsClientAvailableVersion     = $item.softwareUpdateHealth.teamsClientSoftwareUpdateStatus.availableVersion
        FirmwareStatus                  = $item.softwareUpdateHealth.firmwareSoftwareUpdateStatus.softwareFreshness
        FirmwareCurrentVersion          = $item.softwareUpdateHealth.firmwareSoftwareUpdateStatus.currentVersion
        FirmwareAvailableVersion        = $item.softwareUpdateHealth.firmwareSoftwareUpdateStatus.availableVersion
        PartnerAgentStatus              = $item.softwareUpdateHealth.partnerAgentSoftwareUpdateStatus.softwareFreshness
        PartnerAgentCurrentVersion      = $item.softwareUpdateHealth.partnerAgentSoftwareUpdateStatus.currentVersion
        PartnerAgentAvailableVersion    = $item.softwareUpdateHealth.partnerAgentSoftwareUpdateStatus.availableVersion
    }

    $flattenedHealthData += $softwareUpdate
}

$flattenedHealthData | Export-Csv -Path $csvExportPath -NoTypeInformation