function Install-SteamCMD
{
    <#
        .SYNOPSIS
        Downloads the SteamCMD zip to $Path, extracts the EXE and then installs SteamCMD to $Path.

        .PARAMETER Path
        Specifies the path to the directory to install SteamCMD in.

        .EXAMPLE
        PS> Install-SteamCMD -Path D:\SteamCMD -Verbose
    #>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [String]
        $Path
    )
 
    # Create/Validate path
    $TestPath = Test-Path -Path $Path
    if(-not($TestPath))
    {
        [System.IO.Directory]::CreateDirectory($Path)
    }

    # Download SteamCMD
    Write-Verbose "Downloading steamcmd.zip to $Path."
    $OutFile = $Path + '\' + 'steamcmd.zip'
    $TestZipPath = Test-Path -Path $OutFile
    if ($TestZipPath)
    {
        Write-Verbose "Verified that $Path already exists."
    }
    else
    {
        try 
        {
            Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $OutFile -ErrorAction Stop
            Write-Verbose 'steamcmd.zip downloaded successfully.' 
        }
        catch
        {
            Write-Verbose "Couldn't download steamcmd.zip."
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    # Extract SteamCMD.zip
    $ExePath = $Path + '\' + 'steamcmd.exe' 
    $TestExePath = Test-Path -Path $ExePath
    Write-Verbose 'Extracting steamcmd.exe from steamcmd.zip.'
    if ($TestExePath)
    {
        Write-Verbose "File steamcmd.exe already exists at $Path."
    }
    else
    {
        try 
        {
            Expand-Archive $OutFile -DestinationPath $Path -ErrorAction Stop
            Write-Verbose 'steamcmd.exe extracted successfully.'   
        }
        catch
        {
            Write-Verbose "Couldn't extract steamcmd.zip."
            Write-Host $_.Exception.Message -ForegroundColor Red
        }  
    }

    # Install SteamCMD
    Write-Verbose 'Installing SteamCMD.'
    try 
    {
        Start-Process -FilePath $ExePath -ArgumentList "+quit" -Wait -ErrorAction Stop
        Write-Verbose 'SteamCMD install complete.'
    }
    catch
    {
        Write-Verbose "SteamCMD install failed."
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Function Install-7D2DServer
{
    <#
        .SYNOPSIS
        Runs Install-SteamCMD to install SteamCMD at $PathToSteamCMD and then installs the 7D2D Server to $PathTo7D2D.

        .PARAMETER PathToSteamCMD
        Specifies the path to the directory to install 7D2D in.

        .PARAMETER PathTo7D2D
        Specifies the path to the directory to install 7D2D in.

        .EXAMPLE
        PS> Install-7D2DServer -PathToSteamCMD D:\SteamCMD -PathTo7D2D D:\7D2D -Verbose
    #>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [String]
        $PathToSteamCMD,

        [parameter(Mandatory)]
        [String]
        $PathTo7D2D
    )

    # Make sure SteamCMD is installed at requested location.
    $SteamCMDTestPath = Test-Path -Path $PathToSteamCMD
    if (-not($SteamCMDTestPath))
    {
        [System.IO.Directory]::CreateDirectory($Path)  
    }    
    Install-SteamCMD -Path $PathToSteamCMD

    # Install 7D2D Server.
    Write-Verbose 'Installing 7D2D Server.'
    $SteamCMDEXE = $PathToSteamCMD + '/' + 'steamcmd.exe'
    try
    {
        Start-Process $SteamCMDEXE -ArgumentList "+login anonymous +force_install_dir $PathTo7D2D +app_update 294420 +quit" -Wait -ErrorAction Stop
        Write-Verbose '7D2D Server install complete.'
    }
    catch
    {
        Write-Verbose "7D2D Server install failed."
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function Update-7D2DServer
{
    <#
        .SYNOPSIS
        Shuts down 7D2D server, checks for updates, if available it installs them then it reboots.

        .PARAMETER PathToSteamCMD
        Specifies the path to the directory to Update SteamCMD in.

        .PARAMETER PathTo7D2D
        Specifies the path to the directory to Update 7D2D in.

        .EXAMPLE
        PS> Update-7D2DServer -PathToSteamCMD D:\SteamCMD -PathTo7D2D D:\7D2D -Verbose
    #>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [String]
        $PathToSteamCMD,

        [parameter(Mandatory)]
        [String]
        $PathTo7D2D
    )

    # Script Variables
    $SteamCMDOptions = "+login anonymous +force_install_dir $PathTo7D2D +app_update 294420 +quit"
    $PathToStartupScript = $PathTo7D2D + '\startdedicated.bat'

    # Kill the server until it's dead.
    Write-Verbose 'Shutting down the 7D2D server!'
    do
    {
        Stop-Process -Name 7DaysToDieServer -Force         
    }
    until ( $null -eq  (Get-Process -Name 7DaysToDieServer) ) 

    # Launch SteamCMD.exe and update game files.
    Write-Verbose 'Launching SteamCMD to check for updates.'
    try 
    {
        Start-Process -FilePath $PathToSteamCMD -ArgumentList $SteamCMDOptions -ErrorAction Stop
        Write-Verbose 'Waiting for SteamCMD to finish.'
        Wait-Process steamcmd
        Write-Verbose 'SteamCMD update process complete.'
    }
    catch 
    {
        Write-Verbose "7D2D Server update failed."
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    # Start the 7D2D server back up.
    Write-Verbose 'Starting the 7D2D server back up!'
    try 
    {
        Start-Process -FilePath $PathToStartupScript
    }
    catch 
    {
        Write-Verbose 'Failed to start the 7D2D server.'
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

function New-7D2DScheduledTask
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [String]
        $PathTo7D2D
    )
    <#
        .SYNOPSIS
        Creates a scheduled task to start the 7 Days To Die server automatically when the server boots up.

        .PARAMETER PathTo7D2D
        Specifies the path to the directory where 7 Days To Die is installed.

        .EXAMPLE
        PS> New-7D2DScheduledTask -PathTo7D2D $PathTo7D2D
    #>
    
    # Variable to startup script location.
    $PathToStartupScript = $PathTo7D2D + '\startdedicated.bat'
    
    # Building the scheduled task so that it can be registered.
    $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest    
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Action = New-ScheduledTaskAction -Execute $PathToStartupScript -WorkingDirectory $PathTo7D2D

    # Actually scheduling the task.
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName '7D2D Server Startup' -Description 'Runs the startdedicated.bat at server startup.' -Principal $principal
}

function Start-7D2DServerSetup
{
    <#
        .SYNOPSIS
        This is the build function for the toolset. Run this function to run the full 7D2D Server build process.

        .PARAMETER PathToSteamCMD
        Specifies the path to the directory to install SteamCMD in.

        .PARAMETER PathTo7D2D
        Specifies the path to the directory to install 7D2D in.
        
        .EXAMPLE
        PS> Start-7D2DServerSetup -PathToSteamCMD D:\SteamCMD -PathTo7D2D D:\7d2d -Verbose
    #>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        [String]
        $PathToSteamCMD,

        [parameter(Mandatory)]
        [String]
        $PathTo7D2D
    )
    
    # Install SteamCMD.
    Install-SteamCMD -Path $PathToSteamCMD

    # Install the 7 Days To Die dedicated server.
    Install-7D2DServer -PathToSteamCMD $PathToSteamCMD -PathTo7D2D $PathTo7D2D

    # Add task to Task Scheduler to run the startup script located in the 7 Days to Die install folder during server startup as SYSTEM.
    New-7D2DScheduledTask -PathTo7D2D $PathTo7D2D
}
