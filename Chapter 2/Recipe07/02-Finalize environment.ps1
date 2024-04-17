$envPrefix = "Recipe02-07"
$rgName = "$envPrefix-rg"
$location = "westeurope"

# KV management
$kvUpn = Read-host -Prompt "Please provide your user principal name (UPN) for the Key Vault access policy"
$kv = Get-AzKeyVault -ResourceGroupName $rgName | Select-Object -First 1
$kv | Set-AzKeyVaultAccessPolicy -UserPrincipalName $kvUpn -PermissionsToCertificates all -PermissionsToSecrets all

$usrMsi = New-AzUserAssignedIdentity -ResourceGroupName $rgName -Name "$envPrefix-ManagedIdentity" -Location $location
$kv | Set-AzKeyVaultAccessPolicy -ObjectId $usrMsi.PrincipalId -PermissionsToCertificates get -PermissionsToSecrets get

$certName = Read-host -Prompt "Please provide the name of your certificate file (ex. recipe0207-wildcard.pfx)"
$certPwd = Read-Host -Prompt "Please provide the password for the certificate" -AsSecureString
$kv = Get-AzKeyVault -ResourceGroupName $rgName | Select-Object -First 1
Import-AzKeyVaultCertificate -VaultName $kv.VaultName -Name "recipe0207-wildcard" -FilePath ".\$certName" -Password $certPwd

# App Gateway
$vnet = Get-AzVirtualNetwork -Name "SPOKE-VNET" -ResourceGroupName $rgName
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "wafSubnet" -VirtualNetwork $vnet
$webApp = Get-AzWebApp -ResourceGroupName $rgName | Select-Object -First 1
$kv = Get-AzKeyVault -ResourceGroupName $rgName | Select-Object -First 1
$certSecret = Get-AzKeyVaultSecret -VaultName $kv.VaultName -Name 'recipe0207-wildcard'
$certSecretId = $certSecret.Id.Replace($certSecret.Version, "")
$pip = Get-AzPublicIpAddress -Name "WAF-PIP" -ResourceGroupName $rgName
$usrId = Get-AzUserAssignedIdentity -ResourceGroupName $rgName | Select-Object -First 1

$ipConfig = New-AzApplicationGatewayIPConfiguration -Name "appGwIpConfig" -Subnet $subnet
$frontendPort = New-AzApplicationGatewayFrontendPort -Name "appGwFrontendPort" -Port 443
$frontendIp = New-AzApplicationGatewayFrontendIPConfig -Name "appGwFrontendIp" -PublicIPAddress $pip
$backendAddressPool = New-AzApplicationGatewayBackendAddressPool -Name "appGwBackendPool" -BackendFqdns $webApp.DefaultHostName
$backendHttpSettings = New-AzApplicationGatewayBackendHttpSettings -Name "appGwBackendHttpSettings" -Port 443 -Protocol Https -CookieBasedAffinity Enabled -RequestTimeout 30 -PickHostNameFromBackendAddress
$appGwSslCert = New-AzApplicationGatewaySslCertificate -KeyVaultSecretId $certSecretId -Name $certSecret.Name
$listener = New-AzApplicationGatewayHttpListener -Name "appGwHttpListener" -Protocol Https -SslCertificate $appGwSslCert -FrontendIPConfiguration $frontendIp -FrontendPort $frontendPort
$rule = New-AzApplicationGatewayRequestRoutingRule -Name "rule1" -RuleType Basic -BackendHttpSettings $backendHttpSettings -HttpListener $listener -BackendAddressPool $backendAddressPool -Priority 1
$wafConfig = New-AzApplicationGatewayWebApplicationFirewallConfiguration -Enabled $true -FirewallMode "Detection" -RuleSetType "OWASP" -RuleSetVersion "3.2"
$sku = New-AzApplicationGatewaySku -Name WAF_v2 -Tier WAF_v2 -Capacity 1

$appGw = New-AzApplicationGateway -Name "APPGW" -ResourceGroupName $rgName -Location $location -BackendAddressPools $backendAddressPool `
            -BackendHttpSettingsCollection $backendHttpSettings -FrontendIpConfigurations $frontendIp -GatewayIpConfigurations $ipConfig `
            -FrontendPorts $frontendPort -HttpListeners $listener -RequestRoutingRules $rule -Sku $sku -WebApplicationFirewallConfiguration $wafConfig `
            -UserAssignedIdentityId $usrId.Id -SslCertificates $appGwSslCert

# Attach spoke route table to wafSubnet
$vnet = Get-AzVirtualNetwork -Name "SPOKE-VNET" -ResourceGroupName $rgName
$subnets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet
($subnets | Where-Object Name -eq "wafSubnet").RouteTable = Get-AzRouteTable -Name "WAF-RT" -ResourceGroupName $rgName
($subnets | Where-Object Name -eq "appSubnet").RouteTable = Get-AzRouteTable -Name "APP-RT" -ResourceGroupName $rgName
$vnet | Set-AzVirtualNetwork

# Firewall Policy
$usrId = Get-AzUserAssignedIdentity -ResourceGroupName $rgName | Select-Object -First 1
$kv = Get-AzKeyVault -ResourceGroupName $rgName | Select-Object -First 1
$certSecret = Get-AzKeyVaultSecret -VaultName $kv.VaultName -Name 'recipe0207-wildcard'
$certSecretId = $certSecret.Id.Replace($certSecret.Version, "")
$fwPolicy = Get-AzFirewallPolicy -Name "AZFW-POLICY" -ResourceGroupName $rgName
$fwPolicy | Set-AzFirewallPolicy -ThreatIntelMode Deny `
                -IntrusionDetection (New-AzFirewallPolicyIntrusionDetection -Mode Deny) `
                -DnsSetting (New-AzFirewallPolicyDnsSetting -EnableProxy) `
                -UserAssignedIdentityId $usrId.Id `
                ## uncomment the following line to enable TLS inspection
                #-TransportSecurityName "recipe0207-wildcard" `
                #-TransportSecurityKeyVaultSecretId $certSecretId

$rule1 = New-AzFirewallPolicyNetworkRule -Name "waf-to-app" `
            -SourceAddress "192.168.0.0/24" `
            -DestinationAddress "192.168.1.0/24" `
            -DestinationPort "443" `
            -Protocol "TCP"
$rule2 = New-AzFirewallPolicyNetworkRule -Name "app-to-waf" `
            -SourceAddress "192.168.1.0/24" `
            -DestinationAddress "192.168.0.0/24" `
            -DestinationPort "443" `
            -Protocol "TCP"
$ruleCollection = New-AzFirewallPolicyFilterRuleCollection  -Name "Allow-app" `
                    -Priority 100 `
                    -ActionType "Allow" `
                    -Rule $rule1, $rule2
Set-AzFirewallPolicyRuleCollectionGroup -Name "Recipe02-07-Network" `
    -RuleCollection $ruleCollection `
    -Priority 100 -FirewallPolicyObject $fwPolicy
                