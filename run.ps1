# Input bindings
param($Timer)

# Variable definitions
$resourceId = $env:SignalRResourceId

$connectionsPerUnit = 1000          # Number of concurent connections you can have per unit
$unitCounts = 1,2,5,10,20,50,100    # Supported SignalR Unit Counts
$scaleThreshold = .95               # Percentage threshold at which to scale 

# Authenticate the service principle
$clientId = $env:ServicePrincipalClientId
$key = $env:ServicePrincipalKey
$securePassword = ConvertTo-SecureString $key -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($clientId, $securePassword)
$tenantId = $env:ServicePrincipalTenantId

Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant $tenantId

# Get information about the current resource state
$signalRResource = Get-AzResource -ResourceId $resourceId -Verbose
$currentUnitCount = [int]$signalRResource.Sku.Capacity

# Only scale if we are on the Standard_S1 plan
if ($signalRResource.Sku.Name -eq "Standard_S1") {

    # Get metrics for the last 5 minutes
    $connectionCountMetric = Get-AzMetric -ResourceId $resourceId -MetricName "ConnectionCount" -TimeGrain 00:05:00 -StartTime (Get-Date).AddMinutes(-5) -AggregationType Maximum
    $maxConnectionCount = $connectionCountMetric.Timeseries.Data[0].Maximum

    # Calculate the target unit count
    $targetUnitCount = 1
    foreach ($unitCount in $unitCounts) {
        $unitCountConnections = $unitCount * $connectionsPerUnit
        $unitCountConnectionsThreshold = $unitCountConnections * $scaleThreshold
        if ($unitCountConnectionsThreshold -gt $maxConnectionCount -or $unitCount -eq $unitCounts[$unitCounts.Count - 1]) {
            $targetUnitCount = $unitCount
            Break
        }
    }

    # See if we need to change the unit count
    if ($targetUnitCount -ne $currentUnitCount) {

        Write-Host "Scaling to unit count: " $targetUnitCount
                
        # Change the resource unit count
        $signalRResource.Sku.Capacity = $targetUnitCount
        $signalRResource | Set-AzResource -Force
        
    } else {

        Write-Host "Not scaling as resource is already at the optimum unit count: " $currentUnitCount

    }

} else {

    Write-Host "Can't scale as resource is not on a scalable plan: " $signalRResource.Sku.Name

}