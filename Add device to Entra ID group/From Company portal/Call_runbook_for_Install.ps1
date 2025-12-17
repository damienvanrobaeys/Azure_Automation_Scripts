$params  = @{  
DeviceName ="$env:COMPUTERNAME"; 
Action ="Add"  
}  

$webhookURI = ""

$body = ConvertTo-Json -InputObject $params  

$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing  
