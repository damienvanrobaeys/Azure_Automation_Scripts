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
4. Creating a Teams webhook (see below)
5. Choose if you want to display all devices from last x days/hours (starting at line 56)
6. Set a schedule on the Azure Automation like in the above delay (if you choose to send notif for all new devices during last 3 hours, set the schedule on 3 hours)
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
# Information about SharePoint app
$ClientID = ""
$Secret = ''            
$Site_URL = ""
$Folder_Location = ""

# Teams webhoot link
$Webhook = ""

# Teams notif design
$Title = "Autopilot devices to re-register"
$Message = " devices in Autopilot older than > 180 days"
$Button_Text = "Click here to see the list"
$Color = "2874A6"
$CSV_Name = "Obsolete_Autopilot.csv"
$CSV_Path = ""
#*****************************************************************

<#
In the next part we will:
1. Get all devices from the autopilot devices part where propery enrollmentState is not enrolled
2. For all devices, get the Azure ID
3. Get the property createdDateTime for all devices
4. Get all devices where createdDateTime is greater tha 180 days
5. Export datas to CSV
6. Upload CSV on SharePoint
7. Send a notification on Teams
#>

$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token

Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

# Graph URL to use
$Autopilot_URL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"

$autopilotEvents_info = Invoke-WebRequest -Uri $Autopilot_URL -Method GET -Headers $Headers -UseBasicParsing 
$Get_autopilotEvents_JsonResponse = ($autopilotEvents_info.Content | ConvertFrom-Json)
$Get_autopilotEvents = $Get_autopilotEvents_JsonResponse.value | where {$_.enrollmentState -ne "enrolled"}

If($Get_autopilotEvents_JsonResponse.'@odata.nextLink')
{
    do {
        $URL = $Get_autopilotEvents_JsonResponse.'@odata.nextLink'
        $autopilotEvents_info = Invoke-WebRequest -Uri $URL -Method GET -Headers $Headers -UseBasicParsing 
        $Get_autopilotEvents_JsonResponse = ($autopilotEvents_info.Content | ConvertFrom-Json)
        $Get_autopilotEvents += $Get_autopilotEvents_JsonResponse.value | where {$_.enrollmentState -ne "enrolled"}
    } until ($null -eq $Get_autopilotEvents_JsonResponse.'@odata.nextLink')
}

$Devices_Array = @()
ForEach($Detail in $Get_autopilotEvents)
    {
		$Azure_ID_from_Autopilot = $Detail.azureAdDeviceId
		$Azure_URL_From_AzureID = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$Azure_ID_from_Autopilot'"				
		$Get_Azure_Devices_info = Invoke-WebRequest -Uri $Azure_URL_From_AzureID -Method GET -Headers $Headers -UseBasicParsing
		$Get_Azure_Devices_JsonResponse = ($Get_Azure_Devices_info.Content | ConvertFrom-Json).value
		$Devices_to_reregister = $Get_Azure_Devices_JsonResponse | where {((Get-Date).Adddays(-180) -gt $_.createdDateTime)}

		$DisplayName = $Devices_to_reregister.displayName
		$createdDateTime = $Devices_to_reregister.createdDateTime

		$Device_SN = $Detail.serialNumber
		$Device_model = $Detail.model
		$Device_systemFamily = $Detail.systemFamily
		$Device_groupTag = $Detail.groupTag
		$Device_deploymentProfileAssignedDateTime = $Detail.deploymentProfileAssignedDateTime

		$Obj = New-Object PSObject
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "SN" -Value $Device_SN
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "DisplayName" -Value $DisplayName
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "createdDateTime" -Value $createdDateTime	
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Model family name" -Value $Device_systemFamily	
		Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Model" -Value $Device_model	
		$Devices_Array += $Obj		
    } 

$Devices_Count = $Devices_Array.count
$NewFile = New-Item -ItemType File -Name $CSV_Name
$Devices_Array | select * | export-csv $CSV_Name -notype -Delimiter ";"

Connect-PnPOnline -Url $Site_URL -ClientId $ClientID -ClientSecret $Secret -WarningAction Ignore
Add-PnPFile -Path $CSV_Name -Folder $Folder_Location | out-null
Disconnect-pnponline

$body = @"
{
    "@context": "https://schema.org/extensions",
    "@type": "MessageCard",
    "potentialAction": [
        {
            "@type": "OpenUri",
            "name": "$Button_Text",
            "targets": [
                {
                    "os": "default",
                    "uri": "$CSV_Path"
                }
            ]
        }
    ],
    "sections": [
        {
            "text": "$Devices_Count $Message"
        },	
    ],
    "summary": "$Title",
    "themeColor": "$Color",
    "title": "$Title"
}
"@

Invoke-RestMethod -uri $Webhook -Method Post -body $body -ContentType 'application/json'
