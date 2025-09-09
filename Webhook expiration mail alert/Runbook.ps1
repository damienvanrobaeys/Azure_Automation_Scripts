# Delay before expiration
$DaysBeforeExpiration = 90
# Converting delay to date
$Expiration_Date = (Get-Date).AddDays($DaysBeforeExpiration)

# If you want to send a notif by mail
$Send_Mail = $True # $True or $False
$Mail_From = ""
$Mail_To = ""
$CSV_File = "webhook expiration.csv"

# Notif content
$Notif_Title = "Azure Automation runbook with webhooks that expire in less than $DaysBeforeExpiration"
$Notif_Message = "Here is the list of runbook with webhooks that soon expired"

# Authentication with managed identity
Connect-AzAccount -Identity

# Getting automation account info
$automationAccount = Get-AzAutomationAccount
$automationAccountName = $automationAccount.AutomationAccountName
$resourceGroupName = $automationAccount.ResourceGroupName

# Getting all webhooks
$All_Webhooks = Get-AzAutomationWebhook  -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
If(-not $All_Webhooks) 
{
    EXIT
}

$Array_webhook = @()	

# Checking webhooks that soon expired
$Soon_Expired_Webhooks = $All_Webhooks | Where-Object { $_.ExpiryTime -lt $Expiration_Date }
ForEach($Webhook in $Soon_Expired_Webhooks)
{
    $Obj = New-Object PSObject
    Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Runbook" -Value $Webhook.RunbookName	
    Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Creation time" -Value $Webhook.CreationTime	
    Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Expiration time" -Value $Webhook.ExpiryTime
    Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Is enabled ?" -Value $Webhook.IsEnabled	
    Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Last execution" -Value $Webhook.LastInvokedTime	
    Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Resource Group" -Value $Webhook.ResourceGroupName	
    Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Automation account" -Value $Webhook.AutomationAccountName	
    $Array_webhook += $Obj  
}

If($Soon_Expired_Webhooks -eq $null) 
{
    EXIT
} 

If($Send_Mail -eq $True)
    {
		Connect-MgGraph -Identity | out-null

        $Soon_Expired_Webhook_Count = $Array_webhook.count

        $NewFile = New-Item -ItemType File -Name $CSV_File	
        $Array_webhook | export-csv $CSV_File -notype -Delimiter ";"
        $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File))
        $attachmentname = (Get-Item -Path $CSV_File).Name

        $Notif_Title = $Notif_Title + " ($Soon_Expired_Webhook_Count webhooks)"

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
    }
