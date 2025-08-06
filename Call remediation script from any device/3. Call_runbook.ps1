$SerialNumber = (Get-WmiObject -Class Win32_Bios).SerialNumber
$params  = @{  
DeviceName = "$env:COMPUTERNAME"; 
SerialNumber = "$SerialNumber";
ScriptID = ""  
}  

$Secure_header = @{message='Iam_a_bit_more_secure'}
$webhookURI = ""

$body = ConvertTo-Json -InputObject $params  
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing -Headers $Secure_header 
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