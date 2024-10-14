# If you want to send a notif by mail
$Send_Mail = $fale # $True or $False
$Mail_From = ""
$Mail_To = ""

# Notif content
$Notif_Title = "Result of your KQL query on MDE"
$Notif_Message = "Here is the result of your KQL query on Microsoft Defender for Endpoint"

# KQL query to run
$My_Advanced_Query = @"
DeviceEvents 
|where  Timestamp > ago(3d)
| where ActionType == "UserAccountAddedToLocalGroup"
| summarize arg_max(Timestamp,*) by DeviceName
| limit 5
"@	

# Authenticating through the managed identity and getting Token
$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://api.securitycenter.microsoft.com'} 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token
Connect-AzAccount -Identity | out-null

# Creating header
$headers = @{
    'Content-Type' = 'application/json'
    Accept = 'application/json'
    Authorization = "Bearer $accessToken"
}

# MDE URL for running queries
$AdvancedQueries_URL = "https://api.securitycenter.microsoft.com/api/advancedqueries/run"

# Converting te KQL query to JSON
$Query_Body = ConvertTo-Json -InputObject @{ 'Query' = $My_Advanced_Query }

# Running the query using POST method
$Query_response = Invoke-WebRequest -Method Post -Uri $AdvancedQueries_URL -Headers $headers -Body $Query_Body -ErrorAction Stop -UseBasicParsing 

# Converting result to JSON
$Query_response_JSON =  $Query_response | ConvertFrom-Json
$My_Results = $Query_response_JSON.Results

If($Send_Mail -eq $True)
    {
		$CSV_File = "MDE_KQL_Results.csv"
		$NewFile = New-Item -ItemType File -Name $CSV_File
		$My_Results | select DeviceName, Timestamp, InitiatingProcessAccountSid | export-csv $CSV_File -notype -Delimiter ";" 		
		
        $Text_Message = "$Notif_Message"

        Connect-MgGraph -Identity | out-null

        $attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($CSV_File))
        $attachmentname = (Get-Item -Path $CSV_File).Name

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
else
	{
		$My_Results | select DeviceName, Timestamp, InitiatingProcessAccountSid
	}

