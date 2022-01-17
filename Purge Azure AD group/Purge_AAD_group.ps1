# Fill this part: type the group ID to clean
$GroupID = ""
Connect-AzAccount -Identity
$GroupToClean = (Get-AzADGroupMember -GroupObjectId $GroupID)
ForEach($Member in $GroupToClean)
    {
        $Member_ID = $Member.Id                   
        Remove-AzADGroupMember -MemberObjectId $Member_ID -GroupObjectId $GroupID
    }
