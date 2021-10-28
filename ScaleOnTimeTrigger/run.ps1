# Input bindings
param($Timer)

$ErrorActionPreference = "Stop"

# Variable definitions
$resourceId = $env:SignalRResourceId

$connectionsPerUnit = 1000          # Number of concurent connections you can have per unit
$unitCounts = 1,2,5,10,20,50,100    # Supported SignalR Unit Counts
$scaleThreshold = .95               # Percentage threshold at which to scale 

# Get information about the current resource state
$signalRResource = Get-AzResource -ResourceId $resourceId -Verbose
$currentUnitCount = [int]$signalRResource.Sku.Capacity

# Only scale if we are not on the Free Plan
if ($signalRResource.Sku.Name.StartsWith("Free_")) {
    Write-Host "Can't scale as resource is not on a scalable plan: " $signalRResource.Sku.Name
    exit 1
}

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

    Write-Host "Scaling resource to unit count: " $targetUnitCount
            
    # Change the resource unit count
    $signalRResource.Sku.Capacity = $targetUnitCount
    $signalRResource | Set-AzResource -Force
    
} else {

    Write-Host "Not scaling as resource is already at the optimum unit count: " $currentUnitCount

}
