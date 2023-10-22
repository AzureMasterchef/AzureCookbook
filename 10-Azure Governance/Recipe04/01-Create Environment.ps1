$envPrefix = "Recipe10-04"
$location = "westeurope"
$rgName = "$envPrefix-rg"
$vmName = "AutoUpdated-VM"

$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if(-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

Invoke-WebRequest -URI "https://raw.githubusercontent.com/AzureMasterchef/AzureCookbook/main/10-Azure%20Governance/Recipe04/main.bicep" `
    -OutFile main.bicep

New-AzResourceGroupDeployment -ResourceGroupName $rgName `
    -TemplateFile .\main.bicep `
    -vmName $vmName `
    -envPrefix $envPrefix