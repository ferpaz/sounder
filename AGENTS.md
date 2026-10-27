# Instructions for agents

- The product is Sounder 2.0.0: a console WAV player written in C# with .NET 10, exclusively for Windows x64 and ARM64. Do not add support for other operating systems, ARM32, or x86.
- The solution is `src/sounder.slnx`; the main project is `src/sounder/sounder.csproj`.
- Preserve all parameters and aliases documented in README, including `/async`, `/loop -1`, `/stop` without a file, and communication through `stopfile` in the working directory.
- Preserve the credit to Eli Fulkerson, who created the original in 2012; 2017 is the date of the latest installer found, not the confirmed creation year.
- Keep System.CommandLine as the argument parser. Do not replace it with a manual parser. Update `packages.lock.json` if dependencies change.
- Keep slash aliases supported (including /B for background), but hide them from help. Parse all aliases first, then remove them from the model only after Parse and before InvokeAsync; do not remove them before parsing. Help and descriptions must use options starting with a hyphen.
- `-b` / `--background` starts a hidden instance of the same executable and returns control. Without `/async` or `/timer`, play the entire WAV. Preserve `/loop` and the working directory for `/stop`. Do not inherit the console or input/output handles; do not forward the background flag to the child. Maintain support for the apphost, published EXE, and `dotnet sounder.dll`.
- Preserve the default 2000 ms limit for `/async`, its precedence over `/loop`, the initial cleanup of `stopfile` after 150 ms, and subsequent checks every 100 ms. Document any deliberate compatibility change.
- Interoperability is implemented in NativeAudio.cs: MCI waveaudio with Unicode commands and MCI error codes. Open, play, query status, and close on the same worker; maintain ARM64 compatibility.
- Playback failures use AudioPlaybackException and display a diagnostic: stderr and exit code 1 by default; stdout and exit code 0 with --ignore-audio-errors (avoid populating the PS1 error stream). If Windows exposes no output devices, use NoAudioDeviceException and its specific message. Do not turn other errors into success: invalid parameters, missing filename, nonexistent file, path/permission/stopfile issues, and background launch errors retain exit code 1 even with the option; Ctrl+C retains 130. Forward --ignore-audio-errors to the background child without adding any wait or audio confirmation.
- Stop audio and wait for the worker on exit; avoid orphaned tasks or processes. Check the timer, cancellation, and external stop signal when changing concurrency.
- Build: `dotnet build src/sounder.slnx -c Release`. Validate: `pwsh -NoProfile -File src/tests/Smoke.ps1`. Playback tests require a Windows audio device and use silent WAV files.
- Publish through `src/Publish.ps1` or `dotnet publish` with an explicit RID. Keep a single self-contained EXE in `publish/<Version>/<RuntimeIdentifier>/`. Test the x64 EXE on this host; do not claim native ARM64 execution without an ARM64 host.
- Do not commit `publish/`, `bin/`, `obj/`, local tools, IDE files, or temporary artifacts. Check `git status` and `git diff --check` before finishing.
- Keep README focused on product usage and development. Executable analysis notes belong in `docs/RECONSTRUCTION.md`, not README.
- When changing the version, update Version, AssemblyVersion, FileVersion, and the introductory text. Do not assign a license to the original code without evidence of its license.
