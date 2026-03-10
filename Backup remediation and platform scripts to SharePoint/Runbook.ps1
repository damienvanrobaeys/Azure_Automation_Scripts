$Backup_RemediationScripts = $true
$Backup_PlatformScripts = $true

$SharePoint_SiteID = ""  # sharepoint site id	
$SharePoint_Path = ""  # Something like this: "https://systanddeploy.sharepoint.com/sites/Support/Documents%20partages" 
$SharePoint_Graph_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives"  
$SharePoint_ExportFolder = "Windows/Intune_Scripts"  # folder where to upload file

Connect-MgGraph -Identity 

$drives = Invoke-MgGraphRequest -Method GET -Uri $SharePoint_Graph_URL
$Get_Current_Drive = $drives.value | Where-Object {$_.webURL -eq $SharePoint_Path}
$DriveID = $Get_Current_Drive.id

If($Backup_RemediationScripts -eq $true){
$Remediation_Array = @()
$Remediations_sources = "$env:TEMP\Backup_Remediations"	
$Remediations_URL = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
$Get_Remediation_Scripts = (Invoke-MgGraphRequest -Uri $Remediations_URL  -Method GET).value	
ForEach($Script in $Get_Remediation_Scripts)
{
	$Script_displayName = $Script.displayName
	$Script_Name = $Script_displayName.TrimEnd(" ")
	$Script_Sources_Path = "$Remediations_sources\$Script_Name"
	$Script_Id = $Script.id
	$Script_info = "$Remediations_URL/$Script_Id"
	$Get_Script_info = (Invoke-MgGraphRequest -Uri $Script_info  -Method GET -SkipHttpErrorCheck)	

	$Detection_Content = $Get_Script_info.detectionScriptContent	
	If($Detection_Content -eq $null){
		$Detection_Exists = $False
		$Detection_File_Path = Join-Path -Path $Script_Sources_Path -ChildPath "Detection.ps1" 		
		new-item $Detection_File_Path -force -type file | Out-Null
		$fileBytes = [System.IO.File]::ReadAllBytes($Detection_File_Path)				
		
		$Export_Folder = "$SharePoint_ExportFolder\Remediations\$Script_displayName"
		$fileName = "Detection.ps1"
		$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$Export_Folder/$($fileName):/content"
		Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes
	}Else{
		$Detection_Exists = $True
		$Detection_Decoded = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Detection_Content))
		$Detection_File_Path = Join-Path -Path $Script_Sources_Path -ChildPath "Detection.ps1" 
		new-item $Detection_File_Path -force -type file | Out-Null
		$Detection_Decoded | out-file $Detection_File_Path
		$fileBytes = [System.IO.File]::ReadAllBytes($Detection_File_Path)

		$Export_Folder = "$SharePoint_ExportFolder\Remediations\$Script_displayName"
		$fileName = "Detection.ps1"
		$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$Export_Folder/$($fileName):/content"
		Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes | Out-Null
	}
	
	$Remediation_content = $Get_Script_info.remediationScriptContent
	If($Remediation_content -eq $null){
		$Remediation_Exists = $False
		$Remediation_File_Path = Join-Path -Path $Script_Sources_Path -ChildPath "Detection.ps1" 
		new-item $Remediation_File_Path -force -type file | Out-Null
		$fileBytes = [System.IO.File]::ReadAllBytes($Remediation_File_Path)
		
		$Export_Folder = "$SharePoint_ExportFolder\Remediations\$Script_displayName"
		$fileName = "Remediation.ps1"
		$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$Export_Folder/$($fileName):/content"
		Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes
	}Else{
		$Remediation_Exists = $True
		$Remediation_File = "$Script_displayName\Remediation.ps1"
		$Remediation_Decoded = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($Remediation_content))
		$Remediation_File_Path = Join-Path -Path $Script_Sources_Path -ChildPath "Remediation.ps1" 
		new-item $Remediation_File_Path -force -type file | Out-Null
		$Remediation_Decoded | out-file $Remediation_File_Path
		$fileBytes = [System.IO.File]::ReadAllBytes($Remediation_File_Path)	

		$Export_Folder = "$SharePoint_ExportFolder\Remediations\$Script_displayName"
		$fileName = "Remediation.ps1"
		$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$Export_Folder/$($fileName):/content"
		Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes | Out-Null
	}	
	
	$Obj = [PSCustomObject]@{
		Name     				= $Script_Name
		ID     					= $Script_Id
		Publisher    			= $Script.publisher
		Description    		    = $Script.description
		DetectionExists     	= $Detection_Exists
		RemediationExists     	= $Remediation_Exists
		runAs32Bit     			= $Script.runAs32Bit
		RunAsAccount    		= $Script.runAsAccount
		LastModifiedDateTime    = $Script.lastModifiedDateTime
		CreatedDateTime    		= $Script.createdDateTime
	}	
	$Remediation_Array += $Obj
}

	$Remediation_Summary = "$Remediations_sources\Remediation_scripts.csv"
	new-item $Remediation_Summary -force -type file
	$File_Full_Path = $File_Path.FullName
	$Remediation_Array | export-csv $Remediation_Summary -NoTypeInformation -Delimiter ";"
	$fileBytes = [System.IO.File]::ReadAllBytes($Remediation_Summary)	

	$fileName = "Remediation_scripts.csv"	
	$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$SharePoint_ExportFolder/$($fileName):/content"
	Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes
}

If($Backup_PlatformScripts -eq $true){
$Scripts_Array = @()
$PlatformScripts_sources = "$env:TEMP\Backup_Scripts"	
$Scripts_URL = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"
$Get_Platform_Scripts = (Invoke-MgGraphRequest -Uri $Scripts_URL  -Method GET).value
ForEach($Script in $Get_Platform_Scripts)
{
	$Script_displayName = $Script.displayName
	$Script_FileName = $Script.fileName
	$Script_Name = $Script_displayName.TrimEnd(" ")
	$Script_Sources_Path = "$PlatformScripts_sources\$Script_Name"
	$Script_Id = $Script.id
	$Script_info = "$Scripts_URL/$Script_Id"
	
	$Get_Script_info = (Invoke-MgGraphRequest -Uri $Script_info  -Method GET -SkipHttpErrorCheck) 	
	$ScriptContent = $Get_Script_info.scriptContent	
	If($ScriptContent -eq $null){
		$File_Path = Join-Path -Path $Script_Sources_Path -ChildPath $Script_FileName
		new-item $File_Path -force -type file
		$fileBytes = [System.IO.File]::ReadAllBytes($File_Path)
		
		$Export_Folder = "$SharePoint_ExportFolder\PlatformScripts\$Script_displayName"
		$fileName = $Script_FileName
		$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$Export_Folder/$($fileName):/content"
		Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes
	}Else{
		$Script_Decoded = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($ScriptContent))
		$File_Path = Join-Path -Path $Script_Sources_Path -ChildPath $Script_FileName 
		new-item $File_Path -force -type file
		$Script_Decoded | out-file $File_Path
		$fileBytes = [System.IO.File]::ReadAllBytes($File_Path)	

		$Export_Folder = "$SharePoint_ExportFolder\PlatformScripts\$Script_displayName"
		$fileName = $Script_FileName
		$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$Export_Folder/$($fileName):/content"
		Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes
	}

	$Obj = [PSCustomObject]@{
		Name     				= $Script_Name
		ID     					= $Script_Id		
		FileName     			= $Script_FileName
		Description    		    = $Script.description			
		runAs32Bit     			= $Script.runAs32Bit		
		RunAsAccount    		= $Script.runAsAccount					
		LastModifiedDateTime    = $Script.lastModifiedDateTime		
		CreatedDateTime    		= $Script.createdDateTime				
	}	
	$Scripts_Array += $Obj		
}
	$Scripts_Summary = "$PlatformScripts_sources\Platform_scripts.csv"
	new-item $Scripts_Summary -force -type file
	$Scripts_Array | export-csv $Scripts_Summary -NoTypeInformation -Delimiter ";"
	$fileBytes = [System.IO.File]::ReadAllBytes($Scripts_Summary)		
	$fileName = "Platform_scripts.csv"
	$uploadUrl = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$SharePoint_ExportFolder/$($fileName):/content"
	Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -ContentType "text/plain" -Body $fileBytes	
}
	