$envPrefix = "Recipe10-02"
$location = "westeurope"
$rgName = "$envPrefix-rg"
$vmName = "AutoManaged-VM"

$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if(-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

Invoke-WebRequest -URI "https://raw.githubusercontent.com/AzureMasterchef/AzureCookbook/main/10-Azure%20Governance/Recipe02/main.bicep" `
    -OutFile main.bicep

New-AzResourceGroupDeployment -ResourceGroupName $rgName `
    -TemplateFile .\main.bicep `
    -vmName $vmName `
    -envPrefix $envPrefix