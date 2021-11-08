# Input bindings
param($Timer)

$ErrorActionPreference = "Stop"

# Get resources
if ($env:SqlDatabaseResourceId) {
    $sqlDatabaseResources = @(Get-AzResource -ResourceId $env:SqlDatabaseResourceId)
}
elseif ($env:ResourceGroupName) {
    $sqlServerResources = @(Get-AzSqlServer -ResourceGroupName $env:ResourceGroupName)
    foreach ($sqlServerResource in $sqlServerResources) {
        $sqlDatabaseResources += @(Get-AzSqlDatabase -ResourceGroupName $env:ResourceGroupName -ServerName $sqlServerResource.ServerName)
    }
}
else {
    exit
}

[int]$storageScaleThreshold = ([double]$env:SqlDatabaseStorageScaleThreshold*100) ?? 95  # Percentage threshold at which to scale
[long]$storageScaleStep= $env:SqlDatabaseStorageScaleStep ?? 10GB

foreach ($sqlDatabaseResource in $sqlDatabaseResources) {
    # Only scale if storage is scalable
    if ($sqlDatabaseResource.Sku.Tier -in @("Basic", "Hyperscale")) {
        Write-Host "Can't scale as $($sqlDatabaseResource.DatabaseName) is not on a scalable tier: $($sqlDatabaseResource.Sku.Tier)"
        continue
    }

    # Only scale if database is running
    if ($sqlDatabaseResource.pausedDate) {
        Write-Host "Not scaling as $($sqlDatabaseResource.DatabaseName) is paused"
        continue
    }

    # Get metrics
    $storagePercentMetric = Get-AzMetric -ResourceId $sqlDatabaseResource.ResourceId -MetricName "storage_percent" -TimeGrain 0:05:00 -StartTime (Get-Date).AddMinutes(-5) -AggregationType Maximum
    $maxStoragePercent = $storagePercentMetric.Timeseries.Data[0].Maximum

    Write-Host "Current storage usage of $($sqlDatabaseResource.DatabaseName): $maxStoragePercent% of $($sqlDatabaseResource.Properties.maxSizeBytes/1GB)GB"

    # See if we need to scale
    if ($maxStoragePercent -lt $storageScaleThreshold) {
        Write-Host "Not scaling as $($sqlDatabaseResource.DatabaseName) is already at the optimum storage usage"
        continue
    }

    $sqlDatabaseResource.Properties.maxSizeBytes += $storageScaleStep
    Write-Host "Scaling $($sqlDatabaseResource.DatabaseName) to storage size: $($sqlDatabaseResource.Properties.maxSizeBytes/1GB)GB"
    $sqlDatabaseResource | Set-AzResource -Force
}
