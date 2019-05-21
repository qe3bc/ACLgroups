set-strictmode -version latest

function Add-AclGroup
{
  <#
  .Synopsis
  Add-AclGroup creates local groups related to file paths. The groups can be used to assign NTFS permissions.
  .Description
  The cmdlet creates one or more groups based on a filepath. You can choose a prefix, delimiter and a suffix to represent the type of group to be created (read, write, modify, full control). While all of this can of course be done manually, this cmdlet makes it easier to repeat this process consistently.
  .Parameter Name
  Type: String
  Default: None
  Required
  The name of the group that should be created. If output from 
  .Parameter Prefix
  Type: string
  Default: AclGroup
  The Prefix of any created group name. By default, this just adds "AclGroup" in front of the name, to differentiate them from other groups for different purposes.
  The Prefix might also be used to differentiate shares with identical Name attribute (e.g. "Temp") but from different departments (e.g. set Prefix to AclGroupHR for HR shares, AclGroupIT for IT shares etc.).
  .Parameter Delimiter
  Type: string
  Default: -
  The delimiter between prefix, path and permission identifier.
  .Parameter Suffix
  Type: string array
  Default: $False
  The suffix for created groups (for instance, "W" for groups that should be assigned write permissions).
  .Parameter Description
  Type: string
  Default: Resource group for AGDLP permission assignment.
  The description of the created groups.

  .Example
  Create a local group that should get Read access to C:\TestFolder:

  Get-Item C:\TestFolder | Add-AclGroup -Suffix R

  Creates group AclGroup-TestFolder-R.

  .Example
  Create groups with Modify and FullControl permissions on C:\HR\TestFolder. Since there is also a directory C:\IT\TestFolder, we need to differentiate between the two through the prefix setting.

  Get-Item C:\TestFolder | Add-AclGroup -Prefix PermissionGroupHR Suffix MOD,FULL

  Creates Groups PermissionGroupHR-TestFolder-MOD and PermissionGroupHR-TestFolder-FULL

  .Example
  The default delimiter is not wanted for the target environment and has to be changed. In addition, the group should be named "foo", not "Testfolder":

  Add-AclGroup -Suffix R -Name foo -Delimiter _

  Creates group AclGroup_foo_R.
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipelineByPropertyName = $true)]
      [string]$Name,
      [string]$Prefix="AclGroup",
      [string]$Delimiter="-",
      [string[]]$Suffix=(,$False),
      [string]$Description="Resource group for AGDLP permission assignment."
  )

  Process
  {
    foreach ($sfx in $Suffix)
    {
      if ($sfx -ne $False)
      {
        $AclGroupName = $Prefix+$Delimiter+$Name+$Delimiter+$sfx
        Write-Verbose "Creating group $AclGroupName"
        New-LocalGroup -Name $AclGroupName -Description $Description
      }
    }
  }
}

function Remove-AclGroup
{
  <#
  .Synopsis
  Deletes local groups created by Add-AclGroup.
  .Description
  The cmdlet deletes all local groups that fit a set of criteria. Given a directory, it looks for groups with a specific prefix, delimiter and suffix, or deletes all matching groups no matter the suffix.
  .Parameter Path
  Type: System.IO.FileSystemInfo
  Default: None
  Required
  The path whose groups should be deleted. This should be an object of type System.IO.FileSystemInfo, as obtained by the Get-Item cmdlet. The $Path.Name attribute will be used as part of the AclGroup's name, so that only the correct groups will be deleted.
  .Parameter Prefix
  Type: string
  Default: AclGroup
  The Prefix that any group has to match in order to be deleted.
  .Parameter Suffix
  Type: Array of strings
  Default: ("R","W","M","F")
  Groups with any of the given suffixes will be deleted.
  .Parameter Delimiter
  Type: string
  Default: -
  The delimiter between prefix, path and suffix. Used to construct
  the names of the deleted groups.
  .Parameter RemoveAll
  Type: Switch
  If provided, this disregards any suffixes and deletes all groups that can be matched by other criteria.
  .Example
  Delete all groups for C:\Testfolder, created by Add-AclGroup with default options:

  Get-Item C:\Testfolder | Remove-Acl -RemoveAll
  .Example
  Delete Read group for C:\Testfolder, created by Add-AclGroup with default options:

  Get-Item C:\Testfolder | Remove-Acl -Suffix ("R")
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipelineByPropertyName = $true)]
      [System.IO.FileSystemInfo]$Name,
      [string]$Prefix="AclGroup",
      [string[]]$Suffix=("R","W","M","F"),
      [string]$Delimiter="-",
      [switch]$RemoveAll
  )
  Begin
  {
      $DeleteList = @()
  }

  Process
  {
    if ($RemoveAll)
    {
      $MatchingGroups = Get-LocalGroup | Where-Object{$_.Name -match "^$Prefix$Delimiter$Name$Delimiter"}
    }
    else
    {
      $MatchingGroups = Get-LocalGroup | Where-Object{$_.Name -match "^$Prefix$Delimiter$Name$Delimiter[$Suffix]"}
    }
    $MatchingGroups | Remove-LocalGroup
    Foreach ($Group in $MatchingGroups)
    {
      $DeleteItem = New-Object PSObject
      $DeleteItem | Add-Member NoteProperty Name $Group.Name
      $DeleteItem | Add-Member NoteProperty Description $Group.Description
      $DeleteItem | Add-Member NoteProperty Status Deleted
      $deleteList += $DeleteItem
    }
  }
  End
  {
    return $DeleteList
  }
}

function Register-AclGroup
{
    <#
  .Synopsis
  Adds existing groups, for instance created by Add-AclGroup, to the ACL of a folder or other object.
  .Description
  Register-AclGroup creates the actual ACEs for the AclGroups that have been created by Add-AclGroup. If no other options are given, it assumes default values for all Add-AclGroup options and tries to locate the relevant groups.

  Searches for AclGroups with a pattern of $Prefix$Delimiter$GroupName[$Read,$Write,$Modify,$FullControl]
  .Parameter Path
  Type: System.IO.FileSystemInfo
  Default: None
  Required
  The object whose ACL should be modified. This should be an object of type System.IO.FileSystemInfo, as obtained by the Get-Item cmdlet. The $Path.Name attribute will be used as part of the AclGroup's name, so that only the correct groups will be added to the ACL.
  .Parameter Prefix
  Type: string
  Default: AclGroup
  The Prefix that any group has to match in order to be added to the ACL.
  .Parameter GroupName
  Type: string
  Default: $False
  The main part of the group name that any group has to match in order to be added to the ACL. If $False (default), picks the name of the object as group name, otherwise the provided group name is used to construct the full name of the AclGroups to add.
  .Parameter Delimiter
  Type: string
  Default: "-"
  Delimiter between other parts of the group name.
  .Parameter Read
  Type: string
  Default: $False
  The suffix that identifies the correct group for this permission (Read)
  .Parameter Write
  Type: string
  Default: $False
  The suffix that identifies the correct group for this permission (Write)
  .Parameter Modify
  Type: string
  Default: $False
  The suffix that identifies the correct group for this permission (Modify)
  .Parameter FullControl
  Type: string
  Default: $False
  The suffix that identifies the correct group for this permission (FullControl)

  .Example
  Give a group created by Add-AclGroup (suffix "F" ) with default settings full control over C:\Testfolder:
  
  Get-Item C:\Testfolder | Register-AclGroup -FullControl "F"

  .Example
  Give a group named "PermissionGroup_Testfolder_F" full control over C:\Testfolder:

  Get-Item C:\Testfolder | Register-AclGroup -Prefix "PermissionsGroup" -Delimiter "_" -FullControl "F"
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipeline = $true)]
      [System.IO.FileSystemInfo]$Path,
      [string]$Prefix="AclGroup",
      [string]$GroupName=$False,
      [string]$Delimiter="-",
      [string]$Read=$False,
      [string]$Write=$False,
      [string]$Modify=$False,
      [string]$AppliesTo="ThisFolderSubfoldersAndFiles",
      [string]$FullControl=$False
  )

  Process
  {
    write-debug "Entering processing block"
    if ($GroupName -eq $False) {$GroupName = $Path.Name}
  
    $Group = @("$Prefix$Delimiter$GroupName$Delimiter$Read",`
    "$Prefix$Delimiter$GroupName$Delimiter$Write",`
    "$Prefix$Delimiter$GroupName$Delimiter$Modify",`
    "$Prefix$Delimiter$GroupName$Delimiter$FullControl")

    if ($Read -ne $False)
    {
      Add-NTFSAccess -Path $Path.FullName -Account $Group[0] -AccessRights ReadAndExecute -AppliesTo $AppliesTo
    }
    if ($Write -ne $False)
    {
      Add-NTFSAccess -Path $Path.FullName -Account $Group[1] -AccessRights Write -AppliesTo $AppliesTo
    }
    if ($Modify -ne $False)
    {
      Add-NTFSAccess -Path $Path.FullName -Account $Group[2] -AccessRights Modify -AppliesTo $AppliesTo
    }
    if ($FullControl -ne $False)
    {
      Add-NTFSAccess -Path $Path.FullName -Account $Group[3] -AccessRights FullControl -AppliesTo $AppliesTo
    }
  }
}

function Unregister-AclGroup
{
    <#
  .Synopsis
  Removes ACEs, especially those created by Register-AclGroup cmdlet.
  .Description
  This reverses any action taken by Register-AclGroup in a targeted way. If no other options are given, it assumes default values for all Add-AclGroup options and tries to locate the relevant groups.
 .Parameter Path
  Type: System.IO.FileSystemInfo
  Default: None
  Required
  The object whose ACL should be modified. This should be an object of type System.IO.FileSystemInfo, as obtained by the Get-Item cmdlet. The $Path.Name attribute will be used as part of the AclGroup's name, so that only the correct groups will be added to the ACL.
  .Parameter Prefix
  Type: string
  Default: AclGroup
  The Prefix that any group has to match if it is to be removed from the ACL.
  .Parameter GroupName
  Type: string
  Default: $False
  The main part that any group has to match if it is to be removed from the ACL. If $False (default), picks the name of the object as group name, otherwise the provided group name is used to construct the full name of the AclGroups to remove.
  .Parameter Delimiter
  Type: string
  Default: "-"
  The delimiter between all other parts of the group name. Also used to match the correct groups to be removed from the ACL.
  .Parameter Read
  Type: string
  Default: $False
  The Read group suffix.
  .Parameter Write
  Type: string
  Default: $False
  The Write group suffix.
  .Parameter Modify
  Type: string
  Default: $False
  The Modify group suffix.
  .Parameter FullControl
  Type: string
  Default: $False
  The FullControl group suffix.
  .Parameter UnpublishAll
  Type: switch
  Default: $False
  If used, removes all permissions of the group matching the pattern "$Prefix$Delimiter$GroupName". Use with caution.

  .Example
  Remove Read access for group "AclGroup-Testfolder-R" from C:\Testfolder

  Get-Item C:\Testfolder | Unregister-AclGroup -Read R
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipeline = $true)]
      [System.IO.FileSystemInfo]$Path,
      [string]$Prefix="AclGroup",
      [string]$GroupName=$False,
      [string]$Delimiter="-",
      [string]$Read=$False,
      [string]$Write=$False,
      [string]$Modify=$False,
      [string]$FullControl=$False,
      [switch]$UnpublishAll

  )
  Begin
  {
      if ($GroupName -eq $False){$GroupName = $Path.Name}
    }

  Process
  {
    write-debug "Entering processing block"
    if ($UnpublishAll)
    {
      $Group = "$Prefix$Delimiter$GroupName$Delimiter"
      Get-NTFSAccess $Path.FullName | Where-Object{$_.Account -match $Group} | Remove-NTFSAccess
    }
    $Group = @("$Prefix$Delimiter$GroupName$Delimiter$Read",
                                          "$Prefix$Delimiter$GroupName$Delimiter$Write",
                                          "$Prefix$Delimiter$GroupName$Delimiter$Modify",
                                          "$Prefix$Delimiter$GroupName$Delimiter$FullControl")
    if ($Read -ne $False)
    {
      Remove-NTFSAccess -Path $Path.FullName -Account $Group[0] -AccessRights ReadAndExecute
    }
    if ($Write -ne $False)
    {
      Remove-NTFSAccess -Path $Path.FullName -Account $Group[1] -AccessRights Write
    }
    if ($Modify -ne $False)
    {
      Remove-NTFSAccess -Path $Path.FullName -Account $Group[2] -AccessRights Modify
    }
    if ($FullControl -ne $False)
    {
      Remove-NTFSAccess -Path $Path.FullName -Account $Group[3] -AccessRights FullControl
    }
  }
}

function Install-AclGroup
{
    <#
  .Synopsis
  Takes a directory or file path, creates a corresponding local group and adds it to the ACL.
  .Description
  Uses Add-AclGroup and Register-AclGroup to install (=create and add to ACL) a new local permission group. Parameters are passed on to the respective cmdlet. Also gives an option to limit file owner permissions to "Modify" in order to prevent users from setting permissions on their files.
  .Parameter Path
  Type: System.IO.FileSystemInfo
  Default: None
  Required
  The object whose ACL should be modified. This should be an object of type System.IO.FileSystemInfo, as obtained by the Get-Item cmdlet. The $Path.Name attribute will be used as part of the AclGroup's name.
  .Parameter Prefix
  Type: string
  Default: AclGroup
  The Prefix that should be used for the created group.
  .Parameter GroupName
  Type: string
  Default: $False
  The main part of the created group. If $False (default), picks the name of the object as group name, otherwise the provided group name is used to construct the full name of the AclGroups.
  .Parameter Delimiter
  Type: string
  Default: "-"
  The delimiter between all other parts of the group name.
  .Parameter Read
  Type: string
  Default: $False
  The Read group suffix.
  .Parameter Write
  Type: string
  Default: $False
  The Write group suffix.
  .Parameter Modify
  Type: string
  Default: $False
  The Modify group suffix.
  .Parameter FullControl
  Type: string
  Default: $False
  The FullControl group suffix.
  .Parameter Description
  Type: string
  Default: "Group for NTFS Permission Assignment"
  The description of the created group.
  .Example
  Create a local group called "Permissiongroup<Foldername>R" with Read permissions for all subdirectories of a location and add them to their respective ACLs:

  Get-ChildItem -Directory | Install-AclGroup -Prefix "Permissiongroup" -Delimiter "" -Read R
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipeline = $true)]
      [System.IO.FileSystemInfo]$Path,
      [string]$Prefix="AclGroup",
      [string]$Delimiter="-",
      [string]$Read=$False,
      [string]$Write=$False,
      [string]$Modify=$False,
      [string]$FullControl=$False,
      [string]$AppliesTo="ThisFolderSubfoldersAndFiles",
      [string]$Description="Group for NTFS Permission Assignment"

  )

  Process
  {
    $params_add = @{"Name" = $Path.Name
                "Prefix" = $Prefix
                "Suffix" = @($Read, $Write, $Modify, $FullControl) | Where-Object{$_ -ne $False}
                "Delimiter" = $Delimiter
              }
    $params_publish = @{"Path" = $Path
                "Prefix" = $Prefix
                "Read" = $Read
                "Write" = $Write
                "Modify" = $Modify
                "FullControl" = $FullControl
                "Delimiter" = $Delimiter
              }

    Add-AclGroup @params_add -Description $Description
    Register-AclGroup @params_publish -AppliesTo $AppliesTo
  }
}

function Uninstall-AclGroup
{
    <#
  .Synopsis
  Takes a directory or file path, removes a corresponding local group from the ACL and deletes it.
  .Description
  Uses Remove-AclGroup and UnRegister-AclGroup to uninstall (=remove from ACL and delete) a local permission group. Parameters are passed on to the respective cmdlet.
  .Parameter Path
  Type: System.IO.FileSystemInfo
  Default: None
  Required
  The object whose ACL should be modified. This should be an object of type System.IO.FileSystemInfo, as obtained by the Get-Item cmdlet. The $Path.Name attribute will be used as part of the AclGroup's name.
  .Parameter Prefix
  Type: string
  Default: AclGroup
  The Prefix that groups have to match in order to be deleted.
  .Parameter GroupName
  Type: string
  Default: $False
  The main part of the deleted group. If $False (default), picks the name of the object as group name, otherwise the provided group name is used to construct the full name of the AclGroups.
  .Parameter Delimiter
  Type: string
  Default: "-"
  The delimiter between all other parts of the group name.
  .Parameter Read
  Type: string
  Default: $False
  The Read group suffix. If provided, removes the matching group with Read permissions.
  .Parameter Write
  Type: string
  Default: $False
  The Write group suffix. If provided, removes the matching group with Write permissions.
  .Parameter Modify
  Type: string
  Default: $False
  The Modify group suffix. If provided, removes the matching group with Modify permissions.
  .Parameter FullControl
  Type: string
  Default: $False
  The FullControl group suffix. If provided, removes the matching group with FullControl permissions.
  .Parameter RemoveAll
  Type: switch
  Default: $false
  Ignores suffixes and removes/deletes all groups matching PrefixDelimiterGroupName.
  .Example
  Remove a local group called "Permissiongroup<Foldername>R" with Read permissions from the ACLs of all subdirectories of a location and delete them:

  Get-ChildItem -Directory | Uninstall-AclGroup -Prefix "Permissiongroup" -Delimiter "" -Read R
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipeline = $true)]
      [System.IO.FileSystemInfo]$Path,
      [string]$Prefix="AclGroup",
      [string]$Delimiter="-",
      [string]$Read=$False,
      [string]$Write=$False,
      [string]$Modify=$False,
      [string]$FullControl=$False,
      [switch]$RemoveAll
  )
  Begin
  {
    $Suffix = ($Read,$Write,$Modify,$FullControl) | Where-Object{$_ -ne $False}
  }

  Process
  {
    $params = @{"Path" = $Path
                "Prefix" = $Prefix
                "Read" = $Read
                "Write" = $Write
                "Modify" = $Modify
                "FullControl" = $FullControl
                "Delimiter" = $Delimiter
              }
    Unregister-AclGroup @params -UnpublishAll:$RemoveAll
    Remove-AclGroup -Path $Path -Prefix $Prefix -Suffix $Suffix -RemoveAll:$RemoveAll
  }
}

function Reset-Acls
{
    <#
  .Synopsis
  .Description
  .Parameter Path
  .Example
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipeline = $true)]
      [System.IO.FileSystemInfo]$Path,
      [switch]$LimitOwner
  )

  Process
  {
    Write-Verbose "Resetting $($Path.Name)..."
    Write-Verbose "Adding System account with FullControl"
    $Path | Add-NTFSAccess -Account System -AccessRights FullControl
    Write-Verbose "Disabling NTFS inheritance and removing inherited ACEs"
    $Path | Where-Object{($_ | Get-NtfsInheritance).AccessInheritanceEnabled -eq $True} | Disable-NTFSAccessInheritance -RemoveInheritedAccessRules
    Write-Verbose "Deleting all ACE entries except System"
    $Path | Get-NTFSAccess | Where-Object{$_.Account -ne "S-1-5-18"} | Remove-NTFSAccess
    if ($LimitOwner)
    {
      Write-Verbose "Restricting owner access to Modify"
      Get-NTFSAccess -Path $Path.FullName -Account "S-1-3-4" | Remove-NTFSAccess
      Add-NTFSAccess -Path $Path.FullName -Account "S-1-3-4" -AccessRights Modify
    }
    Write-Verbose "Resetting all subdirectories to inherited entries"
    $Path | Get-ChildItem2 -Recurse |`
    Enable-NTFSAccessInheritance -RemoveExplicitAccessRules -Verbose
  }
}


function Set-AclGroups
{
    <#
  .Synopsis
  .Description
  .Parameter Path
  .Example
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipeline = $true)]
      [System.IO.FileSystemInfo]$Path,
      [string]$Prefix="AclGroup",
      [string]$Delimiter="-",
      [switch]$LimitOwner
  )
  Process
  {
    if ($LimitOwner)
    {
      Write-Verbose "Restricting owner access to Modify"
      Get-NTFSAccess -Path $Path.FullName -Account "S-1-3-4" | Remove-NTFSAccess
      Add-NTFSAccess -Path $Path.FullName -Account "S-1-3-4" -AccessRights Modify
    }
    Write-Verbose "Removing all permissions from $($path.FullName) that don't belong to system or match $prefix$delimiter$($path.Name)..."
    $AclDeletionList = Get-NTFSAccess -Path $Path.FullName | `
    Where-Object{$_.Account -notmatch "$Prefix$Delimiter$($path.Name)"} | `
    Where-Object{$_.Account.Sid -notmatch "S-1-5-18"} | Where-Object{$_.Account.Sid -notmatch "S-1-3-4"}
    $AclDeletionList | Remove-NTFSAccess
  }
}

function Find-Rootfolders
{
    <#
  .Synopsis
  Searches for folders with non-inherited permissions.
  .Description
  This is useful as a first measure to identify points in a directory structure that currently have non-inherited permissions. Uses Get-ChildItem2 to get around long paths often present in problematic directory structures.
  .Parameter Target
  Type: System.IO.FileSystemInfo
  Default: None
  Required
  The starting point to explore.
  .Parameter LogPath
  Type: string
  Default: C:\temp
  Where all results are logged.
  .Parameter Depth
  Type: int
  Default: 2
  How deep the search should be performed, starting at $Target
  .Parameter Depth
  Type: int
  Default: 2
  How deep the search should be performed, starting at $Target
  #>
  Param
  (
      [Parameter(
          Mandatory = $true,
          Position = 0,
          ValueFromPipeline = $true)]
      [System.IO.FileSystemInfo]$Target,
      [string]$LogPath = "C:\temp",
      [int]$Depth = 2
  )
  Begin
  {
    $timestamp = Get-Date -Format "FileDateTime"
  }

  Process
  {
    $RootDirs = (Get-ChildItem2 $Target.FullName -Recurse -Depth $Depth | `
    Where-Object{($_ | Get-NTFSAccess).IsInherited -eq $False}).FullName
    $RootDirs | Out-File "$LogPath\$timestamp $($Target.Name).txt"
  }
}
Set-StrictMode -Off
