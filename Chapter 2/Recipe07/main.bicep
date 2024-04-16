param location string = resourceGroup().location
param vmSize string = 'Standard_D2s_v3'
param envPrefix string
param adminUsername string = 'adminUser'
@secure()
param adminPassword string

var fwName = 'AZFW'
var wafName = 'WAF'

var vmList = [
  {
    name: 'VM1'
    ip: '192.168.0.10'
  }
  {
    name: 'VM2'
    ip: '172.16.0.10'
  } 
]

var spokeSubnetList = [
  {
    name: 'wafSubnet'
    subnetPrefix: '192.168.0.0/24'
  }
  {
    name: 'appSubnet'
    subnetPrefix: '192.168.1.0/24'
  }
]

var rtList = [
  {
    name: 'SPOKE-TO-HUB-RT'
    routes: [
      {
        name: 'to-app'
        addressPrefix: first(filter(spokeSubnetList, s => s.name == 'appSubnet')).subnetPrefix
      }
    ]
  }
  {
    name: 'HUB-TO-SPOKE-RT'
    routes: [
      {
        name: 'to-waf'
        addressPrefix: first(filter(spokeSubnetList, s => s.name == 'wafSubnet')).subnetPrefix
      }
    ]
  }
]

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'HUB-VNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/22'
      ]
    }
  }
}

resource fwSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: 'AzureFirewallSubnet'
  parent: hubVnet
  properties: {
    addressPrefix: '10.0.0.0/26'
  }
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = {
  name: '${fwName}-POLICY'
  location: location
  properties: {
    threatIntelMode: 'Alert'
    sku: {
      tier: 'Standard'
    }
  }
}

resource fwPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${fwName}-PIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fw 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: fwName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'AzureFirewallIpConfig'
        properties: {
          subnet: {
            id: fwSubnet.id
          }
          publicIPAddress: {
            id: fwPip.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: fwPolicy.id
    }
  }
}

output fwPublicIP string = fwPip.properties.ipAddress
output fwPrivateIP string = fw.properties.ipConfigurations[0].properties.privateIPAddress

resource rt 'Microsoft.Network/routeTables@2023-04-01' = [for rt in rtList: {  
  name: rt.name
  location: location
  properties: {
    routes: [
      for route in rt.routes: {
        name: route.name
        properties: {
          addressPrefix: route.addressPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fw.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
    disableBgpRoutePropagation: true
  }
}]

resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${envPrefix}-SPOKE-VNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/23'
      ]
    }
  }
}

resource spokeSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = [for (subnet, i) in spokeSubnetList: {
  name: subnet.name
  parent: spokeVnet
  properties: {
    addressPrefix: subnet.subnetPrefix
    routeTable: {
      id: rt[i].id
    }
  }
}]

resource peeringH2S 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  name: 'hub-to-spoke-peer'
  parent: hubVnet
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
  }
  dependsOn: [
    spokeSubnet[0]
    spokeSubnet[1]
  ]
}

resource peeringS2H 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  name: 'spoke-to-hub-peer'
  parent: spokeVnet
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
  dependsOn: [
    fwSubnet
  ]
}

resource waf 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-11-01' = {
  name: 'WAF'
  location: location
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 'maxRequestBodySizeInKb'
      fileUploadLimitInMb: 'fileUploadLimitInMb'
      state: 'Enabled'
      mode: 'Detection'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'ruleSetType'
          ruleSetVersion: 'ruleSetVersion'
        }
      ]
    }
  }
}


resource privDns 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'internal.azurecookbook.info'
  location: 'global'
}

resource privDnsLinkSpoke 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (spoke, i) in spokeList: {
  name: 'spoke${i+1}-link'
  parent: privDns
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spokeVnet[i].id
    }
    registrationEnabled: true
  }
}]

resource privDnsLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'hub-link'
  parent: privDns
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubVnet.id
    }
    registrationEnabled: false
  }
}
