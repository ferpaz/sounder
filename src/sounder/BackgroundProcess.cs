using System.ComponentModel;
using System.Globalization;
using System.Runtime.InteropServices;

namespace Sounder;

internal static partial class BackgroundProcess
{
    private const uint CreateNoWindow = 0x08000000;

    internal static unsafe void Start(string path, int loops, int? milliseconds, bool asynchronous, bool ignoreAudioErrors)
    {
        var executable = Environment.ProcessPath ?? throw new IOException("Cannot locate the Sounder executable.");
        var arguments = new List<string> { QuoteFile(executable) };
        // Support both the apphost/single EXE and development via `dotnet sounder.dll`.
        if (Path.GetFileNameWithoutExtension(executable).Equals("dotnet", StringComparison.OrdinalIgnoreCase))
            arguments.Add(QuoteFile(Path.GetFullPath(Environment.GetCommandLineArgs()[0])));
        // Forward parsed values, excluding --background, so the child cannot relaunch itself.
        arguments.Add("--loop");
        arguments.Add(loops.ToString(CultureInfo.InvariantCulture));
        if (milliseconds is int timeout)
        {
            arguments.Add("--timer");
            arguments.Add(timeout.ToString(CultureInfo.InvariantCulture));
        }
        if (asynchronous) arguments.Add("--async");
        if (ignoreAudioErrors) arguments.Add("--ignore-audio-errors");
        arguments.Add("--");
        arguments.Add(QuoteFile(path));
        var command = (string.Join(' ', arguments) + '\0').ToCharArray();
        var startup = new StartupInfo { Size = (uint)Marshal.SizeOf<StartupInfo>() };
        fixed (char* commandLine = command)
        {
            // No shell, no console and no inherited handles (including redirected pipes).
            // Keep the same working directory so relative paths and /stop share their scope.
            if (!CreateProcess(executable, commandLine, 0, 0, false, CreateNoWindow,
                0, Environment.CurrentDirectory, ref startup, out var process))
                throw new Win32Exception(Marshal.GetLastPInvokeError(), "Cannot start background playback.");
            CloseHandle(process.Thread);
            CloseHandle(process.Process);
        }
    }

    // All quoted values are existing Windows file paths: no embedded quotes or trailing slash.
    private static string QuoteFile(string path) => $"\"{path}\"";

    [LibraryImport("kernel32.dll", EntryPoint = "CreateProcessW", SetLastError = true,
        StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static unsafe partial bool CreateProcess(string applicationName, char* commandLine,
        nint processAttributes, nint threadAttributes, [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
        uint creationFlags, nint environment, string currentDirectory,
        ref StartupInfo startupInfo, out ProcessInformation processInformation);

    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CloseHandle(nint handle);

    [StructLayout(LayoutKind.Sequential)]
    private struct StartupInfo
    {
        public uint Size;
        public nint Reserved, Desktop, Title;
        public uint X, Y, XSize, YSize, XCountChars, YCountChars, FillAttribute, Flags;
        public ushort ShowWindow, ReservedSize;
        public nint ReservedBytes, StandardInput, StandardOutput, StandardError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInformation
    {
        public nint Process, Thread;
        public uint ProcessId, ThreadId;
    }
}
