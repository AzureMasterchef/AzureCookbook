$envPrefix = "Recipe07-02"
$location = "westeurope"
$rgName = "$envPrefix-rg"

$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if(-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

# Upload the main.bicep file from the Chapter 07/Recipe02 folder to cloud shell

New-AzResourceGroupDeployment -ResourceGroupName $rgName `
    -TemplateFile .\main.bicep `
    -envPrefix $envPrefix `
    -Location $location