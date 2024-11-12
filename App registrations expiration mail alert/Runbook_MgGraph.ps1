# If you want to send a notif by mail
$Send_Mail = $True # $True or $False
$Mail_From = ""
$Mail_To = ""
$CSV_File_Secret = "Azure app secret expiration.csv"
$CSV_File_Certificate = "Azure app certificate expiration.csv"

# Notif content
$Notif_Title_Secret = "Azure applications with secret that soon expired"
$Notif_Message_Secret = "Here is the list of Azure applications with secret that soon expired"

$Notif_Title_Certificate = "Azure applications with certificate that soon expired"
$Notif_Message_Certificate = "Here is the list of Azure applications with certificate that soon expired"

Connect-MgGraph -Identity | out-null

$Array_secret = @()	
$Array_certificate = @()	
$Today = get-date
$Apps_With_Credentials = Get-MgApplication -all | where {(($_.PasswordCredentials.count -ne 0) -or ($_.KeyCredentials.count -ne 0))}
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
			$Secret_StartDateTime = $Secret.StartDateTime
			$Secret_EndDateTime = $Secret.EndDateTime
			
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
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Secret start date" -Value $Secret_EndDateTime
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
			$Cert_StartDateTime = $Cert.StartDateTime
			$Cert_EndDateTime = $Cert.EndDateTime
			
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
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Certificate start date" -Value $Cert_StartDateTime
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Certificate end date" -Value $Cert_EndDateTime	
			Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Days before expiration" -Value $Diff_date_certificate
			$Array_certificate += $Obj 
		}		
	}
}

$Soon_Expired_Secret = $Array_secret | where {$_."Secret state" -eq "Not expired" -and $_."Days before expiration" -le 90}
$Soon_Expired_Certificate = $Array_certificate | where {$_."Certificate state" -eq "Not expired" -and $_."Days before expiration" -le 90}

$Soon_Expired_Secret_Count = $Soon_Expired_Secret.count
$Soon_Expired_Certificate_Count = $Soon_Expired_Certificate.count

If($Send_Mail -eq $True)
    {
        If($Soon_Expired_Secret_Count -gt 0)
            {
        		$NewFile = New-Item -ItemType File -Name $CSV_File_Secret	
                $Soon_Expired_Secret | export-csv $CSV_File_Secret -notype -Delimiter ";"
                $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File_Secret))
                $attachmentname = (Get-Item -Path $CSV_File_Secret).Name

                $Notif_Title_Secret = $Notif_Title_Secret + " ($Soon_Expired_Secret_Count app secrets)"

                $params = @{
                    Message         = @{
                        Subject       = $Notif_Title_Secret
                        Body          = @{
                            ContentType = "HTML"
                            Content     = $Notif_Message_Secret
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

                $Notif_Title_Certificate = $Notif_Message_Certificate + " ($Soon_Expired_Certificate_Count app certificates)"

                $params = @{
                    Message         = @{
                        Subject       = $Notif_Title_Certificate
                        Body          = @{
                            ContentType = "HTML"
                            Content     = $Notif_Message_Certificate
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
