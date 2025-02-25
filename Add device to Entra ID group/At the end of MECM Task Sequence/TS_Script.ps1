$params  = @{  
DeviceName ="$env:COMPUTERNAME"
} 

$TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
$webhookURI = $TSEnv.Value("TS_Automation_Webhook")

$body = ConvertTo-Json -InputObject $params  
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing  