Set-StrictMode -Version 5

$LIST_URL = "a.wunderlist.com/api/v1/lists"
$TASK_URL = "a.wunderlist.com/api/v1/tasks"
$SUBTASK_URL = "a.wunderlist.com/api/v1/subtasks"
$NOTE_URL = "a.wunderlist.com/api/v1/notes"
$FILE_URL = "a.wunderlist.com/api/v1/files"

function Get-WunderlistList
{
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string] $Id,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [hashtable] $PermissionHeaders
    )

    EnsureKey -Object $PermissionHeaders -Key "X-Client-Id"
    EnsureKey -Object $PermissionHeaders -Key "X-Access-Token"

    $listUrl = $LIST_URL

    if ($Id) {
        $listUrl = "$listUrl/$Id"
    }

    $lists = TryInvokeWebRequest -Uri $listUrl -Headers $PermissionHeaders
    
    # Add additional properties to the return value for easy piping to get tasks
    $lists | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "ListId" -NotePropertyValue $_.id -PassThru }
}

function Get-WunderlistTask
{
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "Task")]
        [String] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [String] $ListId,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [switch] $IncludeCompleted,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [hashtable] $PermissionHeaders
    )

    Begin {
        EnsureKey -Object $PermissionHeaders -Key "X-Client-Id"
        EnsureKey -Object $PermissionHeaders -Key "X-Access-Token"

        $taskUrl = $TASK_URL
    }


    Process {
        switch ($PsCmdlet.ParameterSetName) {
            "Task" {
                $taskUrl = "$taskUrl/$Id"

                # Weird. Have to take a copy, else it acts as immutable for Add-Member
                $temp = TryInvokeWebRequest -Uri $taskUrl -Headers $PermissionHeaders

                # Add additional properties to the return value for easy piping to get subtasks
                $temp | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "TaskId" -NotePropertyValue $_.id -PassThru }
            }
            "List" {
                # Weird. Have to take a copy, else it acts as immutable for Add-Member
                $temp = TryInvokeWebRequest -Uri $taskUrl -Headers $PermissionHeaders -Body @{ "list_id" = $ListId }

                # Add additional properties to the return value for easy piping to get subtasks
                $temp | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "TaskId" -NotePropertyValue $_.id -PassThru }

                # Wunderlist API returns only completed tasks when "complete"=true is set, but this behavior does not seem useful.
                #   IncludeCompleted switch will return everything including completed tasks
                if ($IncludeCompleted) {
                    # Weird. Have to take a copy, else it acts as immutable for Add-Member
                    $temp = TryInvokeWebRequest -Uri $taskUrl -Headers $PermissionHeaders -Body @{ "list_id" = $ListId; "completed" = $true }
                   
                    # Add additional properties to the return value for easy piping to get subtasks
                    $temp | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "TaskId" -NotePropertyValue $_.id -PassThru }
                }
            }
        }
    }
}

function Get-WunderlistSubTask
{
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "SubTask")]
        [String] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Task")]
        [String] $TaskId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [String] $ListId,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = "List")]
        [Parameter(ParameterSetName = "Task")]
        [switch] $IncludeCompleted,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [hashtable] $PermissionHeaders
    )

    Begin {
        EnsureKey -Object $PermissionHeaders -Key "X-Client-Id"
        EnsureKey -Object $PermissionHeaders -Key "X-Access-Token"

        $subTaskUrl = $SUBTASK_URL
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            "SubTask" {
                $subTaskUrl = "$subTaskUrl/$Id"
                TryInvokeWebRequest -Uri $subTaskUrl -Headers $PermissionHeaders
            }
            "Task" {
                # Another bad\contradicting API design. Querying by task_id will return all subtasks including the completed ones!!
                $subTasks = TryInvokeWebRequest -Uri $subTaskUrl -Headers $PermissionHeaders -Body @{ "task_id" = $TaskId }
                if ($IncludeCompleted) {
                    $subTasks
                }
                else {
                    $subTasks | Where-Object { $_.completed -eq $false }
                }
            }
            "List" {
                # Another bad\contradicting API design. Querying by list_id will return all subtasks including the completed ones!!
                $subTasks = TryInvokeWebRequest -Uri $subTaskUrl -Headers $PermissionHeaders -Body @{ "list_id" = $ListId }
                if ($IncludeCompleted) {
                    $subTasks
                }
                else {
                    $subTasks | Where-Object { $_.completed -eq $false }
                }
            }
        }
    }
}

function Get-WunderlistNote
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "Note")]
        [String] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Task")]
        [String] $TaskId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [String] $ListId,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [hashtable] $PermissionHeaders
    )

    Begin {
        EnsureKey -Object $PermissionHeaders -Key "X-Client-Id"
        EnsureKey -Object $PermissionHeaders -Key "X-Access-Token"

        $noteUrl = $NOTE_URL
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            "Note" {
                $noteUrl = "$noteUrl/$Id"
                TryInvokeWebRequest -Uri $noteUrl -Headers $PermissionHeaders
            }
            "Task" {
                TryInvokeWebRequest -Uri $noteUrl -Headers $PermissionHeaders -Body @{ "task_id" = $TaskId }
            }
            "List" {
                TryInvokeWebRequest -Uri $noteUrl -Headers $PermissionHeaders -Body @{ "list_id" = $ListId }
            }
        }
    }
}

function Get-WunderlistFile
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "File")]
        [String] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Task")]
        [String] $TaskId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [String] $ListId,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [hashtable] $PermissionHeaders
    )

    Begin {
        EnsureKey -Object $PermissionHeaders -Key "X-Client-Id"
        EnsureKey -Object $PermissionHeaders -Key "X-Access-Token"

        $fileUrl = $FILE_URL
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            "File" {
                $fileUrl = "$fileUrl/$Id"
                TryInvokeWebRequest -Uri $fileUrl -Headers $PermissionHeaders
            }
            "Task" {
                TryInvokeWebRequest -Uri $fileUrl -Headers $PermissionHeaders -Body @{ "task_id" = $TaskId }
            }
            "List" {
                TryInvokeWebRequest -Uri $fileUrl -Headers $PermissionHeaders -Body @{ "list_id" = $ListId }
            }
        }
    }
}

function EnsureKey
{
    Param(
        [hashtable] $Object,
        [string] $Key
    )

    $res = $Object.ContainsKey($Key) `
        -and -not ([string]::IsNullOrWhiteSpace($Object[$Key])) `
        -and $Object[$Key].Length -gt 0

    if (-not $res) {
        throw "'" + $Key + "' is either missing or empty"
    }
}

function TryInvokeWebRequest
{
    Param(
        [string] $Uri,
        [hashtable] $Headers,
        [hashtable] $Body
    )

    try {
        $result = Invoke-WebRequest -Uri $Uri -Headers $Headers -Body $Body
        
        $result.Content | ConvertFrom-Json
    }
    catch [System.Net.WebException]{
        # Invoke-WebRequest throws regular WebExceptions with confusing text; hence casting to a much
        # useful text with this throw
        throw $_.Exception.Message + " " + $_.ErrorDetails
    }
}

Export-ModuleMember -Function Get-WunderlistList
Export-ModuleMember -Function Get-WunderlistTask
Export-ModuleMember -Function Get-WunderlistSubTask
Export-ModuleMember -Function Get-WunderlistNote
Export-ModuleMember -Function Get-WunderlistFile