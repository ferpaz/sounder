using System.Runtime.InteropServices;

namespace Sounder;

// MCI supports completion status and explicit stop. One worker owns the device.
internal sealed partial class NativeAudio : IDisposable
{
    private readonly string alias = "sounder_" + Guid.NewGuid().ToString("N");

    [LibraryImport("winmm.dll", EntryPoint = "mciSendStringW", StringMarshalling = StringMarshalling.Utf16)]
    private static unsafe partial uint SendString(string command, char* result, uint length, nint callback);

    [LibraryImport("winmm.dll", EntryPoint = "mciGetErrorStringW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static unsafe partial bool GetErrorString(uint error, char* result, uint length);

    internal NativeAudio(string path) => Command($"open \"{path}\" type waveaudio alias {alias}");
    internal void Play() => Command($"play {alias} from 0");
    internal bool IsPlaying => Command($"status {alias} mode") == "playing";

    private static unsafe string Command(string command)
    {
        const int capacity = 512;
        char* buffer = stackalloc char[capacity];
        buffer[0] = '\0';
        var error = SendString(command, buffer, capacity, 0);
        if (error != 0)
        {
            buffer[0] = '\0';
            var message = GetErrorString(error, buffer, capacity) ? new string(buffer) : $"MCI error {error}";
            throw new IOException($"Windows audio: {message}");
        }
        return new string(buffer);
    }

    public unsafe void Dispose()
    {
        // Close releases the device even if a previous stop failed.
        SendString($"stop {alias}", null, 0, 0);
        SendString($"close {alias}", null, 0, 0);
    }
}
