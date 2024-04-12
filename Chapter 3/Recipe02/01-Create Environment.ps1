$envPrefix = "Recipe03-02"
$location = "westeurope"
$rgName = "$envPrefix-rg"

$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if (-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

$subnetList = @()
$subnetList += New-AzVirtualNetworkSubnetConfig -Name "subnet1" -AddressPrefix "10.0.0.0/25"
$subnetList += New-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -AddressPrefix "10.0.0.128/25"

$vnet = New-AzVirtualNetwork -ResourceGroupName $rgName `
    -Name "$envPrefix-VNET" `
    -AddressPrefix "10.0.0.0/24" `
    -Location $location `
    -Subnet $subnetList

# Create a bastion to connect to the VM
$pip = New-AzPublicIpAddress -ResourceGroupName $rgName `
        -Name "$envPrefix-PIP" `
        -AllocationMethod Static `
        -Sku Standard `
        -Location $location

New-AzBastion -ResourceGroupName $rgName `
    -Name "$envPrefix-BASTION" `
    -VirtualNetworkId $vnet.Id `
    -Sku Basic `
    -PublicIpAddressId $pip.Id `
    -ScaleUnit 2

# Create the VM and its disk
$adminPassword = Read-Host -Prompt "Enter the password for the VM" -AsSecureString
$credential = New-Object PSCredential "adminUser", $adminPassword
$nic = New-AzNetworkInterface -ResourceGroupName $rgName `
    -Name "$envPrefix-VM-NIC" `
    -Location $location `
    -SubnetId $vnet.Subnets[0].Id `
    -EnableAcceleratedNetworking
$diskconfig = New-AzDiskConfig `
                -Location $location `
                -DiskSizeGB 2048 `
                -DiskIOPSReadWrite 8000 `
                -DiskMBpsReadWrite 550 `
                -AccountType PremiumV2_LRS `
                -LogicalSectorSize 4096 `
                -CreateOption Empty
$dataDisk = New-AzDisk `
                -ResourceGroupName $rgName `
                -DiskName "$envPrefix-VM-DataDisk" `
                -Disk $diskconfig
$vmConfig = New-AzVMConfig -VMName "$envPrefix-VM" `
                -VMSize "Standard_E4bds_v5"
$vmConfig = Set-AzVMOperatingSystem -Windows `
                -ComputerName "$envPrefix-VM" `
                -Credential $credential `
                -ProvisionVMAgent `
                -EnableAutoUpdate
$vmConfig = Set-AzVMSourceImage -PublisherName "MicrosoftWindowsServer" `
                -Offer "WindowsServer" `
                -Skus "2022-datacenter-azure-edition" `
                -Version "latest"
$vmConfig = Add-AzVMNetworkInterface -Id $nic.Id
$vmConfig = Set-AzVMOSDisk -CreateOption FromImage -Windows
$vmConfig = Add-AzVMDataDisk -Caching None `
                -CreateOption Empty `
                -DiskSizeInGB 2048 `
                -ManagedDiskId $dataDisk.Id

$vmConfig | New-AzVM -ResourceGroupName $rgName -Location $location

# New-AzVM -ResourceGroupName $rgName `
#     -Name "Demo-VM" `
#     -Location $location `
#     -VirtualNetworkName "$envPrefix-vnet" `
#     -SubnetName "subnet1" `
#     -OpenPorts 3389 `
#     -Credential (New-Object PSCredential "adminUser", $adminPassword) `
#     -Image Win2022AzureEdition `
#     -Size "Standard_E4bds_v5" `
#     -
        

