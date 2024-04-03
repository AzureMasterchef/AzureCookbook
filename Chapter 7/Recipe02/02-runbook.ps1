# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

$storageAccount = Get-AzStorageAccount -ResourceGroupName "Recipe07-02-rg" | 
                    ? StorageAccountName -like 'recipe0702*'

Write-Output "Azure Cookbook - Recipe 7.02" | Out-File -FilePath .\recipe0702.txt

$storageContext = New-AzStorageContext -UseConnectedAccount -BlobEndpoint $storageAccount.PrimaryEndpoints.blob

Set-AzStorageBlobContent -Container "images" -File ".\recipe0702.txt" -Blob "Recipe0702" -Context $storageContext

## manca powershell ed il modulo AZ sul worker