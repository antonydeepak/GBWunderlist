Set-StrictMode -Version 5

$LIST_URL = "a.wunderlist.com/api/v1/lists"
$TASK_URL = "a.wunderlist.com/api/v1/tasks"
$SUBTASK_URL = "a.wunderlist.com/api/v1/subtasks"
$NOTE_URL = "a.wunderlist.com/api/v1/notes"
$FILE_URL = "a.wunderlist.com/api/v1/files"

$script:permissionHeaders = $null

function Set-WunderlistPermissionHeaders
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "Table")]
        [hashtable] $PermissionHeaders,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "Field")]
        [string] $ClientId,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "Field")]
        [string] $AccessToken
    )

    switch ($PsCmdlet.ParameterSetName) {
        "Table" {
            EnsureKey -Object $PermissionHeaders -Key "ClientId"
            EnsureKey -Object $PermissionHeaders -Key "AccessToken"

            $script:permissionHeaders = @{
                "X-Client-Id" = $PermissionHeaders["ClientId"]
                "X-Access-Token" = $PermissionHeaders["AccessToken"]
            }
        }
        "Field" {
            $script:permissionHeaders = @{
                "X-Client-Id" = $ClientId
                "X-Access-Token" = $AccessToken
            }
        }}

    Write-Output "Permission headers successfully set"
}

function Get-WunderlistList
{
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string] $Id
    )

    EnsurePermissionHeadersNotNull

    $listUrl = $LIST_URL

    if ($Id) {
        $listUrl = "$listUrl/$Id"
    }

    $lists = TryInvokeWebRequest -Uri $listUrl -Headers $script:PermissionHeaders
    
    # Add additional properties to the return value for easy piping to get tasks
    $lists | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "ListId" -NotePropertyValue $_.id -PassThru }
}

function Get-WunderlistTask
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "Task")]
        [String] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [String] $ListId,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [switch] $IncludeCompleted
    )

    begin {
        EnsurePermissionHeadersNotNull

        $taskUrl = $TASK_URL
    }


    process {
        switch ($PsCmdlet.ParameterSetName) {
            "Task" {
                $taskUrl = "$taskUrl/$Id"

                # Weird. Have to take a copy, else it acts as immutable for Add-Member
                $temp = TryInvokeWebRequest -Uri $taskUrl -Headers $script:PermissionHeaders

                # Add additional properties to the return value for easy piping to get subtasks
                $temp | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "TaskId" -NotePropertyValue $_.id -PassThru }
            }
            "List" {
                # Weird. Have to take a copy, else it acts as immutable for Add-Member
                $temp = TryInvokeWebRequest -Uri $taskUrl -Headers $script:PermissionHeaders -Body @{ "list_id" = $ListId }

                # Add additional properties to the return value for easy piping to get subtasks
                $temp | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "TaskId" -NotePropertyValue $_.id -PassThru }

                # Wunderlist API returns only completed tasks when "complete"=true is set, but this behavior does not seem useful.
                #   IncludeCompleted switch will return everything including completed tasks
                if ($IncludeCompleted) {
                    # Weird. Have to take a copy, else it acts as immutable for Add-Member
                    $temp = TryInvokeWebRequest -Uri $taskUrl -Headers $script:PermissionHeaders -Body @{ "list_id" = $ListId; "completed" = $true }
                   
                    # Add additional properties to the return value for easy piping to get subtasks
                    $temp | ForEach-Object { Add-Member -InputObject $_ -NotePropertyName "TaskId" -NotePropertyValue $_.id -PassThru }
                }
            }
        }
    }
}

function Get-WunderlistSubTask
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = "SubTask")]
        [String] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Task")]
        [String] $TaskId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "List")]
        [String] $ListId,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = "List")]
        [Parameter(ParameterSetName = "Task")]
        [switch] $IncludeCompleted
    )

    begin {
        EnsurePermissionHeadersNotNull

        $subTaskUrl = $SUBTASK_URL
    }

    process {
        switch ($PsCmdlet.ParameterSetName) {
            "SubTask" {
                $subTaskUrl = "$subTaskUrl/$Id"
                TryInvokeWebRequest -Uri $subTaskUrl -Headers $script:PermissionHeaders
            }
            "Task" {
                # Another bad\contradicting API design. Querying by task_id will return all subtasks including the completed ones!!
                $subTasks = TryInvokeWebRequest -Uri $subTaskUrl -Headers $script:PermissionHeaders -Body @{ "task_id" = $TaskId }
                if ($IncludeCompleted) {
                    $subTasks
                }
                else {
                    $subTasks | Where-Object { $_.completed -eq $false }
                }
            }
            "List" {
                # Another bad\contradicting API design. Querying by list_id will return all subtasks including the completed ones!!
                $subTasks = TryInvokeWebRequest -Uri $subTaskUrl -Headers $script:PermissionHeaders -Body @{ "list_id" = $ListId }
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
        [String] $ListId
    )

    begin {
        EnsurePermissionHeadersNotNull

        $noteUrl = $NOTE_URL
    }

    process {
        switch ($PsCmdlet.ParameterSetName) {
            "Note" {
                $noteUrl = "$noteUrl/$Id"
                TryInvokeWebRequest -Uri $noteUrl -Headers $script:PermissionHeaders
            }
            "Task" {
                TryInvokeWebRequest -Uri $noteUrl -Headers $script:PermissionHeaders -Body @{ "task_id" = $TaskId }
            }
            "List" {
                TryInvokeWebRequest -Uri $noteUrl -Headers $script:PermissionHeaders -Body @{ "list_id" = $ListId }
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
        [String] $ListId
    )

    begin {
        EnsurePermissionHeadersNotNull

        $fileUrl = $FILE_URL
    }

    process {
        switch ($PsCmdlet.ParameterSetName) {
            "File" {
                $fileUrl = "$fileUrl/$Id"
                TryInvokeWebRequest -Uri $fileUrl -Headers $script:PermissionHeaders
            }
            "Task" {
                TryInvokeWebRequest -Uri $fileUrl -Headers $script:PermissionHeaders -Body @{ "task_id" = $TaskId }
            }
            "List" {
                TryInvokeWebRequest -Uri $fileUrl -Headers $script:PermissionHeaders -Body @{ "list_id" = $ListId }
            }
        }
    }
}

function EnsureKey
{
    param(
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

function EnsurePermissionHeadersNotNull
{
    if (-not $script:PermissionHeaders) {
        throw "Permission header('X-Client-Id' or 'X-Access-Token') is null." + `
                "Please call 'Set-PermissionHeaders' to set the appropriate permission headers(ClientId & AccessToken)." + `
                "If you are not sure what this is about, please visit 'https://developer.wunderlist.com/' to register the app and obtain clientid and access token."
    }
}

function TryInvokeWebRequest
{
    param(
        [string] $Uri,
        [hashtable] $Headers,
        [hashtable] $Body
    )

    try {
        $result = Invoke-WebRequest -Uri $Uri -Headers $Headers -Body $Body
        
        $result.Content | ConvertFrom-Json
    }
    catch [System.Net.WebException] {
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

Export-ModuleMember -Function Set-WunderlistPermissionHeaders