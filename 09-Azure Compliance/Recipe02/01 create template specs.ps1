$envPrefix = "Recipe09-02"
$location = "westeurope"
$rgName = "$envPrefix-rg"

# Prepare the resource group
$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if(-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
}

# Get the bicep file from the git repo
if (Get-Item .\storage_with_pe.bicep) {
    Remove-Item .\storage_with_pe.bicep
}

Invoke-WebRequest -URI "https://raw.githubusercontent.com/AzureMasterchef/AzureCookbook/main/09-Azure%20Compliance/Recipe02/storage_with_pe.bicep" `
    -OutFile storage_with_pe.bicep

if (Get-Item .\landing_zone.bicep) {
    Remove-Item .\landing_zone.bicep
}

Invoke-WebRequest -URI "https://raw.githubusercontent.com/AzureMasterchef/AzureCookbook/main/09-Azure%20Compliance/Recipe02/landing_zone.bicep" `
    -OutFile landing_zone.bicep

# Create a template spec for landing_zone.bicep
$templateSpec_v1 = New-AzTemplateSpec -Name "$envPrefix-landingZone-ts" `
                    -Version 1.0 `
                    -ResourceGroupName $rg.ResourceGroupName `
                    -Location $location `
                    -TemplateFile ./landing_zone.bicep

# Create a deployment stack starting from the template spec. The deployment stack targets the subscription, since landing_zone.bicep create a resource group at that scope
$storageAccountName = "recipe0902stg$(Get-Random -Minimum 000000 -Maximum 999999)"

$parameters = @{
    rgName = "$envPrefix-target-rg"
    storageAccountName = $storageAccountName
    $location = $location
}

New-AzSubscriptionDeploymentStack  `
    -Name "$envPrefix-DeploymentStack" `
    -DeploymentResourceGroupName  "$envPrefix-managed-RG" `
    -TemplateSpec $templateSpec_v1.Id `
    -TemplateParameterObject $parameters `
    -DeleteAll `
    -DenySettingsApplyToChildScopes `
    -DenySettingsMode "DenyDelete"

# !!!!!!!!!!!!!!!!!!
# Execute the remaing part of the script after applying a change to landing_zone.bicep

# Generate a new version of the Template Spec
$templateSpec_v2 = New-AzTemplateSpec -Name "$envPrefix-landingZone-ts" `
                    -Version 2.0 `
                    -ResourceGroupName $rg.ResourceGroupName `
                    -Location $location `
                    -TemplateFile ./landing_zone.bicep

Set-AzSubscriptionDeploymentStack  `
    -Name "$envPrefix-DeploymentStack" `
    -DeploymentResourceGroupName  "$envPrefix-managed-RG" `
    -TemplateSpec $templateSpec_v2.Id `
    -TemplateParameterObject $parameters `
    -DeleteAll `
    -DenySettingsApplyToChildScopes `
    -DenySettingsMode "DenyDelete"

# Delete the deployment stack and all the related resources
Remove-AzSubscriptionDeploymentStack `
  -Name "$envPrefix-DeploymentStack"