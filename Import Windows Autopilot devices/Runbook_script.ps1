<#
Author: Damien VAN ROBAEYS
Website: https://www.systanddeploy.com
Twitter: @syst_and_deploy
Mail: damien.vanrobaeys@gmail.com
#>

<#Prerequisites
1. Add module pnp.powershell in Azure Automation
2. Use a managed identity: see an example there: https://www.systanddeploy.com/2022/01/scheduling-purge-of-azure-ad-group.html
3. Create a SharePoint app for uploading the file: https://www.systanddeploy.com/2022/02/how-to-use-teamssharepoint-as-logs.html
4. Set a schedule on the Azure Automation 
#>

#*****************************************************************
# Information about SharePoint app
$ClientID = ""
$Secret = ''    
$Site_URL = ""
$Folder_Location = ""

# Exception group ID
$HardwareHash_Exception_Group_ID = ""
#*****************************************************************

# Getting a token and authenticating to your tenant using the managed identity
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

Connect-PnPOnline -Url $Site_URL -ClientId $ClientID -ClientSecret $Secret -WarningAction Ignore

Function Add_ToGroup
{
	param(
	$DeviceID	
	)

	# Get the Azure AD Object ID of the device using the azureADDeviceId provided just before 
	$Azure_URL_From_AzureID = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$DeviceID'"				
	$Get_Azure_Devices_info = Invoke-WebRequest -Uri $Azure_URL_From_AzureID -Method GET -Headers $Headers -UseBasicParsing
	$Get_Azure_Devices_JsonResponse = ($Get_Azure_Devices_info.Content | ConvertFrom-Json).value
	$Device_ObjectID = $Get_Azure_Devices_JsonResponse.id

	# Check if the device is already in the group using the Object ID
	$Get_Group_Members = (Get-AzADGroupMember -GroupObjectId $HardwareHash_Exception_Group_ID) | where {$_.id -eq $Device_ObjectID}
	If($Get_Group_Members -eq $null)
		{
			# The device is not in the group so we will add it
			Add-AzADGroupMember -TargetGroupObjectId $HardwareHash_Exception_Group_ID -MemberObjectId $Device_ObjectID		
			"The device has been added in the group: $Device_ObjectID"
		}
	Else
		{
			# The device is already in the group
			"The device already exists in the group: $Device_ObjectID"
		}

}

$Autopilot_URL = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/import"	

$Get_All_TXT = Get-PnPFolderItem -FolderSiteRelativeUrl "Documents partages/Windows/HardwareHash" | where {$_.Name -like "*txt*"}
$File_Array = @()	
ForEach($File in $Get_All_TXT)
	{
		$File_URL = $File.ServerRelativeUrl
		$File_Name = $File.Name
		Get-PnPFile -Url $File_URL -Path $env:temp -FileName $File_Name -AsFile -Force
		$Automation_File_Path = "$env:temp\$File_Name"
		$Get_Hardware_Hash = get-content $Automation_File_Path
		$DeviceName = $File_Name.Split("_")[0]
		$Get_SerialNumber = $File_Name.Split("_")[1]
		$Device_URL_FromSN = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter' + "=contains(serialNumber,'$Get_SerialNumber')"
		$Get_Device_Infos = Invoke-WebRequest -Uri $Device_URL_FromSN -Method GET -Headers $Headers -UseBasicParsing         
        $Device_Infos_JsonResponse = ($Get_Device_Infos.Content | ConvertFrom-Json)
        $Device_Infos = $Device_Infos_JsonResponse.value
		$Device_azureAdDeviceId = $Device_Infos.azureAdDeviceId
		
		$Get_Autopilot_Devices_URL = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?$filter' + "=contains(serialNumber,'$Get_SerialNumber')"
		
        $Autopilot_info = Invoke-WebRequest -Uri $Get_Autopilot_Devices_URL -Method GET -Headers $Headers -UseBasicParsing         
        $Autopilot_info_JsonResponse = ($Autopilot_info.Content | ConvertFrom-Json)
		$Check_Device_InAutopilot = $Autopilot_info_JsonResponse.value		
        $Device_azureAdDeviceId_from_Autopilot = $Check_Device_InAutopilot.azureAdDeviceId
		If($Device_azureAdDeviceId_from_Autopilot -eq $null)
			{
				"$Get_SerialNumber not in Autopilot"

$Device_Hash_ToImport = @"
{
"importedWindowsAutopilotDeviceIdentities":[{"serialNumber":"$Get_SerialNumber",
"productKey":"",
"hardwareIdentifier":"$Get_Hardware_Hash"}]
}
"@

                Try
                    {
        				Invoke-WebRequest -Uri $Autopilot_URL -Method POST -Headers $Headers -UseBasicParsing -Body $Device_Hash_ToImport -ContentType "application/json" | out-null
                        $Hash_Import_Status = $True                              
                    }
                Catch
                    {
                        $Reported_Error = $error[0].exception.message
                        $Hash_Import_Status = $False
                    }

                If($Hash_Import_Status -eq $True)
                    {
						"removing file"
                        Remove-PnPFile -ServerRelativeUrl $File_URL -Force
						Add_ToGroup -DeviceID $Device_azureAdDeviceId
                    }
                Else
                    {
                        "fail"
                    }
			}
		Else
			{
				"$Get_SerialNumber already in Autopilot"
                Remove-PnPFile -ServerRelativeUrl $File_URL -Force
				Add_ToGroup -DeviceID $Device_azureAdDeviceId				
			}          	
	}
