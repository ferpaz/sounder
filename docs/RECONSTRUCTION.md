# Analysis record

## Artifact identity

- Supplied file: `E:\vh4\MSBuild\sounder.exe`, 21,504 bytes.
- SHA-256: `6749f81e19c9646e24f3b271e8cdc0ae0163a169c9981a95d45cf10cfc323c63`.
- VB.NET/WinForms assembly, CLR v2.0.50727, AnyCPU IL, version 1.0.0.0.
- MVID: `5feef4a5-a3a5-48a9-8780-f7024b748585`.
- The embedded help identifies the version as August 3, 2012 and credits Eli Fulkerson. The user clarified that 2017 is the date of the latest installer found.

## Static evidence

REA inspected metadata and members without running the original:

- Identity: `ev_0d541917ded0d7054e0955e2b4ca03d7427cf429c02eb91ecb3a3950117bc78d`.
- Members of sounder.Form1: `ev_50409031c2e661e7437ba7a13608234ed756c864d9e7988591db22adbeb15a56`.
- Additional reconstruction with ILSpy CLI 11.1.0.9782, type `sounder.Form1`, cross-checked against strings and IL calls. Its output is reconstructed code, not the original source.

`Form1_Load` contains all preserved aliases. It enables polling timers, interprets `/loop` and `/timer`, creates `stopfile` for `/stop`, and adds SND_ASYNC for `/async`. `PlayWav` makes repeated synchronous calls to sndPlaySoundA; `-1` means an infinite loop. Asynchronous mode bypasses that worker and therefore ignores `/loop`. Both `/async` and `/timer` enable the termination timer; its default value is 2000 ms. The initial stopfile cleanup interval is 150 ms; stop checks use the default WinForms interval of 100 ms. The original process exits through Process.Kill.

## Implementation decisions

A console application without WinForms was created in C#/.NET 10 using System.CommandLine and MCI waveaudio (winmm.dll). It preserves the options and valid behavior described above while adding support for Unicode paths. Forced termination is replaced with cancellation and explicit device closure. An initial test with synchronous PlaySound showed that stopping waited until the WAV finished; the final implementation therefore queries MCI status and can stop the device from its owning worker. Help and version information go to the console rather than a window. Invalid numeric arguments are rejected instead of silently falling back to 2000/-1; unknown options and multiple files are rejected instead of taking the last token as the path. Playback errors produce exit code 1 by default. Accidental bugs in the original parser are not intended to be preserved.

The original was not executed; behavioral correspondence is based on static inspection. Implementation checks are automated in `src/tests/Smoke.ps1`. Physical audibility and native ARM64 execution require verification on the corresponding hardware.

## Version 2.0.0 verification

- SDK used: .NET 10.0.402; Release build completed without warnings or errors.
- Restore with `--locked-mode` verified.
- Smoke.ps1 completed against both the build executable and the published self-contained x64 EXE. It covers all aliases, help/version, invalid values, a Unicode path with spaces, the duration of one and two plays, an infinite loop, the timer, the default asynchronous lifetime, `/stop` from another process, and cleanup of an earlier signal. It uses silent PCM audio and does not demonstrate physical audibility.
- x64 and ARM64 publications: each folder contains only `sounder.exe`. Verified PE headers: AMD64 `0x8664` and ARM64 `0xAA64`, respectively.
- Publishing without a RID was rejected with a message requesting `win-x64` or `win-arm64`. ARM64 execution remains pending on compatible hardware.
