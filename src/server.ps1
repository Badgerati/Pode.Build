Import-Module Pode -MaximumVersion 2.99.99 -Force
Import-Module ..\..\Pode.Web\src\Pode.Web.psm1 -Force
Import-Module ./tools.psm1 -Force

Start-PodeServer -Threads 2 -ScriptBlock {
    #TODO: bind the endpoint - but this can be configured via config (host, port, http(s))
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # enable error logging to file
    #TODO: this should be configurable - so for windows, could be event viewer
    # and configure the max days
    New-PodeLoggingMethod -File -Name 'errors' -MaxDays 30 | Enable-PodeErrorLogging
    # New-PodeLoggingMethod -File -Name 'requests' -MaxDays 30 | Enable-PodeRequestLogging

    # set the use of templates, and set a login page
    Use-PodeWebTemplates -Title 'Pode.Build' -Logo '/pode.web/images/icon.png' -Theme Auto

    #TODO: default is no auth, but this should be configurable

    #TODO: setup the home page - this could just be "recent jobs" or a dashboard of pode.build



    # load the main pages
    Use-PodeScript -Path ./Pages/jobs.ps1
    Use-PodeScript -Path ./Pages/settings.ps1
}