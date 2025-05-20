#*****************************************************************
$Users_Activity_Delay = 30

# Notif content
$Notif_Title = "Users without Intune licence"
$Notif_Message = "Here is the list of users with an activity during last $Users_Activity_Delay days and without Intune licence"
$CSV_Name = "Users without Intune licence.csv"

# If you want to send a notif by mail
$Mail_From = ""
$Mail_To = ""
#*****************************************************************

$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

$Users_URL = 'https://graph.microsoft.com/v1.0/users?$select=userPrincipalName,DisplayName,userType,accountEnabled,signInSessionsValidFromDateTime,id&$filter=accountEnabled eq true'

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
$Get_All_Users = $Get_All_Users | where {$_.userType -eq "Member"}
ForEach($User in $Get_All_Users | where {(((Get-Date).Adddays(-$Users_Activity_Delay)) -lt ($_.signInSessionsValidFromDateTime))})
	{
		$User_ID = $User.id
        $Licence_URL = "https://graph.microsoft.com/v1.0/users/$User_ID/licenseDetails"
        $Get_servicePlanName = Invoke-WebRequest -Uri $Licence_URL -Method GET -Headers $Headers -UseBasicParsing 
        $Get_servicePlanName_JsonResponse = ($Get_servicePlanName.Content | ConvertFrom-Json)
        $Users_Licence_Details = ($Get_servicePlanName_JsonResponse.value).servicePlans.servicePlanName
        If((($Users_Licence_Details | where-object {$_ -like "*INTUNE_*"}).count) -eq 0)	
			{
                $Obj = New-Object PSObject
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Display name" -Value $User.displayName
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "User type" -Value $User.userType	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "UPN" -Value $User.userPrincipalName	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "ID" -Value $User.id	
                Add-Member -InputObject $Obj -MemberType NoteProperty -Name "signInSessionsValidFromDateTime" -Value $User.signInSessionsValidFromDateTime	                
                $Users_without_licences_Array += $Obj           
			}     
	}

$Users_without_licence_count = $Users_without_licences_Array.count    
$NewFile = New-Item -ItemType File -Name $CSV_Name
$Users_without_licences_Array | select * | export-csv $CSV_Name -notype -Delimiter ";"

Connect-MgGraph -Identity | out-null

$attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_Name))
$attachmentname = (Get-Item -Path $CSV_Name).Name

$Notif_Title = $Notif_Title + " ($Users_without_licence_count users)"

$params = @{
	Message         = @{
		Subject       = $Notif_Title
		Body          = @{
			ContentType = "HTML"
			Content     = $Notif_Message
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
