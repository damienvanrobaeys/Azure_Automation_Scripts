<#
Author: Damien VAN ROBAEYS
Website: https://www.systanddeploy.com
Twitter: @syst_and_deploy
Mail: damien.vanrobaeys@gmail.com
#>

<#Prerequisites
1. Add group ID where to add your devices when they are installed in variable $Deployment_Completed_Group_ID (see line 17)
2. Use a managed identity: see an example there: https://www.systanddeploy.com/2022/01/scheduling-purge-of-azure-ad-group.html
3. Choose if you want to display all devices from last x days/hours (starting at line 56)
4. Set a schedule on the Azure Automation like in the above delay (if you choose to send notif for all new devices during last 3 hours, set the schedule on 3 hours)
#>

#*****************************************************************
# Group ID where to add devices once autopilot is completed
$Deployment_Completed_Group_ID = ""
#*****************************************************************

$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token

Connect-AzAccount -Identity

$headers = @{'Authorization'="Bearer " + $accessToken}

$Monitor_Devices_URL = "https://graph.microsoft.com/beta/deviceManagement/autopilotEvents"

do {
	# Get information from Autopilot devices part
	try{
		$autopilotEvents_info = Invoke-RestMethod -Uri $Monitor_Devices_URL -Method GET -Headers $headers
		$Get_autopilotEvents = $autopilotEvents_info.value
		$NextLinkAP = $autopilotEvents_info.'@odata.nextLink'
		$AutopilotEvents = $Get_autopilotEvents
		# Devices added during last 3 hours
        	# $AutopilotEvents = $Get_autopilotEvents | where {((Get-Date).Addhours(-3) -lt $_.deploymentEndDateTime)}
        	# Devices added during last 1 days
        	# $AutopilotEvents = $Get_autopilotEvents | where {((Get-Date).Adddays(-1) -lt $_.deploymentEndDateTime)}
		ForEach($Monitor_Device in $AutopilotEvents){
			If($null -ne $Monitor_Device.deploymentEndDateTime){
				$SerialNumber = $Monitor_Device.deviceSerialNumber
				If($null -ne $SerialNumber){
					try{
						$Intune_Devices_URL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=serialNumber eq '" + ($SerialNumber -replace '\s','') +"'"
						$Get_DeviceFromIntune_info = Invoke-RestMethod -Uri $Intune_Devices_URL -Method GET -Headers $headers
						ForEach($Get_Device_azureADDeviceId in $Get_DeviceFromIntune_info.Value){
							$Get_Device_azureADDeviceId = $Get_Device_azureADDeviceId.azureADDeviceId
							try{ 
								$AzureAD_Devices_URL ="https://graph.microsoft.com/beta/Devices?`$filter=deviceId eq '" + $Get_Device_azureADDeviceId + "'"
								$Get_DevicesFromAz_info = Invoke-RestMethod -Uri $AzureAD_Devices_URL -Method GET -Headers $headers
								$Device_ObjectID = $Get_DevicesFromAz_info.Value.id
								If($null -ne $Device_ObjectID){
									$Get_Group_Members = Get-AzADGroupMember -GroupObjectId $Deployment_Completed_Group_ID | Where-Object {$_.id -eq $Device_ObjectID}
									If($null -eq $Get_Group_Members){
											try {
												Add-AzADGroupMember -TargetGroupObjectId $Deployment_Completed_Group_ID -MemberObjectId $Device_ObjectID
												"device added: $Device_ObjectID"
											} catch {
												Write-Output ("Failed to Add-AzADGroupMember")
											}
									} else {
											"device already exists: " + $Get_DevicesFromAz_info.Value.DisplayName + " Serial Number: " + $SerialNumber
									}
								} else {
									Write-Output ("Device_ObjectID is null")
								}
							} catch {
								Write-Output  ("Failed to Get information from Azure AD")
							}
						}
					} catch {
						Write-Output  ("Failed to Get information from Intune")
					}
				} else {
					"Failed deployment for DeviceId: " + $Monitor_Device.deviceId + " userPrincipalName: " + $Monitor_Device.userPrincipalName
				}
			} else {
				Write-Output ("deploymentEndDateTime was null")
			}
		}
	} catch {
		Write-Output  ("Failed getting Autopilot events")
	}
} while ($null -ne $NextLinkAP)
