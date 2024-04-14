param location string = resourceGroup().location
param vmName string
param vmSize string = 'Standard_D2s_v3'
param envPrefix string
param adminUsername string = 'adminUser'
@secure()
param adminPassword string

resource hubvnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: '${envPrefix}-HUB-VNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/22'
      ]
    }
  }
}

resource fwsubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  name: 'AzureFirewallSubnet'
  parent: hubvnet
  properties: {
    addressPrefix: '10.0.0.0/26'
  }
}

resource spokevnet 'Microsoft.Network/virtualNetworks@2023-05-01' = [for i in range(1, 2): {
  name: '${envPrefix}-SPOKE${i}-VNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.${i}.0/24'
      ]
    }
  }
}]

resource spokesubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = [for (vnet, i) in spokevnet: {
  name: 'AzureFirewallSubnet'
  parent: spokevnet[i]
  properties: {
    addressPrefix: '192.168.${i}.0/26'
  }
}]



resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmName}-NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 128
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}
