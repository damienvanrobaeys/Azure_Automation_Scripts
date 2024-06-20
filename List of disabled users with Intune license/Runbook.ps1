#*****************************************************************
# Information about SharePoint app
$Tenant = ""  # tenant name
$ClientID = "" # azure app client id 
$Secret = '' # azure app secret
$SharePoint_SiteID = ""  # sharepoint site id	
$SharePoint_Path = ""  # sharepoint main path
$SharePoint_ExportFolder = "Windows/Logs"  # folder where to upload file
$CSV_Name = "Disabled_Users_With_Intune_Licence.csv"
$Exported_CSV_URL = ""

# Notif content
$Notif_Title = "Disabled users accounts with an Intune licence"
$Notif_Message = "Here is the list of disabled users accounts that still have Intune licence"

# If you want to send a notif by mail
$Send_Mail = $True # $True or $False
$Mail_From = ""
$Mail_To = ""

# Teams webhoot link
$Send_TeamsNotif = $True  # $True or $False
$Webhook_URL = "https://grtgaz.webhook.office.com/webhookb2/50149506-37f4-471a-a130-73ca735d90c3@081c4a9c-ea86-468c-9b4c-30d99d63df76/IncomingWebhook/e25f6205be6644a2b983a2300424d551/dcd2dea7-7f2e-421c-8eeb-63e37d3071bb"
$Color = "2874A6"
#*****************************************************************

# Authentication with the managed identity
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}


$Users_URL = 'https://graph.microsoft.com/v1.0/users?$select=userPrincipalName,DisplayName,accountEnabled,id&$filter=accountEnabled eq false'
$All_Users = Invoke-WebRequest -Uri $Users_URL -Method GET -Headers $Headers -UseBasicParsing 
$All_Users_JsonResponse = ($All_Users.Content | ConvertFrom-Json)
$Get_All_Users = $All_Users_JsonResponse.value

If($All_Users_JsonResponse.'@odata.nextLink')
{
    do {
        $URL = $All_Users_JsonResponse.'@odata.nextLink'
        $All_Users = Invoke-WebRequest -Uri $URL -Method GET -Headers $Headers -UseBasicParsing 
        $All_Users_JsonResponse = ($All_Users.Content | ConvertFrom-Json)
        $Get_All_Users += $All_Users_JsonResponse.value
    } until ($null -eq $All_Users_JsonResponse.'@odata.nextLink')
}


$Users_without_licences_Array = @()	
ForEach($User in $Get_All_Users)
	{
		$User_ID = $User.id
        $Licence_URL = "https://graph.microsoft.com/v1.0/users/$User_ID/licenseDetails"
        $Get_servicePlanName = Invoke-WebRequest -Uri $Licence_URL -Method GET -Headers $Headers -UseBasicParsing 
        $Get_servicePlanName_JsonResponse = ($Get_servicePlanName.Content | ConvertFrom-Json)
        $Users_Licence_Details = ($Get_servicePlanName_JsonResponse.value).servicePlans.servicePlanName
        If((($Users_Licence_Details | where-object { $_ -like "*INTUNE_*"}).count) -gt 0)	
			{
                $Obj = New-Object PSObject
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Display name" -Value $User.displayName	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "UPN" -Value $User.userPrincipalName	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "ID" -Value $User.id	
                $Users_without_licences_Array += $Obj           
			}     
	}

$NewFile = New-Item -ItemType File -Name $CSV_Name
$Users_without_licences_Array | select * | export-csv $CSV_Name -notype -Delimiter ";"


If($Send_TeamsNotif -eq $True)
{
    $Body = @{  
        client_id = $ClientID
        client_secret = $Secret
        scope = "https://graph.microsoft.com/.default"   
        grant_type = 'client_credentials'  
    }  
        
    $Graph_Url = "https://login.microsoftonline.com/$($Tenant).onmicrosoft.com/oauth2/v2.0/token"  
    Try
        {
            $AuthorizationRequest = Invoke-RestMethod -Uri $Graph_Url -Method "Post" -Body $Body  
        }
    Catch
        {
            EXIT
        }
        
    $Access_token = $AuthorizationRequest.Access_token  
    $Header = @{  
        Authorization = $AuthorizationRequest.access_token  
        "Content-Type"= "application/json"  
        'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"	
    }  

    $SharePoint_Graph_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives"  
    $BodyJSON = $Body | ConvertTo-Json -Compress  

    Try
        {
            $Result = Invoke-RestMethod -Uri $SharePoint_Graph_URL -Method 'GET' -Headers $Header -ContentType "application/json"   
        }
    Catch
        {
            EXIT
        }

    $DriveID = $Result.value| Where-Object {$_.webURL -eq $SharePoint_Path } | Select-Object id -ExpandProperty id  
    $FileName = $CSV_Name.Split("\")[-1]  
    $createUploadSessionUri = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$SharePoint_ExportFolder/$($fileName):/createUploadSession"

    Try
        {
            $uploadSession = Invoke-RestMethod -Uri $createUploadSessionUri -Method 'POST' -Headers $Header -ContentType "application/json" 
        }
    Catch
        {
            EXIT
        }

    $fileInBytes = [System.IO.File]::ReadAllBytes($CSV_Name)
    $fileLength = $fileInBytes.Length

    $headers = @{
    'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"
    }

    Try
        {
            $response = Invoke-RestMethod -Method 'Put' -Uri $uploadSession.uploadUrl -Body $fileInBytes -Headers $headers
        }
    Catch
        {
            EXIT
        }


$body = @"
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "$Notif_Title",
    "title": "$Notif_Title",

    "potentialAction": [{
        "@type": "OpenUri",
        "name": "View the list of users",
        "targets": [{
            "os": "default",
            "uri": "$Exported_CSV_URL"
        }]
    }],
    "sections": [
        {
            "text": "$Notif_Message"
        },	
    ]	

}
"@
Invoke-RestMethod -uri $Webhook_URL -Method Post -body $body -ContentType 'application/json'  
}
  

If($Send_Mail -eq $True)
    {
        $Text_Message = "$Notif_Message"

        Connect-MgGraph -Identity | out-null

        $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_Name))
        $attachmentname = (Get-Item -Path $CSV_Name).Name

        $params = @{
            Message         = @{
                Subject       = $Notif_Title
                Body          = @{
                    ContentType = "HTML"
                    Content     = $Text_Message
                }
                ToRecipients  = @(
                    @{
                        EmailAddress = @{
                            Address = $Mail_To
                        }
                    }
                )
                Attachments   = @(
                    @{
                        "@odata.type" = "#microsoft.graph.fileAttachment"
                        Name          = $attachmentname
                        ContentType   = "text/plain"
                        ContentBytes  = $attachmentmessage
                    }
                )
            }
            SaveToSentItems = "false"
        }

        Send-MgUserMail -UserId $Mail_From -BodyParameter $params                
    }
 