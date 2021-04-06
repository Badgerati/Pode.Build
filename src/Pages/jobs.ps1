# setup the jobs path
$jobsPath = Join-Path (Get-PodeServerPath) 'Jobs'
Set-PodeBuildState -Name 'JobsPath' -Value $jobsPath

if (!(Test-Path $jobsPath)) {
    New-Item -ItemType Directory -Path $jobsPath -Force -ErrorAction Stop | Out-Null
}

$metaPath = Get-PodeBuildJobMetaPath
if (($null -eq $metaPath) -or !(Test-Path $metaPath)) {
    New-PodeBuildJobMeta -Type Folder
}

# setup the jobs page
Add-PodeWebPage -Name Jobs -Icon Code -Group Automation -NoBackArrow -ScriptBlock {
    # load meta data
    $meta = Get-PodeBuildJobMeta

    # render modals
    if (($null -eq $meta) -or ($meta.Type -ieq 'folder')) {
        #TODO: render "add folder" and "add job" buttons for modal
        New-PodeWebContainer -Content @(
            New-PodeWebButton -Name 'New Folder' -Icon 'folder-plus' -CssClass 'mb-0' -ScriptBlock {
                Show-PodeWebModal -Name 'New Folder' -DataValue (Get-PodeBuildQueryPath)
            }
            New-PodeWebButton -Name 'New Job' -Icon 'plus' -CssClass 'mb-0' -ScriptBlock {
                Show-PodeWebModal -Name 'New Job' -DataValue (Get-PodeBuildQueryPath)
            }
        )

        #TODO: new job modal
        # name, script filepath, schedule, max-runs to keep
        New-PodeWebModal -Name 'New Job' -Icon 'plus' -AsForm -Content @(
            New-PodeWebTextbox -Name 'Name'
            New-PodeWebTextbox -Name 'File'
        ) -ScriptBlock {
            if ($WebEvent.Data.Name.Length -le 2) {
                Out-PodeWebValidation -Name 'Name' -Message 'Job name must be greater than 2 characters'
                return
            }

            #TODO: validate name - letters/numbers, no spaces, etc

            $path = Get-PodeBuildJobPath -Name $WebEvent.Data.Name
            if (Test-Path $path) {
                Out-PodeWebValidation -Name 'Name' -Message 'The job name already exists'
                return
            }

            if ([string]::IsNullOrWhiteSpace($WebEvent.Data.File) -or !(Test-Path $WebEvent.Data.File)) {
                Out-PodeWebValidation -Name 'File' -Message 'The file path does not exist'
                return
            }

            if (Test-Path $WebEvent.Data.File -PathType Container) {
                Out-PodeWebValidation -Name 'File' -Message 'The file path must be a file, not a directory'
                return
            }

            #TODO: create job
            # schedule
            try {
                New-PodeBuildJobMeta -Name $WebEvent.Data.Name -Type Job
                $meta = Add-PodeBuildJobMetaItem -Name $WebEvent.Data.Name -Type Job -PassThru
            }
            catch {
                Show-PodeWebError -Message $_.Exception.Message
                return
            }

            Show-PodeWebToast -Message "Job created: $($WebEvent.Data.Name)"

            if (($null -eq $meta) -or ($meta.Items.Length -eq 1)) {
                Reset-PodeWebPage
            }
            else {
                Sync-PodeWebTable -Name 'Jobs'
            }

            Hide-PodeWebModal
        }

        # new folder modal
        New-PodeWebModal -Name 'New Folder' -Icon 'folder-plus' -AsForm -Content @(
            New-PodeWebTextbox -Name 'Name'
        ) `
        -ScriptBlock {
            if ($WebEvent.Data.Name.Length -le 2) {
                Out-PodeWebValidation -Name 'Name' -Message 'Folder name must be greater than 2 characters'
                return
            }

            #TODO: validate name - letters/numbers, no spaces, etc

            $path = Get-PodeBuildJobPath -Name $WebEvent.Data.Name
            if (Test-Path $path) {
                Out-PodeWebValidation -Name 'Name' -Message 'The folder name already exists'
                return
            }

            try {
                New-PodeBuildJobMeta -Name $WebEvent.Data.Name -Type Folder
                $meta = Add-PodeBuildJobMetaItem -Name $WebEvent.Data.Name -Type Folder -PassThru
            }
            catch {
                Show-PodeWebError -Message $_.Exception.Message
                return
            }

            Show-PodeWebToast -Message "Folder created: $($WebEvent.Data.Name)"

            if (($null -eq $meta) -or ($meta.Items.Length -eq 1)) {
                Reset-PodeWebPage
            }
            else {
                Sync-PodeWebTable -Name 'Jobs'
            }

            Hide-PodeWebModal
        }

        #TODO: rename folder modal

        #TODO: delete folder modal
    }
    elseif ($meta.Type -ieq 'job') {
        #TODO: run button - show running when job is running
        #TODO: edit, delete modals (build with params modal?)
        New-PodeWebContainer -Content @(
            New-PodeWebButton -Name 'Run' -Icon 'play' -CssClass 'mb-0' -ScriptBlock {}
            New-PodeWebButton -Name 'Edit' -Icon 'edit-2' -CssClass 'mb-0' -ScriptBlock {}
            New-PodeWebButton -Name 'Delete' -Icon 'trash-2' -CssClass 'mb-0' -ScriptBlock {}
        )
    }

    # dont render anything if no meta
    if (($null -eq $meta) -or ($meta.Items.Length -eq 0)) {
        return
    }

    # render folder/jobs table for a folder
    if ($meta.Type -ieq 'folder') {
        New-PodeWebCard -Content @(
            New-PodeWebTable -Name 'Jobs' -DataColumn Name -Click -NoExport -NoRefresh -ScriptBlock {
                $meta = Get-PodeBuildJobMeta
                $meta.Items = ($meta.Items | Sort-Object -Property Name, Type)

                foreach ($item in $meta.Items) {
                    [ordered]@{
                        Type = (Convert-PodeBuildTypeToElement -Type $item.Type)
                        Status = (Convert-PodeBuildStatusToElement -Type $item.Status)
                        Name = $item.Name
                        LastUpdated = $item.LastUpdated
                        Actions = 'Lorem' # Rename, Delete, RunJob, EditJob?
                    }
                }
            } `
            -Columns @(
                Initialize-PodeWebTableColumn -Key Type -Width '5' -Alignment Center
                Initialize-PodeWebTableColumn -Key Status -Width '5' -Alignment Center
                Initialize-PodeWebTableColumn -Key Name -Width '50'
                Initialize-PodeWebTableColumn -Key LastUpdated -Width '30' -Name 'Last Updated' -Icon 'calendar'
                Initialize-PodeWebTableColumn -Key Actions -Width '10' -Icon 'zap'
            )
        )
    }

    # render runs table for a job
    #TODO: run button
    if ($meta.Type -ieq 'job') {
        New-PodeWebCard -Content @(
            New-PodeWebTable -Name 'Runs' -DataColumn Name -Click -NoExport -ScriptBlock {
                $meta = Get-PodeBuildJobMeta
                $meta.Items = ($meta.Items | Sort-Object -Descending -Property Name)

                foreach ($item in $meta.Items) {
                    [ordered]@{
                        Status = (Convert-PodeBuildStatusToElement -Type $item.Status)
                        Name = $item.Name
                        Duration = "$($item.Duration)s"
                        StartTime = $item.StartTime
                        Actions = 'Lorem' # Download
                    }
                }
            } `
            -Columns @(
                Initialize-PodeWebTableColumn -Key Status -Width '5' -Alignment Center
                Initialize-PodeWebTableColumn -Key Name -Width '45'
                Initialize-PodeWebTableColumn -Key Duration -Width '10' -Icon 'clock'
                Initialize-PodeWebTableColumn -Key StartTime -Width '30' -Name 'Start Time' -Icon 'calendar'
                Initialize-PodeWebTableColumn -Key Actions -Width '10' -Icon 'zap'
            )
        )
    }


    # render run info for a run
    #TODO: download log button

}