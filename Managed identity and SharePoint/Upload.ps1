$SharePoint_SiteID = "" # sharepoint site id	
$SharePoint_Path = ""  # Something like this: "https://systanddeploy.sharepoint.com/sites/Support/Documents%20partages" 
$SharePoint_ExportFolder = "Windows/Apps_Report"  # folder where to upload file
$fileName = ""  # Something like this File.txt

Connect-MgGraph -Identity 

$File_Path = Join-Path -Path $env:TEMP -ChildPath $fileName 
$fileContent | Set-Content -Path $File_Path -Encoding UTF8
$fileBytes = [System.IO.File]::ReadAllBytes($File_Path)

$SharePoint_Graph_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives"  
$drives = Invoke-MgGraphRequest -Method GET -Uri $SharePoint_Graph_URL

$Get_Current_Drive = $drives.value | Where-Object {$_.webURL -eq $SharePoint_Path}
$DriveID = $Get_Current_Drive.id

$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$SharePoint_ExportFolder/$($fileName):/content"
Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes




