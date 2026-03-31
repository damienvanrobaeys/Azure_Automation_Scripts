# Your tenant id (in Azure Portal, under Azure Entra ID > Overview )
$TenantID=""

# Name of the manage identity or enterprise application
$DisplayNameOfMSI="" 

# Permission to set to the managed identity
$Permissions = @('Mail.send','ThreatHunting.Read.All')

# Check if module is installed and if not install it
If(!(Get-Installedmodule Microsoft.Graph.Applications)){Install-Module Microsoft.Graph.Applications}Else{Import-Module Microsoft.Graph.Applications}

# Authenticate through Connect-MgGraph cmdlet
Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory -TenantId $TenantID

# Get info about the managed identity we have created
$MSI = Get-MgServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'"

# Retrieve the Microsoft Graph SDK application on Entra ID
# AppId: 00000003-0000-0000-c000-000000000000
$API = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'"

# Check all permissions that can be added through the Microsoft Graph app
# We will then get the id of AppRoles we need to add
$AppRoles = $API.AppRoles | Where-Object {($_.Value -in $Permissions) -and ($_.AllowedMemberTypes -contains "Application")}

# Set permissions on the managed identity
ForEach($Role in $AppRoles){`
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $MSI.Id -PrincipalId $MSI.Id -AppRoleId $Role.Id -ResourceId $API.Id`
}