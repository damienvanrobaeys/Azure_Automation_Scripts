<#
Author: Damien VAN ROBAEYS
Website: https://www.systanddeploy.com
Twitter: @syst_and_deploy
Mail: damien.vanrobaeys@gmail.com
#>

<#
Prerequisites for the purge
1. Create a SharePoint application
2. fill SharePoint app in below variables

Prerequisites for the Teams notification
1. Create a webhook on a Teams channel (see below)
2. Add the webhook URL in variable Webhook_URL

To create a webhook proceed as below:
1. Go to your channel
2. Click on the ...
3. Click on Connectors
4. Go to Incoming Webhook
5. Type a name
6. Click on Create
7. Copy the Webhook path
#>

# Variables to fill for SharePoint app
$ClientID = ""
$Secret = ''	
$Site_URL = ""		
$Purge_Delay = 90
		
# Information about Teams webhook
$Purge_Notif = $True
$Webhook_URL = ""
	
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

Function Purge_SharePoint
	{
		param(
		[switch]$Folder, 
		[switch]$File,
		[switch]$Recursive,	
		[switch]$NoRecycle,				
		[int]$Delay,
		$ContentToClean
		)
		
		If($Folder -and $File)
			{
				write-host "Please use parameter File or Folder not both"
				Break
			}

		$Recycle_Status = $True
		If($NoRecycle)
			{
				$Recycle_Status = $False
			}
			
		$Recursive_Status = $False
		If($Recursive)
			{
				$Recursive_Status = $True
			}			

		"Keep in Recycle bin after deletion: $Recycle_Status"		
		"Recursive status: $Recursive_Status"		
		"Items will be deleted after: $Delay days"		

		Try
			{
				Connect-PnPOnline -Url $Site_URL -ClientId $ClientID -ClientSecret $Secret -WarningAction Ignore									
				"Connecting to SharePoint: SUCCESS"				
			}
		Catch
			{
				"Connecting to SharePoint: Failed"
			}	

		$Current_date = Get-Date			
		$Get_Content = Get-PnPFolderItem -FolderSiteRelativeUrl $ContentToClean -ItemType File -Recursive:$Recursive_Status					
		$Item_Count = 0
		ForEach($Item in $Get_Content)
			{
				$Item_Modif_Date = $Item.TimeLastModified
				$Item_Name = $Item.Name
				$Last_Modif_in_days = ($Current_date - $Item_Modif_Date).days

				
				$Item_URL = $Item.ServerRelativeUrl
				If($Last_Modif_in_days -ge $Delay)
					{
						$Item_Count = $Item_Count + 1
						"Removing item: $Item_Name (Last modification: $Last_Modif_in_days)"				
					}
			}

		If($Purge_Notif -eq $True)
			{
				$Title_Message = "SharePoint cleaning notif"					
				$Text_Message = "<b>SharePoint location</b>: $ContentToClean<br>
				<b>Delay</b>: $Delay days<br>
				<b>Files deleted</b>: $Item_Count<br>
				"
				Send_Notif -Text $Text_Message -Title $Title_Message | out-null
			}			
	}

# Purge files but keeps in recycle bin
Purge_SharePoint -ContentToClean <Folder on SharePoint> -Delay $Purge_Delay

# Purge files but keeps in recycle bin
Purge_SharePoint -ContentToClean <Folder on SharePoint> -Delay $Purge_Delay -NoRecycle

# Example
# Purge_SharePoint -ContentToClean "Documents partages/Windows/Logs" -Delay $Purge_Delay
