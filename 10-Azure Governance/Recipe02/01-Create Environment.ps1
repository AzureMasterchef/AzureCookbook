$envPrefix = "Recipe10-02"
$location = "westeurope"
$rgName = "$envPrefix-rg"
$vmName = "AutoManaged-VM"

$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if(-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

New-AzResourceGroupDeployment -ResourceGroupName $rgName `
    -TemplateUri "https://raw.githubusercontent.com/AzureMasterchef/AzureCookbook/main/10-Azure%20Governance/Recipe02/main.bicep" `
    -vmName $vmName `
    -envPrefix $envPrefix