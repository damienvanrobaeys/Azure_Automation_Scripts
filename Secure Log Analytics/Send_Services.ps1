$DCR = "" # id available in DCR > JSON view > immutableId
$Table = "ServicesSecureLA_CL" # custom log to create

$Get_Services = get-service | select-object @{label="TimeGenerated";Expression={get-date -Format "dddd MM/dd/yyyy HH:mm K"}},`
@{Label="DCR";Expression={$DCR}},`
@{Label="Table";Expression={$Table}},`
@{Label="DeviceName";Expression={$env:computername}},`
DisplayName, Name, Status, StartType

$PS_Version = ($psversiontable).PSVersion.Major
If($PS_Version -eq 7)
	{
		$Body_JSON = $Get_Services | ConvertTo-Json -AsArray;
	}Else{
		$Body_JSON = $Get_Services | ConvertTo-Json
	}

$Secure_header = @{message='Iam_a_bi_more_secure'}
$webhookURI = ""
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $Body_JSON -UseBasicParsing -Headers $Secure_header  

$StatusCode = $response.StatusCode
$Code_Return = @{
	"202" = "Request accepted"
	"400" = "Bad Request : The webhook has expired or is disabled"
	"404" = "Not Found: webhook, runbook or account wasn't found"
	"500" = "Internal Server Error: The URL was valid, but an error occurred. Resubmit the request"
}
$Error_code = $Code_Return.GetEnumerator() | Select-Object -Property Key,Value 
$Get_Error_Label = ($Error_code | Where {$_.Key -eq $StatusCode}).Value
$Get_Error_Label	