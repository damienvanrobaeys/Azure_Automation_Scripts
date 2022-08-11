<#
Author: Damien VAN ROBAEYS
Website: https://www.systanddeploy.com
Twitter: @syst_and_deploy
Mail: damien.vanrobaeys@gmail.com
#>

<#Prerequisites
1. Create a webhook on a Teams channel (see below)
2. Add the webhook URL in variable Webhook_URL
3. Use a managed identity: see an example there: https://www.systanddeploy.com/2022/01/scheduling-purge-of-azure-ad-group.html
4. Choose if you want to display all devices from last x days/hours (starting at line 60)
5. Set a schedule on the Azure Automation like in the above delay (if you choose to send notif for all new devices during last 3 hours, set the schedule on 3 hours)
#>

<# To create a webhook proceed as below:
1. Go to your channel
2. Click on the ...
3. Click on Connectors
4. Go to Incoming Webhook
5. Type a name
6. Click on Create
7. Copy the Webhook path
#>

#*****************************************************************
# Information about Teams webhook
$Webhook_URL = ""
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

# Devices added during last x hours
# $AutopilotEvents = $Get_autopilotEvents | where {((Get-Date).Addhours(-3) -lt $_.deploymentEndDateTime)}

# Devices added during last x days
$AutopilotEvents = $Get_autopilotEvents | where {((Get-Date).Adddays(-1) -lt $_.deploymentEndDateTime)}

# Function used to send notif on Teams
Function Send_Notif
{
		param(
		$Text,	
		$Title
		)

		$Body = @{
		'text'= $Text
		'Title'= $Title
		'themeColor'= "#2874A6"
		}

		$Params = @{
				 Headers = @{'accept'='application/json'}
				 Body = $Body | ConvertTo-Json
				 Method = 'Post'
				 URI = $Webhook_URL 
		}
		Invoke-RestMethod @Params

}	
 
ForEach($Monitor_Device in $AutopilotEvents)
	{
		If($Monitor_Device.deploymentEndDateTime -ne $null)
			{
				$deviceId = $Monitor_Device.deviceId	
				$SerialNumber = $Monitor_Device.deviceSerialNumber		
				$EndDateTime = $Monitor_Device.deploymentEndDateTime
				$StartDateTime = $Monitor_Device.deploymentStartDateTime
				
				<# Variables not used there
				$accountSetupDuration = $Monitor_Device.accountSetupDuration
				$SetupDuration = $Monitor_Device.deviceSetupDuration
				$PreparationDuration = $Monitor_Device.devicePreparationDuration
				$TotalDuration = $Monitor_Device.deploymentTotalDuration
				$deploymentDuration = $Monitor_Device.deploymentDuration	
				#>

				$StartTime = $StartDateTime | out-string
				$Formated_StartDateTime = [datetime]$StartTime

				$EndTime = $EndDateTime | out-string
				$Formated_EndDateTime = [datetime]$EndTime				
				
				$Total_Duration = $Formated_EndDateTime - $Formated_StartDateTime
				$Formated_Duration = $Total_Duration.ToString("dd' days 'hh' hours 'mm' minutes 'ss' seconds'")

				$Intune_Info = ($Get_DevicesFromIntune_JsonResponse | where {$_.serialNumber -eq $SerialNumber})
				$Get_Device_azureADDeviceId = $Intune_Info.azureADDeviceId
				$Device_ObjectID = ($Get_DevicesFromAz_JsonResponse | where {$_.deviceId -eq $Get_Device_azureADDeviceId}).ID

				$deviceName = $Intune_Info.deviceName
				$osVersion = $Intune_Info.osVersion
				$model = $Intune_Info.model
				$manufacturer = $Intune_Info.manufacturer
				$serialNumber = $Intune_Info.serialNumber
				$userDisplayName = $Intune_Info.userDisplayName
                                                                    					
				$Title_Message = "A new Windows Autopilot device has been installed"					
				$Text_Message = "<b>Device name</b>: $deviceName<br>
				<b>Start time</b>: $Formated_StartDateTime<br>
				<b>End time</b>: $Formated_EndDateTime<br>
				<b>Deployment duration</b>: $Formated_Duration<br>						
				<b>OS</b>: $osVersion<br>
				<b>Model</b>: $model<br>
				<b>Manufacturer</b>: $manufacturer<br>
				<b>Serial number</b>: $serialNumber<br>
				<b>User</b>: $userDisplayName
				"
				Send_Notif -Text $Text_Message -Title $Title_Message			
			}			
	}     