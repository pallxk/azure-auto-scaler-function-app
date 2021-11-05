# Input bindings
param($Timer)

$ErrorActionPreference = "Stop"

# Variable definitions
$resourceId = $env:SqlDatabaseResourceId
[int]$storageScaleThreshold = ([double]$env:SqlDatabaseStorageScaleThreshold*100) ?? 95  # Percentage threshold at which to scale
[long]$storageScaleStep= $env:SqlDatabaseStorageScaleStep ?? 10GB

# Get information about the current resource state
$sqlDatabaseResource = Get-AzResource -ResourceId $resourceId

# Only scale if storage is scalable
if ($sqlDatabaseResource.Sku.Tier -in @("Basic", "Hyperscale")) {
    Write-Host "Can't scale as resource is not on a scalable tier: " $sqlDatabaseResource.Sku.Tier
    exit 1
}

# Only scale if database is running
if ($sqlDatabaseResource.pausedDate) {
    Write-Host "Not scaling as SQL database is paused"
}

# Get metrics
$storagePercentMetric = Get-AzMetric -ResourceId $resourceId -MetricName "storage_percent" -TimeGrain 0:05:00 -StartTime (Get-Date).AddMinutes(-5) -AggregationType Maximum
$maxStoragePercent = $storagePercentMetric.Timeseries.Data[0].Maximum

Write-Host "Current storage usage: $maxStoragePercent% of $($sqlDatabaseResource.Properties.maxSizeBytes/1GB)GB"

# See if we need to scale
if ($maxStoragePercent -lt $storageScaleThreshold) {
    Write-Host "Not scaling as resource is already at the optimum storage usage"
    exit 0
}

$sqlDatabaseResource.Properties.maxSizeBytes += $storageScaleStep
Write-Host "Scaling resource to storage size: $($sqlDatabaseResource.Properties.maxSizeBytes/1GB)GB"
$sqlDatabaseResource | Set-AzResource -Force
