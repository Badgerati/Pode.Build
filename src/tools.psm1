function Set-PodeBuildState
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [object]
        $Value
    )

    Set-PodeState -Name "pode.build.$($Name)" -Value $Value -Scope 'pode.build' | Out-Null
}

function Get-PodeBuildState
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return (Get-PodeState -Name "pode.build.$($Name)")
}

function Get-PodeBuildQueryPath
{
    if ($null -eq $WebEvent) {
        return ([string]::Empty)
    }

    $value = $WebEvent.Query['value']
    $base = $WebEvent.Query['base']
    return (Join-PodeWebPath -Path $base -ChildPath $value -ReplaceSlashes)
}

function Get-PodeBuildJobPath
{
    param(
        [Parameter()]
        [string]
        $Name
    )

    $jobsPath = Get-PodeBuildState -Name 'JobsPath'

    if ($null -ne $WebEvent) {
        $path = Get-PodeBuildQueryPath
        $jobsPath = (Join-PodeWebPath -Path $jobsPath -ChildPath $path -ReplaceSlashes)
    }

    if (![string]::IsNullOrEmpty($Name)) {
        $jobsPath = (Join-PodeWebPath -Path $jobsPath -ChildPath $Name -ReplaceSlashes)
    }

    return $jobsPath
}

function Get-PodeBuildJobMetaPath
{
    $jobsPath = Get-PodeBuildJobPath
    return (Join-PodeWebPath -Path $jobsPath -ChildPath 'meta.json')
}

function Get-PodeBuildJobMeta
{
    $metaPath = Get-PodeBuildJobMetaPath
    if (!(Test-Path $metaPath)) {
        return $null
    }

    return (Get-Content -Path $metaPath -Force -Raw | ConvertFrom-Json)
}

function New-PodeBuildJobMeta
{
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Folder', 'Job')]
        [string]
        $Type
    )

    # create a new meta.json
    $jobsPath = Get-PodeBuildJobPath -Name $Name
    New-Item -ItemType Directory -Path $jobsPath -Force -ErrorAction Stop | Out-Null

    $metaPath = Join-PodeWebPath -Path $jobsPath -ChildPath 'meta.json'
    if (Test-Path $metaPath) {
        return
    }

    switch ($Type.ToLowerInvariant()) {
        'folder' {
            $metaContent = @{
                Type = $Type
                LastUpdated = Get-PodeBuildDateNow
                Items = @()
            }
        }

        'job' {
            $metaContent = @{
                Type = $Type
                LastUpdated = Get-PodeBuildDateNow
                Schedule = $null
                Status = 'New'
                NextRunId = 1
                File = $WebEvent.Data.File
                Items = @()
            }
        }
    }

    Save-PodeBuildJobMeta -Content $metaContent -Path $metaPath
}

function Save-PodeBuildJobMeta
{
    param(
        [Parameter()]
        $Content,

        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    $Content.LastUpdated = Get-PodeBuildDateNow
    $Content | ConvertTo-Json | Out-File -FilePath $Path -Force -ErrorAction Stop | Out-Null
}

function Get-PodeBuildDateNow
{
    return ([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))
}

function Add-PodeBuildJobMetaItem
{
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Folder', 'Job', 'Run')]
        [string]
        $Type,

        [switch]
        $PassThru
    )

    # adds cached item line to a meta.json for speed
    $metaPath = Get-PodeBuildJobMetaPath
    $metaContent = Get-PodeBuildJobMeta

    if (!$metaContent.Items) {
        $metaContent.Items = @()
    }

    switch ($Type.ToLowerInvariant()) {
        'folder' {
            $metaContent.Items += [PSCustomObject]@{
                Name = $Name
                Type = $Type
                LastUpdated = Get-PodeBuildDateNow
            }
        }

        'job' {
            $metaContent.Items += [PSCustomObject]@{
                Name = $Name
                Type = $Type
                LastUpdated = Get-PodeBuildDateNow
                Status = 'Running' # Running, Failed, Success
            }
        }

        'run' {
            $metaContent.Items += [PSCustomObject]@{
                Name = $Name
                Type = $Type
                LastUpdated = Get-PodeBuildDateNow
                StartTime = Get-PodeBuildDateNow
                Duration = 0
                Status = 'New' # Running, Failed, Success
            }
        }
    }

    Save-PodeBuildJobMeta -Content $metaContent -Path $metaPath

    if ($PassThru) {
        return $metaContent
    }
}

function Remove-PodeBuildJobMetaItem
{
    param(
        [Parameter()]
        [string]
        $Name,

        [switch]
        $PassThru
    )

    # removes a cached item line from a meta.json
    $metaPath = Get-PodeBuildJobMetaPath
    $metaContent = Get-PodeBuildJobMeta

    if (!$metaContent.Items) {
        $metaContent.Items = @()
    }

    $metaContent.Items = @(foreach ($item in $meta.Items) {
        if ($item -ine $Name) {
            $item
        }
    })

    Save-PodeBuildJobMeta -Content $metaContent -Path $metaPath

    if ($PassThru) {
        return $metaContent
    }
}

function Convert-PodeBuildTypeToElement
{
    param(
        [Parameter()]
        [ValidateSet('', 'Folder', 'Job', 'Run')]
        [string]
        $Type
    )

    $title = ConvertTo-PodeWebTitleCase -Value $Type

    switch ($Type.ToLowerInvariant()) {
        'folder' {
            return (New-PodeWebIcon -Name 'folder' -Colour Yellow -Title $title)
        }

        'job' {
            return (New-PodeWebIcon -Name 'code' -Title $title)
        }

        'run' {
            return (New-PodeWebIcon -Name 'code' -Title $title)
        }

        default {
            return $null
        }
    }
}

function Convert-PodeBuildStatusToElement
{
    param(
        [Parameter()]
        [ValidateSet('', 'New', 'Success', 'Failed', 'Aborted', 'Paused', 'Running')]
        [string]
        $Type
    )

    $title = ConvertTo-PodeWebTitleCase -Value $Type

    switch ($Type.ToLowerInvariant()) {
        'new' {
            return (New-PodeWebIcon -Name 'circle' -Title $title)
        }

        'success' {
            return (New-PodeWebIcon -Name 'check-circle' -Colour Limegreen -Title $title)
        }

        'failed' {
            return (New-PodeWebIcon -Name 'alert-circle' -Colour Red -Title $title)
        }

        'aborted' {
            return (New-PodeWebIcon -Name 'minus-circle' -Title $title)
        }

        'paused' {
            return (New-PodeWebIcon -Name 'pause-circle' -Colour Yellow -Title $title)
        }

        'running' {
            return (New-PodeWebSpinner -Colour Cornflowerblue -Title $title)
        }

        default {
            return $null
        }
    }
}

function ConvertTo-PodeWebTitleCase
{
    param(
        [Parameter()]
        [string]
        $Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return ([string]::Empty)
    }

    try {
        return [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($Value.ToLowerInvariant())
    }
    catch {
        return $Value
    }
}