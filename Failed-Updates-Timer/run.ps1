# Set environment variables and local variables
$storageAccountName = "dattohaloalertsstgnirab"
$storageAccountKey = $env:strKey
$tableName = "DevicePatchAlerts"

# Connect to Azure Storage
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$table = Get-StorageTable -Context $context -TableName $tableName

# Define the threshold for row deletion
$thresholdDate = (Get-Date).AddDays(-90)

# Retrieve all entities from the table
$entities = Get-AzTableRowAll -Table $table

foreach ($entity in $entities) {
    if ($entity.Timestamp -lt $thresholdDate) {
        # Remove rows older than the threshold
        Remove-AzTableRow -Table $table -PartitionKey $entity.PartitionKey -RowKey $entity.RowKey
        Write-Host "Removed entity with RowKey: $($entity.RowKey) from PartitionKey: $($entity.PartitionKey)"
    }
}