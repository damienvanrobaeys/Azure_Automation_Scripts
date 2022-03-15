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

# Graph URL to use
$AzureAD_Devices_URL = "https://graph.microsoft.com/beta/Devices"
$Intune_Devices_URL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
$Monitor_Devices_URL = "https://graph.microsoft.com/beta/deviceManagement/autopilotEvents"

$headers = @{'Authorization'="Bearer " + $accessToken}

# Get information from Autopilot devices part
$autopilotEvents_info = Invoke-WebRequest -Uri $Monitor_Devices_URL -Method GET -Headers $Headers -UseBasicParsing 
$Get_autopilotEvents = ($autopilotEvents_info.Content | ConvertFrom-Json).value

# Get information from Intune part
$Get_DevicesFromIntune_info = Invoke-WebRequest -Uri $Intune_Devices_URL -Method GET -Headers $Headers -UseBasicParsing 
$Get_DevicesFromIntune_JsonResponse = ($Get_DevicesFromIntune_info.Content | ConvertFrom-Json).value

# Get information from Azure AD part
$Get_DevicesFromAz_info = Invoke-WebRequest -Uri $AzureAD_Devices_URL -Method GET -Headers $Headers -UseBasicParsing 
$Get_DevicesFromAz_JsonResponse = ($Get_DevicesFromAz_info.Content | ConvertFrom-Json).value

<#
In the next part we will:
1. List all devices from the autopilot devices part
2. Get the approriate serial number
3. Get the appropriate ID from Intune part using the serial number
4. Get the appropriate ID from Azure part using the intune device ID
#>

# Add automatically all devices from autopilot monitoring part
# $AutopilotEvents = $Get_autopilotEvents

# Devices added during last 3 hours
$AutopilotEvents = $Get_autopilotEvents | where {((Get-Date).Addhours(-3) -lt $_.deploymentEndDateTime)}

# Devices added during last 1 days
# $AutopilotEvents = $Get_autopilotEvents | where {((Get-Date).Adddays(-1) -lt $_.deploymentEndDateTime)}

$AutopilotEvents.deploymentEndDateTime
ForEach($Monitor_Device in $AutopilotEvents)
	{
		If($Monitor_Device.deploymentEndDateTime -ne $null)
			{
				$deviceId = $Monitor_Device.deviceId	
				$SerialNumber = $Monitor_Device.deviceSerialNumber				

				$Get_Device_azureADDeviceId = ($Get_DevicesFromIntune_JsonResponse | where {$_.serialNumber -eq $SerialNumber}).azureADDeviceId				
				$Device_ObjectID = ($Get_DevicesFromAz_JsonResponse | where {$_.deviceId -eq $Get_Device_azureADDeviceId}).ID

				$Get_Group_Members = (Get-AzADGroupMember -GroupObjectId $Deployment_Completed_Group_ID) | where {$_.ID -eq $Device_ObjectID}
				If($Get_Group_Members -eq $null)
					{
						Add-AzADGroupMember -TargetGroupObjectId $Deployment_Completed_Group_ID -MemberObjectId $Device_ObjectID		
						"device added: $Device_ObjectID"
					}
				Else
					{
						"device already exists: $Device_ObjectID"
					}	
			}			
	}                    
