$Root = Split-Path -Parent $PSScriptRoot
$DefaultMakefile = "$Root\Microsoft.AspNetCore.Build\msbuild\DefaultMakefile.proj"
$DefaultTasksMakefile = "$Root\Microsoft.AspNetCore.Build\msbuild\DefaultTasksMakefile.proj"

& "$Root\init\init-aspnet-build.ps1"

function GetMakefileFor($dir) {
    $candidate = Join-Path $dir "makefile.proj"
    if(Test-Path $candidate) {
        $candidate
    } else {
        $DefaultMakefile
    }
}

function banner($msg) {
    Write-Host -ForegroundColor Cyan "******"
    Write-Host -ForegroundColor Cyan $msg
    Write-Host -ForegroundColor Cyan "******"
}

# Scan the args to identify if we're build a project or repo
$sawProject = $false
$projectDir = $null;
$makefile = $null;
$newArgs = @($args | ForEach {
    if($_) {
        if($_.StartsWith("/") -or $_.StartsWith("-")) {
            # Pass through all switches
            $_
        }
        else {
            $sawProject = $true
            if(Test-Path $_) {
                # It's a thing that exists :). But is it a project or a directory?
                $item = Get-Item $_
                if($item.PSIsContainer) {
                    # It's a directory, treat it as an ASP.NET Repo
                    $projectDir = $item.FullName
                    $makefile = GetMakefileFor $_
                } else {
                    # It's a file, we don't want that in this case
                    throw "You can't use aspnet-build to launch an MSBuild project. Use msbuild directly for that."
                }
            }
        }
    }
})

if(!$sawProject) {
    $projectDir = Convert-Path .
    $makefile = GetMakefileFor $projectDir 
}

$oldPath = $env:PATH
try {
    $env:PATH="$env:LOCALAPPDATA\Microsoft\dotnet;$env:PATH"

    # Check the dotnet cli setup
    $expectedVer = cat "$Root\dotnet-install\dotnet-version.txt"
    $actualVer = dotnet --version
    if($expectedVer -ne $actualVer) {
        throw "Expected version '$expectedVer' but dotnet --version returned '$actualVer'. Do you have the correct SDK version in your global.json?"
    }

    $Artifacts = Join-Path $projectDir "artifacts"
    if(!(Test-Path $Artifacts)) {
        mkdir $Artifacts | Out-Null
    }
    $Artifacts = Convert-Path $Artifacts
    $Logs = Join-Path $Artifacts "logs"

    if(!(Test-Path $Logs)) {
        mkdir $Logs | Out-Null
    }


    $MainLog = Join-Path $Logs "msbuild.log"
    $TasksLog = Join-Path $Logs "tasks.msbuild.log"
    $ErrLog = Join-Path $Logs "msbuild.err"
    $WrnLog = Join-Path $Logs "msbuild.wrn"
    
    # Check if we need to build tasks first
    $TasksDir = Join-Path $projectDir "tasks"
    if(Test-Path $TasksDir) {
        $Proj = Join-Path $TasksDir "makefile.proj"
        if(!(Test-Path $Proj)) {
            $Proj = $DefaultTasksMakefile
        }
        Write-Host "Building Tasks"
        banner "dotnet build3 $Proj $newArgs"
        try {
            pushd $TasksDir
            dotnet build3 $Proj /v:q "/flp:ShowTimestamp;PerformanceSummary;Verbosity=Detailed;LogFile=`"$TasksLog`"" "/p:AspNetBuildRoot=`"$Root`""
            if($LASTEXITCODE -ne 0) {
                throw "Tasks build failed"
            }
        } finally {
            popd
        }
    }

    $newArgs += @("/p:AspNetBuildRoot=$Root")
    $newArgs += @("/flp1:ShowTimestamp;PerformanceSummary;Verbosity=Detailed;LogFile=`"$MainLog`"")
    $newArgs += @("/flp2:ErrorsOnly;LogFile=`"$ErrLog`"")
    $newArgs += @("/flp3:WarningsOnly;LogFile=`"$WrnLog`"")

    banner "dotnet build3 $makefile $newArgs"
    try {
        pushd $projectDir
        dotnet build3 $makefile @newArgs
        if($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
    } finally {
        popd
    }
} finally {
    popd
    $env:PATH = $oldPath
}