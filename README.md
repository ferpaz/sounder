# Sounder 2.0.0

A command-line WAV player for **Windows x64 and Windows ARM64**, built with **.NET 10**.

The original Sounder was created by **Eli Fulkerson in 2012**. The latest installer found by this project's maintainer dates from **2017**; the original version is no longer maintained. This version continues its functionality with an updated implementation. Original author: [Eli Fulkerson](https://www.elifulkerson.com/).

## Usage

```powershell
sounder.exe "C:\Sounds\alert.wav"
sounder.exe /loop 3 "C:\Sounds\alert.wav"
sounder.exe /loop -1 /timer 10000 "C:\Sounds\alert.wav"
sounder.exe /async /timer 2000 "C:\Sounds\alert.wav"
sounder.exe --background "C:\Sounds\alert.wav"
sounder.exe -b --loop 3 "C:\Sounds\alert.wav"
sounder.exe --ignore-audio-errors "C:\Sounds\alert.wav"
sounder.exe /stop
sounder.exe /help
sounder.exe /version
```

| Parameter | Supported aliases | Behavior |
| --- | --- | --- |
| `/stop` | `-s`, `/s`, `/S`, `--stop` | Creates `stopfile` in the working directory to stop playback started there. |
| `/loop times` | `-l`, `/l`, `/L`, `--loop` | Plays the specified number of times. `-1`: indefinitely; `0`: no playback. Plays once by default. |
| `/timer ms` | `-t`, `/t`, `/T`, `--timer` | Limits execution to a positive number of milliseconds. |
| `/async` | `-a`, `/a`, `/A`, `--async` | Plays once asynchronously; keeps the process alive until the `/timer` limit (2000 ms by default), even if the WAV has finished. Ignores `/loop`. |
| `--background` | `-b`, `/B` | Starts a hidden instance and returns control immediately. Plays the entire WAV by default; respects `/loop`, `/timer`, and `/stop`. |
| `--ignore-audio-errors` | — | Displays audio playback failures but returns `0`. Parameter and file errors still return `1`. |
| `/help` | `-h`, `/h`, `/H`, `/?`, `--help`, `-?` | Displays console help. Running without arguments also displays help. |
| `/version` | `-v`, `/v`, `/V`, `--version` | Displays the version. |

Normally, the process waits until playback finishes, it receives `/stop`, the timer expires, or Ctrl+C is pressed. `/async` changes the playback mode but does not detach the application from the console.

Help displays only options starting with a hyphen. Slash aliases (`/stop`, `/L`, `/B`, etc.) remain supported for compatibility and are documented in the table above.

With `-b` or `--background`, the initial instance exits after starting another Sounder instance without a console window, using the same working directory. The WAV continues until it finishes: **there is no default 2000 ms limit in this mode**. You can combine it with `--loop` or `--timer` and stop it by running `sounder.exe /stop` from that same directory. Ctrl+C in the original console does not stop the hidden instance. If you also specify `--async`, its original behavior is preserved, including the default 2000 ms limit and precedence over `/loop`.

The initial instance's exit code indicates whether the process could be started: `0` means Windows created it. Arguments and file existence are validated before launch; subsequent audio errors occur in the hidden instance and are not returned to the original console. To diagnose them, run the same command without `--background`.

`/stop` can be used without a file. If a WAV is also specified, it sends the signal and starts the new playback. Processes that need to communicate must share the **working directory**, which must be writable. On startup, each player discards an old `stopfile` after 150 ms; subsequent signals are checked every 100 ms. Avoid sending `/stop` during that initial period. The signal file remains until another playback instance clears it.

Paths with spaces and Unicode characters are supported; use quotes and, for names starting with a hyphen, place `--` before the path. Windows must have an audio device and support the WAV format. Missing, non-integer, or out-of-range numeric values produce an error. Help and version information are displayed in the console.

By default, audio playback failures display a message and return `1`. To use Sounder as a notification inside BAT or PS1 scripts without an audio problem interrupting the script, add **`--ignore-audio-errors`**: it displays the same message but returns `0`. If Windows cannot find any available output device, Sounder displays a message explaining that no sound device is available to play audio files. Other audio errors retain the details reported by Windows. In `--background` mode, the option is forwarded to the hidden process; the initial instance still returns control without waiting for audio playback.

| Code | Meaning |
| --- | --- |
| `0` | Playback completed, timer expired, `/stop`, help/version, background launch, or an audio failure with `--ignore-audio-errors`. |
| `1` | Audio failure without `--ignore-audio-errors`; invalid parameters, missing filename, **nonexistent file**, path/permission/`stopfile` problems, or failure to start the hidden process (even with the option). |
| `130` | Manual cancellation with Ctrl+C. |

The option only ignores audio failures. For example, with `--ignore-audio-errors`, an existing file with an invalid WAV format displays the audio error and returns `0`; a path that does not exist returns `1`. Without that option, both return `1`. Tolerated audio notices are written to standard output (`stdout`) to avoid populating PowerShell's error stream; errors that are not ignored use `stderr`. Exit code `0` does not guarantee audible sound: the volume may be muted, or the output may be a virtual device.

## Development

Requires Windows and the .NET 10 SDK. Open `src/sounder.slnx` in a version of Visual Studio that supports .NET 10, or open the repository in Visual Studio Code with C# Dev Kit.

From the repository root:

```powershell
dotnet restore .\src\sounder.slnx --locked-mode
dotnet build .\src\sounder.slnx -c Release --no-restore
dotnet run --project .\src\sounder -- /help
pwsh -NoProfile -File .\src\tests\Smoke.ps1
```

Arguments are parsed with [System.CommandLine 2.0.13](https://www.nuget.org/packages/System.CommandLine/2.0.13), a widely used Microsoft package on NuGet. Playback uses the Windows audio API.

## Publishing: one EXE per architecture

From the repository root:

```powershell
# Publish both architectures
pwsh -NoProfile -File .\src\Publish.ps1

# Or publish just one
pwsh -NoProfile -File .\src\Publish.ps1 -Runtime win-x64
pwsh -NoProfile -File .\src\Publish.ps1 -Runtime win-arm64
```

You can also run these commands directly:

```powershell
dotnet publish .\src\sounder\sounder.csproj -c Release -r win-x64 --self-contained true
dotnet publish .\src\sounder\sounder.csproj -c Release -r win-arm64 --self-contained true
```

The project configures single-file publishing, includes the .NET runtime, and embeds debugging symbols in the binary. Output is automatically placed in:

```text
publish/
  2.0.0/
    win-x64/sounder.exe
    win-arm64/sounder.exe
```

Each distribution contains a single `sounder.exe`; users do not need to install .NET. At runtime, .NET may extract its native libraries to its temporary directory. `winmm.dll` is a Windows component. The WAV file is supplied separately. Windows x86, 32-bit ARM, Linux, and macOS are not supported. The supported ARM architecture is ARM64.

The version is defined in `src/sounder/sounder.csproj`. When incrementing it, also update `AssemblyVersion`, `FileVersion`, and the introductory text. The publish path uses that version automatically. `publish/` and generated build and IDE files are excluded from Git.
