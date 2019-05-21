# ACLgroup
A little powershell script to make managing NTFS permissions for windows file shares easier. It currently only supports the creation of *local* ACL groups, but if this is helpful to more people than me, I'll look into adapting the module for domain-local groups.

## Motivation
Managing permissions with powershell is quite easy, thanks to the amazing module [NTFSSecurity by raandree](https://github.com/raandree/NTFSSecurity). It's a bit more difficult when encountering legacy structures, grown organically over time. This module aims to provide tools to clean up existing ACLs.

## Dependencies
Needs [NTFSSecurity by raandree](https://github.com/raandree/NTFSSecurity) to work.

## Documentation
Most commandlets have their documentation with them, so Get-Help should work. Some is still missing.

## Usage

### Discovery
To discover current root folders (all folders with non-inherited permissions), the cmdlet "Find-Rootfolders" just searches for directories with non-inherited ACEs and logs them. This helps with selecting roots that should continue to exist and those that should be removed.

Once you have that down, the next step is either resetting the ACLs of root folders and their subdirectories to a clean state and adding ACL groups afterwards, or adding the ACL groups first and reset later (to clean up permissions without disruptions to users).

### Reset

#### Hard reset
Reset-Acls adds the System account with FullControl permissions and removes all other entries from the ACL (inherited or otherwise). It then goes through all subdirectories and turns on permission inheritance, while removing non-inherited entries.

Optionally, file owner permissions can be restricted to "Modify".

#### Soft reset
Set-AclGroups does the same as the hard reset option, except it also leaves previously installed ACL groups intact.

### Adding ACL groups
To create ACL groups for directories and put them into the ACL, use the Install-AclGroup cmdlet. This takes a path, creates a corresponding group and adds it to the ACL all in one command.
