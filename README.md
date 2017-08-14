# GBWunderlist
PowerShell client for [Wunderlist](https://www.wunderlist.com/) [Api](https://developer.wunderlist.com/documentation). You can use this powershell module to programatically access your Wunderlist lists, tasks, subtasks, notes and file. Not all Api calls have been implemented yet, but the ones implemented are well crafted to get the basics done.


## Getting Started

### Prerequisites

* [PowerShell](https://msdn.microsoft.com/en-us/powershell/mt173057.aspx) is mostly available by default in latest Windows client\server operating system. You can also download PowerShell for Mac OSX & Linux from its [release](https://github.com/PowerShell/PowerShell/releases/) page.

* [Optional but recommended] [PowerShellGet](http://www.powershellgallery.com/) packagemanagement module. PowerShellGet is available by default in PowerShell 5.0 (which ships in Windows 10) or later. If you don't have PowerShellGet installed (which you can find by running Install-Module cmdlet), you can install it from [here]((http://www.powershellgallery.com/)).

### Installation

There are two ways to install the module

* Install from [PowerShellGet](https://www.powershellgallery.com/packages/GBWunderlist) (recommended)
```
Install-Module -Name GBWunderlist
```

* Install from source code
```
git clone https://github.com/antonydeepak/GBWunderlist.git

Copy-Item /path/to/git/clone/GBWunderlist $home\Documents\WindowsPowerShell\Modules -Recurse

Import-Module GBWunderlist

Note: $home\Documents\WindowsPowerShell\Modules should be in $env:PSModulePath by default. If not, pick a folder that is present in that path.
```

## Usage

* First you have to [register your app](https://developer.wunderlist.com/apps/new/) in Wunderlist developer portal; `APP URL` and `AUTH CALLBACK URL` can be filled with dummy values. After registration you should see the **Client Id** and an option to **Create Access Token**.

* Use `Set-GBWunderlistPermissionHeaders` to set the permission headers using `ClientId` and `AccessToken` from above. Permission headers authorize every call to Wunderlist API and hence these values are set as script globals and reused in all subsequent calls.

```
Set-GBWunderlistPermissionHeaders -ClientId "g288f97453a5149ae28b" -AccessToken "6f75011ae7d9969fdc8aca78c45d50eb25d6f4a9783c85f81948bcccb2a8"
```

After these two steps you can retrieve your data using the following functions

* To get the Wunderlist list use `Get-GBWunderlistList` or `Get-GBWunderlistList -Id <list_id>`
```
Get-GBWunderlistList
Get-GBWunderlistList -Id 311278196
```

* To get Wunderlist task use either `Get-GBWunderlistTask -Id <task_id>` or `Get-GBWunderlistTask -ListId <list_id> [-IncludeCompleted]`. `IncludeCompleted` will get completed tasks along with non-completed ones.

```
Get-GBWunderlistTask -Id 1234

Get-GBWunderlistTask -ListId 311278196
Get-GBWunderlistTask -ListId 311278196 -IncludeCompleted
```
You can also chain commands through pipe. So you can do `Get-GBWunderlistList -Id 311278196 | Get-GBWunderlistTask` to get the tasks for a `ListId`

* To get Wunderlist subtask use either `Get-GBWunderlistSubTask -Id <sub_task_id>` or `Get-GBWunderlistSubTask -TaskId <task_id> [-IncludeCompleted]` or `Get-GBWunderlistSubTask -ListId <list_id> [-IncludeCompleted]`. `IncludeCompleted` will get completed subtasks along with non-completed ones.

```
Get-GBWunderlistSubTask -Id 432

Get-GBWunderlistSubTask -ListId 311278196
Get-GBWunderlistSubTask -TaskId 1234 -IncludeCompleted
```
Again you can pipe commands in very creative ways like `Get-GBWunderlistList |  Where-Object {$_.title -match 'work'} | Get-GBWunderlistTask | Get-GBWunderlistSubTask -IncludeCompleted`. Here you are fetching all the subtasks including the completed ones from a list named 'work'.
**Note**: this is just an example as you can do the same with `Get-GBWunderlistSubTask -ListId <list_id>`

* To get Wunderlist note use either `Get-GBWunderlistNote -Id <note_id>` or `Get-GBWunderlistNote -TaskId <task_id>` or `Get-GBWunderlistNote -ListId <list_id>`.

```
Get-GBWunderlistNote -ListId 311278196
```

* To get Wunderlist note use either `Get-GBWunderlistFile -Id <file_id>` or `Get-GBWunderlistFile -TaskId <task_id>` or `Get-GBWunderlistFile -ListId <list_id>`.

```
Get-GBWunderlistFile -Id 24
```
## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details