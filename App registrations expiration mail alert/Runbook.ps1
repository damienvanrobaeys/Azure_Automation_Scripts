# Expiration delay
$Expiration_Delay = 90

# If you want to send a notif by mail
$Send_Mail = $True # $True or $False
$Mail_From = ""
$Mail_To = ""
$CSV_File_Secret = "Azure app secret expiration.csv"
$CSV_File_Certificate = "Azure app certificate expiration.csv"

# Notif content
$Notif_Title_Secret = "Azure app registrations with secret that soon expired"
$Notif_Message_Secret = "Here is the list of Azure app registrations with secret that soon expired"

$Notif_Title_Certificate = "Azure app registrations with certificate that soon expired"
$Notif_Message_Certificate = "Here is the list of Azure app registrations with certificate that soon expired"

$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://graph.microsoft.com/' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity
$headers = @{'Authorization'="Bearer " + $accessToken}

$AppsRegistration_URL = "https://graph.microsoft.com/v1.0/applications?`$select=id,appId,displayName,passwordCredentials,KeyCredentials,CreatedDateTime"

$All_Apps = Invoke-WebRequest -Uri $AppsRegistration_URL -Method GET -Headers $Headers -UseBasicParsing 
$All_Apps_JsonResponse = ($All_Apps.Content | ConvertFrom-Json)
$Get_All_Apps = $All_Apps_JsonResponse.value
If($All_Apps_JsonResponse.'@odata.nextLink')
{
    do {
        $URL = $All_Apps_JsonResponse.'@odata.nextLink'
        $All_Apps = Invoke-WebRequest -Uri $URL -Method GET -Headers $Headers -UseBasicParsing 
        $All_Apps_JsonResponse = ($All_Apps.Content | ConvertFrom-Json)
        $Get_All_Apps += $All_Apps_JsonResponse.value
    } until ($null -eq $All_Apps_JsonResponse.'@odata.nextLink')
}

$Array_secret = @()	
$Array_certificate = @()	
$Today = get-date
$Apps_With_Credentials = $Get_All_Apps | where {(($_.PasswordCredentials.count -ne 0) -or ($_.KeyCredentials.count -ne 0))}
ForEach($App in $Apps_With_Credentials)
{	
	$App_ID = $App.id
	$App_Name = $App.displayname
	$App_CreatedDateTime = $App.CreatedDateTime
	$App_Secret = $App.PasswordCredentials
	$App_Certificate = $App.KeyCredentials	
	If($App_Secret.count -gt 0)
	{
		ForEach($Secret in $App_Secret)
		{
			$Secret_Name = $Secret.DisplayName
			If($Secret_Name -eq $null){$Secret_Name = "Empty name"}
			[datetime]$Secret_EndDateTime = $Secret.EndDateTime
			
			$Diff_date_secret = ($Secret_EndDateTime - $Today).days
			If($Secret_EndDateTime -gt $Today)
			{
				$Secret_State = "Not expired"
			}
			else
			{
				$Secret_State = "Expired"
			}

			$Obj = New-Object PSObject
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Application name" -Value $App_Name	
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Created on" -Value $App_CreatedDateTime
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Secret name" -Value $Secret_Name
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Secret state" -Value $Secret_State
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Secret end date" -Value $Secret_EndDateTime
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Days before expiration" -Value $Diff_date_secret
			$Array_secret += $Obj  	
		}
	}
	
	If($App_Certificate.count -gt 0)
	{
		ForEach($Cert in $App_Certificate)
		{
			$Cert_Name = $Cert.DisplayName
			If($Cert_Name -eq $null){$Cert_Name = "Empty name"}
			[datetime]$Cert_EndDateTime = $Cert.EndDateTime
		
			$Diff_date_certificate = ($Cert_EndDateTime - $Today).days
			If($Cert_EndDateTime -gt $Today)
			{
				$Certificate_State = "Not expired"
			}
			else
			{
				$Certificate_State = "Expired"
			}
			
			$Obj = New-Object PSObject
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Application name" -Value $App_Name	
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Created on" -Value $App_CreatedDateTime
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Certificate name" -Value $Cert_Name
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Certificate state" -Value $Certificate_State
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Certificate end date" -Value $Cert_EndDateTime	
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Days before expiration" -Value $Diff_date_certificate
			$Array_certificate += $Obj 
		}		
	}
}

If($Send_Mail -eq $True)
    {
	Connect-MgGraph -Identity | out-null
		
        $Soon_Expired_Secret = $Array_secret | where {$_."Secret state" -eq "Not expired" -and $_."Days before expiration" -le $Expiration_Delay} | select "Application name", "Created on", "Secret name", "Secret name","Secret end date", "Days before expiration"
        $Soon_Expired_Certificate = $Array_certificate | where {$_."Certificate state" -eq "Not expired" -and $_."Days before expiration" -le $Expiration_Delay} | select "Application name","Created on", "Certificate name","Certificate end date", "Days before expiration"

        $Soon_Expired_Secret_Count = $Soon_Expired_Secret.count
        $Soon_Expired_Certificate_Count = $Soon_Expired_Certificate.count

        If($Soon_Expired_Secret_Count -gt 0)
            {
        	$NewFile = New-Item -ItemType File -Name $CSV_File_Secret	
                $Soon_Expired_Secret | export-csv $CSV_File_Secret -notype -Delimiter ";"
                $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File_Secret))
                $attachmentname = (Get-Item -Path $CSV_File_Secret).Name

                $Notif_Title_Secret = $Notif_Title_Secret + " ($Soon_Expired_Secret_Count app secrets)"

                $Text_Message = "$Notif_Message_Secret" 

                $params = @{
                    Message         = @{
                        Subject       = $Notif_Title_Secret
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
			  	

         If($Soon_Expired_Certificate_Count -gt 0)
            {
        	$NewFile = New-Item -ItemType File -Name $CSV_File_Certificate
                $Soon_Expired_Certificate | export-csv $CSV_File_Certificate -notype -Delimiter ";"
                $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File_Certificate))
                $attachmentname = (Get-Item -Path $CSV_File_Certificate).Name

                $Notif_Title_Certificate = $Notif_Title_Certificate + " ($Soon_Expired_Certificate_Count app certificates)"

                $params = @{
                    Message         = @{
                        Subject       = $Notif_Title_Certificate
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
    }
