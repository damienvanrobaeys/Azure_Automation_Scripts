$managedIdentityId = ''
$Permissions = @('AdvancedQuery.Read.All')
Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory -TenantId $TenantID
$msi = Get-MgServicePrincipal -Filter "Id eq '$managedIdentityId'"
$mde = Get-MgServicePrincipal -Filter "AppId eq 'fc780465-2017-40d4-a0c5-307022471b92'"
foreach ($Perm in $Permissions) {
	$Permission = $mde.AppRoles | where Value -Like $Perm | Select-Object -First 1

	If($Permission){
		New-MgServicePrincipalAppRoleAssignment `
			-ServicePrincipalId $msi.Id `
			-AppRoleId $permission.Id `
			-PrincipalId $msi.Id `
			-ResourceId $mde.Id
	}
}
Disconnect-MgGraph
