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
					 Headers = @{'Content-Type'='application/json'}
					 Body = $Body | ConvertTo-Json
					 Method = 'Post'
					 URI = $Webhook_URL 
			}
			Invoke-RestMethod @Params
            $Params.Body
                                       

	}	

#*****************************************************************
$workspace_ID = ""
$Notif_Title = "Devices with local admin account(s)"
$Notif_Message = "Here is the list of devices with local admin accounts during the last 7 days <br>*Creation: date when the account has been created <br>*Creator: Who created the account"

# If you want to send a notif by mail
$Send_Mail = $True # $True or $False
$Mail_From = ""
$Mail_To = ""

# If you want to send a notif on a Teams channel
$Send_TeamsNotif = $True  # $True or $False
$Webhook_URL = ""
$Color = "2874A6"
#*****************************************************************

$url = $env:IDENTITY_ENDPOINT  
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headers.Add("X-IDENTITY-HEADER", $env:IDENTITY_HEADER) 
$headers.Add("Metadata", "True") 
$body = @{resource='https://api.loganalytics.io' } 
$script:accessToken = (Invoke-RestMethod $url -Method 'POST' -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $body ).access_token

Connect-AzAccount -Identity | out-null

$headers = @{
    'Content-Type' = 'application/json'
    Accept = 'application/json'
    Authorization = "Bearer $accessToken"
}

$AdvancedQueries_URL = "https://api.loganalytics.io/v1/workspaces/$workspace_ID/query"
$My_Query = 'LocalAdmin_Details_CL | where CreationDate_t > ago(2d) | where Account_s <> "Administrateur" and Account_s !contains "defaultuser" | summarize arg_max(TimeGenerated,*) by DeviceName_s, Account_s | extend CreationDateFormat = format_datetime(CreationDate_t,"MM-dd-yyyy hh:mm") | project Device=DeviceName_s, Account=Account_s, Description=Description_s,Creator=AddedBy_s, Creation=CreationDateFormat'
$Query_Body = @{query = $My_Query} | ConvertTo-Json
$Query_response = Invoke-WebRequest -Method Post -Uri $AdvancedQueries_URL -Headers $headers -Body $Query_Body -UseBasicParsing 
$resultsTable = $Query_response.Content | ConvertFrom-Json
$count = 0
foreach ($table in $resultsTable.Tables) {
$count += $table.Rows.Count
}
$results = New-Object object[] $count
$i = 0;
foreach ($table in $resultsTable.Tables) {
    foreach ($row in $table.Rows) {
        $properties = @{}
        for ($columnNum=0; $columnNum -lt $table.Columns.Count; $columnNum++) {
            $properties[$table.Columns[$columnNum].name] = $row[$columnNum]
        }      
        $results[$i] = (New-Object PSObject -Property $properties)
        $null = $i++
    }
}

$results_count = $results.count
If($results_count -gt 0)
    {
        $style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
        $style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
        $style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
        $style = $style + "TD{border: 1px solid black; padding: 5px; }"
        $style = $style + "</style>"        

        $results = $results | select Device, Account, Description, Creation, Creator
        $results_Table = $results | ConvertTo-HTML -Fragment #-Head $style
        $results_Table = $results | ConvertTo-HTML -Head $style
        $results_Table = $results_Table.Replace("<table>","<table border='1'>")
        $Text_Message = "$Notif_Message<br>
        $results_Table
        "

        $Notif_Title = $Notif_Title + ": " + $results_count

        If($Send_Mail -eq $True)
            {
                Connect-MgGraph -Identity | out-null
                $params = @{
                    message = @{
                        subject = $Notif_Title
                        body = @{
                            contentType = "HTML"
                            content = $Text_Message
                        }
                        toRecipients = @(
                            @{
                                emailAddress = @{
                                    address = $Mail_To
                                }
                            }
                        )
                    }
                    saveToSentItems = "false"
                }

                Send-MgUserMail -UserId $Mail_From -BodyParameter $params                
            }

        If($Send_TeamsNotif -eq $True)
            {
                Send_Notif -Text $Text_Message -Title $Notif_Title  | out-null
            }
    }



