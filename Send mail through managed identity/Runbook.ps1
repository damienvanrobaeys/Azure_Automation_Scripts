# BASIC MAIL
$Mail_From = ""
$Mail_To = ""

$Notif_Title = "Mail sent through Azure Automation"
$Notif_Message = "Luke, I am your message"

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
	}
	SaveToSentItems = "false"
}

Connect-MgGraph -Identity 
Send-MgUserMail -UserId $Mail_From -BodyParameter $params                


# MAIL WITH ATTACHMENT
$Mail_From = ""
$Mail_To = ""

$Notif_Title = "Mail sent through Azure Automation"
$Notif_Message = "Luke, I am your message"

$My_CSV = "MyFile.csv"
New-Item -ItemType File -Name $My_CSV

$attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($My_CSV))
$attachmentname = (Get-Item -Path $My_CSV).Name

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
Connect-MgGraph -Identity 
Send-MgUserMail -UserId $Mail_From -BodyParameter $params  
