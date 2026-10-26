[CmdletBinding()]
param([string] $Executable = (Join-Path $PSScriptRoot '../sounder/bin/Release/net10.0-windows/sounder.exe'))
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Tests require Windows.' }
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sounder-tests-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$running = [Collections.Generic.List[Diagnostics.Process]]::new()

function Start-Sounder([string[]] $Arguments, [switch] $Managed) {
    $info = [Diagnostics.ProcessStartInfo]::new($(if ($Managed) { (Get-Command dotnet).Source } else { $Executable }))
    if ($Managed) { $info.ArgumentList.Add([IO.Path]::ChangeExtension($Executable, '.dll')) }
    $info.WorkingDirectory = $scratch
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($info)
    $running.Add($process)
    return $process
}
function Invoke-Sounder([string[]] $Arguments, [int] $ExitCode = 0) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Sounder $Arguments
    if (-not $process.WaitForExit(10000)) { throw "Timed out: $Arguments" }
    $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
    if ($process.ExitCode -ne $ExitCode) { throw "Exit $($process.ExitCode), expected $ExitCode for '$Arguments': $output" }
    return @{ Output = $output; Elapsed = $watch.ElapsedMilliseconds }
}
function Assert-That([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

function Start-BackgroundPlayer([string[]] $Arguments, [switch] $Managed) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $launcher = Start-Sounder $Arguments -Managed:$Managed
    Assert-That ($launcher.WaitForExit(1500)) 'Background launcher waited for playback.'
    Assert-That ($launcher.ExitCode -eq 0) 'Background launch failed.'
    # EOF must arrive even while the hidden child is playing: no inherited pipe handles.
    $stdout = $launcher.StandardOutput.ReadToEndAsync()
    $stderr = $launcher.StandardError.ReadToEndAsync()
    Assert-That ($stdout.Wait(1000) -and $stderr.Wait(1000)) 'Background child inherited the caller pipes.'
    Assert-That ($watch.ElapsedMilliseconds -lt 1500) 'Background launch did not return promptly.'
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $($launcher.Id)")
    Assert-That ($children.Count -eq 1) 'Expected exactly one hidden playback child.'
    $child = [Diagnostics.Process]::GetProcessById($children[0].ProcessId)
    # Keep a real handle while observing a process we did not start via Process.Start.
    # Otherwise Windows can discard its exit status before PowerShell queries it.
    $null = $child.Handle
    $running.Add($child)
    Assert-That ($child.MainWindowHandle -eq 0) 'Background player has a visible window.'
    return $child
}

try {
    # Three seconds of silent mono PCM, 8 kHz / 16-bit, including a Unicode filename.
    $wave = Join-Path $scratch 'silencio á.wav'
    $stream = [IO.File]::Create($wave)
    $writer = [IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int]48036)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]8000)
        $writer.Write([int]16000)
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]48000)
        $writer.Write([byte[]]::new(48000))
    } finally { $writer.Dispose() }

    foreach ($alias in @('-h','/h','/H','/?','/help','--help','-?')) {
        Assert-That ((Invoke-Sounder @($alias)).Output.Contains('Usage:')) "Missing help alias $alias"
    }
    Assert-That ((Invoke-Sounder @()).Output.Contains('Usage:')) 'No-argument help failed.'
    foreach ($alias in @('-v','/v','/V','/version','--version')) {
        Assert-That ((Invoke-Sounder @($alias)).Output.Trim() -eq '2.0.0') "Missing version alias $alias"
    }
    foreach ($alias in @('-s','/s','/S','/stop','--stop')) {
        Invoke-Sounder @($alias) | Out-Null
        Assert-That (Test-Path -LiteralPath (Join-Path $scratch 'stopfile')) "Missing stop alias $alias"
        [IO.File]::Delete((Join-Path $scratch 'stopfile'))
    }
    foreach ($alias in @('-l','/l','/L','/loop','--loop')) { Invoke-Sounder @($alias,'0',$wave) | Out-Null }
    foreach ($alias in @('-t','/t','/T','/timer','--timer')) {
        $result = Invoke-Sounder @($alias,'350','/loop','-1',$wave)
        Assert-That ($result.Elapsed -ge 300 -and $result.Elapsed -lt 2500) "Timer failed: $alias, $($result.Elapsed) ms"
    }
    foreach ($alias in @('-a','/a','/A','/async','--async')) {
        $result = Invoke-Sounder @($alias,'/timer','350',$wave)
        Assert-That ($result.Elapsed -ge 300 -and $result.Elapsed -lt 2500) "Async alias failed: $alias"
    }
    foreach ($arguments in @(
        @('/loop','bad',$wave), @('/loop','-2',$wave), @('/timer','0',$wave),
        @('/timer','bad',$wave), @('/timer'), @('/loop'), @('--unknown'),
        @('/timer','2147483648',$wave), @('missing.wav'), @($wave,$wave)
        @('-b','missing.wav'), @('--background','/loop','bad',$wave), @('--background')
    )) { Invoke-Sounder $arguments 1 | Out-Null }

    $once = Invoke-Sounder @($wave)
    $twice = Invoke-Sounder @('/loop','2',$wave)
    Assert-That ($once.Elapsed -ge 2500 -and $twice.Elapsed -ge ($once.Elapsed + 2000)) 'Loop count / natural completion failed.'
    $asyncDefault = Invoke-Sounder @('/async','/loop','-1',$wave)
    Assert-That ($asyncDefault.Elapsed -ge 1900 -and $asyncDefault.Elapsed -lt 2900) 'Default async lifetime failed.'

    $player = Start-Sounder @('/loop','-1',$wave)
    Start-Sleep -Milliseconds 700
    Assert-That (-not $player.HasExited) 'Infinite loop exited early.'
    Invoke-Sounder @('/stop') | Out-Null
    Assert-That ($player.WaitForExit(2000)) 'External /stop did not stop the player.'
    Assert-That ($player.ExitCode -eq 0) 'External /stop returned an error.'

    # A stale signal must not stop a newly launched player.
    $stale = Invoke-Sounder @('/timer','700',$wave)
    Assert-That ($stale.Elapsed -ge 650) 'Stale stopfile interrupted playback.'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $scratch 'stopfile'))) 'Stale stopfile was not cleaned.'
    foreach ($alias in @('-b', '--background')) {
        # A relative Unicode path also proves preservation of the working directory.
        $background = Start-BackgroundPlayer @($alias, [IO.Path]::GetFileName($wave))
        Start-Sleep -Milliseconds 2200
        Assert-That (-not $background.HasExited) 'Background default unexpectedly cut the WAV at 2000 ms.'
        Assert-That ($background.WaitForExit(2500)) 'Background player did not exit at EOF.'
        Assert-That ($background.ExitCode -eq 0) "Background WAV playback failed: exit $($background.ExitCode)."
    }
    $backgroundLoop = Start-BackgroundPlayer @('-b','--loop','2',$wave)
    Start-Sleep -Milliseconds 3300
    Assert-That (-not $backgroundLoop.HasExited) 'Background loop did not start its second playback.'
    Invoke-Sounder @('/stop') | Out-Null
    Assert-That ($backgroundLoop.WaitForExit(2000)) 'Background /stop failed or working directory changed.'
    Assert-That ($backgroundLoop.ExitCode -eq 0) 'Background /stop returned an error.'

    $backgroundTimer = Start-BackgroundPlayer @('--background','--loop','-1','--timer','2000',$wave)
    Assert-That ($backgroundTimer.WaitForExit(3000)) 'Background timer failed.'
    Assert-That ($backgroundTimer.ExitCode -eq 0) 'Background timer returned an error.'
    $backgroundAsync = Start-BackgroundPlayer @('-b','--async','--loop','-1',$wave)
    Assert-That ($backgroundAsync.WaitForExit(3000)) 'Background did not preserve async lifetime.'
    Assert-That ($backgroundAsync.ExitCode -eq 0) 'Background async returned an error.'

    if (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($Executable, '.dll'))) {
        $managedChild = Start-BackgroundPlayer @('-b',$wave) -Managed
        Assert-That ($managedChild.WaitForExit(5000)) 'Background failed with dotnet sounder.dll.'
        Assert-That ($managedChild.ExitCode -eq 0) 'Managed background playback failed.'
    }
    Write-Host 'PASS: aliases, validation, Unicode WAV, loops, timer, async, stopfile and detached background playback.'
} finally {
    foreach ($process in $running) {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
    # Delete only the uniquely created test directory under the system temp folder.
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedScratch.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        ([IO.Path]::GetFileName($resolvedScratch)).StartsWith('sounder-tests-')) {
        Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
    }
}
