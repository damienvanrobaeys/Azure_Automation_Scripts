$SharePoint_SiteID = "" # sharepoint site id	
$SharePoint_Path = ""  # Something like this: "https://systanddeploy.sharepoint.com/sites/Support/Documents%20partages" 
$SharePoint_ExportFolder = "Windows/Apps_Report"  # folder where to upload file
$fileName = ""  # Something like this File.txt

Connect-MgGraph -Identity

$SharePoint_Graph_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives"  
$drives = Invoke-MgGraphRequest -Method GET -Uri $SharePoint_Graph_URL
$drive  = $drives.value | Where-Object {$_.webUrl -eq $SharePoint_Path}
$DriveID = $drive.id

If($DriveID -eq $null)
	{	
		EXIT
	}

$File_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/${SharePoint_ExportFolder}/${fileName}"
$File = Invoke-MgGraphRequest -Method GET -Uri $File_URL
$downloadUrl = $File.'@microsoft.graph.downloadUrl'

If($downloadUrl -eq $null)
	{	
		EXIT
	}

$Local_Download_Path = Join-Path -Path $env:TEMP -ChildPath $fileName
Invoke-WebRequest -Uri $downloadUrl -OutFile $Local_Download_Path
