<# 
More info in this link: https://www.systanddeploy.com/2024/11/automatically-populate-device-group.html

Modules to use:
Connect-MgGraph: Microsoft.Graph.Authentication
Get-MgGroupMember: Microsoft.Graph.Groups
New-MgGroupMember: Microsoft.Graph.Groups
#>


# Fill the variable 
# Target group where to add devices
$Target_Group_ID = "75b2f518-4007-4f60-8ae3-9db3bf247813" 
# Intune remediation script ID
$Remediation_Script_ID = "dca4d52f-78bb-4333-996a-a8b9f963b0ea" 

# Function to add devices with registry key to the target Entra ID group
Function Add_Devices
	{
		param(
		$Device
		)

		# Checking if the device is a managed device
		$Get_Device_Info = Get-MgDeviceManagementManagedDevice -Filter "contains(deviceName,'$Device')"
		
		# Getting the device azureADDeviceId
		$EntraID_Device_ID = $Get_Device_Info.azureADDeviceId

		# Getting device info from Entra ID
		$EntraID_Device_ID = Get-MgDevice -Filter "deviceId eq '$EntraID_Device_ID'"

		# Getting device object ID
		$Device_ObjectId = $EntraID_Device_ID.Id
		
		# Checking if the device is already member of the group
		$IsMember = Get-MgGroupMember -GroupId $Target_Group_ID -All | Where-Object { $_.Id -eq $Device_ObjectId }
		
		# Add the device to the target group
		If($IsMember) 
		{
			Write-Output "Device $Device is already member in the group"
		}Else{
			# Add the device in the group
			New-MgGroupMember -GroupId $Target_Group_ID -DirectoryObjectId $Device_ObjectId
			Write-Output "Device $Device has been added to the target group"				
		}
	}

# Authenticating to the managed Identity
Connect-MgGraph -Identity -NoWelcome 

# Getting results from the remediation script
$Remediations_URL = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$Remediation_Script_ID/deviceRunStates?`$select=detectionState,lastStateUpdateDateTime,preRemediationDetectionScriptOutput%0A&`$expand=managedDevice(`$select=deviceName)"
$Get_Scripts = (Invoke-MgGraphRequest -Uri $Remediations_URL  -Method GET).value
# Getting all devices with output "Status OK"
$Updated_values = $Get_Scripts | where {$_.preRemediationDetectionScriptOutput -like "*Status OK*"}
ForEach($Obj in $Updated_values)
{
	$deviceName = $obj.managedDevice.deviceName
	Add_Devices -Device $deviceName
}










