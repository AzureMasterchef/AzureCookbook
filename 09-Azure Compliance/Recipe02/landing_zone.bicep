targetScope = 'subscription'

param rgName string = 'Recipe09-02-rg'
param location string = 'eastus'
param storageAccountName string

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
}

module storage_with_pe 'storage.bicep' = [for i in range(1, 2): {
  name: 'storage${i}'
  scope: rg
  params: {
    location: rg.location
    storageAccountName: '${storageAccountName}0${i}'
  }
}]

