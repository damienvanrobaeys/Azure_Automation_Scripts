<#
Author: Damien VAN ROBAEYS
Website: https://www.systanddeploy.com
Twitter: @syst_and_deploy
Mail: damien.vanrobaeys@gmail.com
#>

<#Prerequisites
1. Use a managed identity: see an example there: https://www.systanddeploy.com/2022/01/scheduling-purge-of-azure-ad-group.html
2. Creating a Teams webhook (see below)
3. Set a schedule on the Azure Automation like in the above delay (if you choose to send notif for all new devices during last 3 hours, set the schedule on 3 hours)
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


# Function to send Teams notif
Function Send_Notif
	{
			param(
			$Text,	
			$Title
			)

			$Body = @{
			'text'= $Text
			'Title'= $Title
			'themeColor'= "$Color"
			}

			$Params = @{
					 Headers = @{'accept'='application/json'}
					 Body = $Body | ConvertTo-Json
					 Method = 'Post'
					 URI = $Webhook_URL 
			}
			Invoke-RestMethod @Params
	}	

#*****************************************************************
# 							Part to fill
#*****************************************************************

# Teams webhoot link
$Webhook_URL = ""

# Choose the top x devices (default is 50)
$Top_count = 50

# Teams notif design
$Notif_Title = "Top 50 devices with BSOD"
$Notif_Message = "Here is the list of top 50 devices with BSOD on the last 30 days"

$Color = "2874A6"
#*****************************************************************

# Getting a token
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token

# Authentication
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

# Graph URL to use
$Top50_BSOD_URL = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsDevicePerformance?dtFilter=all&`$orderBy=blueScreenCount%20desc&`$top=$Top_count&`$filter=blueScreenCount%20ge%201%20and%20blueScreenCount%20le%2050"
$StartupHistory_url = "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsDeviceStartupHistory?" + '$filter=deviceId%20eq%20%27' + "$DeviceID%27"		

# Getting BSOD info
$All_BSOD = Invoke-WebRequest -Uri $Top50_BSOD_URL -Method GET -Headers $Headers -UseBasicParsing 
$All_BSOD_JsonResponse = ($All_BSOD.Content | ConvertFrom-Json)
$Get_All_BSOD = $All_BSOD_JsonResponse.value

$BSOD_Array = @()		
ForEach($BSOD in $Get_All_BSOD)
	{
		$Device_Model = $BSOD.model
		$Device_Name = $BSOD.deviceName
		$BSOD_Count = $BSOD.blueScreenCount
		$DeviceID = $BSOD.id
	
        $Get_StartupHistory = Invoke-WebRequest -Uri $StartupHistory_url -Method GET -Headers $Headers -UseBasicParsing 
        $Get_BSOD_JsonResponse = ($Get_StartupHistory.Content | ConvertFrom-Json)
        $Get_BSOD = ($Get_BSOD_JsonResponse.value | Where {$_.restartCategory -eq "blueScreen"})[-1]	
        
        $Last_BSOD_Date = [datetime]($Get_BSOD.startTime)
		$Last_BSOD_Code = $Get_BSOD.restartStopCode
		$OS = $Get_BSOD.operatingSystemVersion		
		
		$BSOD_Obj = New-Object PSObject
		Add-Member -InputObject $BSOD_Obj -MemberType NoteProperty -Name "Device" -Value $Device_Name		
		Add-Member -InputObject $BSOD_Obj -MemberType NoteProperty -Name "Model" -Value $Device_Model		
		Add-Member -InputObject $BSOD_Obj -MemberType NoteProperty -Name "Count" -Value $BSOD_Count		
		Add-Member -InputObject $BSOD_Obj -MemberType NoteProperty -Name "OS version" -Value $OS				
		Add-Member -InputObject $BSOD_Obj -MemberType NoteProperty -Name "Last BSOD" -Value $Last_BSOD_Date		
		Add-Member -InputObject $BSOD_Obj -MemberType NoteProperty -Name "Last code" -Value $Last_BSOD_Code
		$BSOD_Array += $BSOD_Obj	
	}

$BSOD_Table = $BSOD_Array  | ConvertTo-HTML -Fragment
$BSOD_Table = $BSOD_Table.Replace("<table>","<table border='1'>")
$Text_Message = "$Notif_Message<br><br>
$BSOD_Table
"

Send_Notif -Text $Text_Message -Title $Notif_Title  | out-null	