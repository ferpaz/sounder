using System.Diagnostics;

namespace Sounder;

internal static class Playback
{
    internal const string StopFile = "stopfile";

    internal static Task<int> RunAsync(string path, int loops, int? milliseconds,
        bool asynchronous, CancellationToken cancellationToken) => Task.Run(() =>
    {
        if (loops == 0 && !asynchronous) return 0;
        using var lifetime = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        if (milliseconds is int timeout) lifetime.CancelAfter(timeout);
        var watch = Stopwatch.StartNew();
        using var audio = new NativeAudio(path);
        var cleanedStaleSignal = false;
        long nextStopCheck = 150;
        long completed = 0;
        if (lifetime.IsCancellationRequested) return cancellationToken.IsCancellationRequested ? 130 : 0;
        audio.Play();
        while (true)
        {
            // One worker owns every native command, including stop/close on disposal.
            if (lifetime.Token.WaitHandle.WaitOne(20))
                return cancellationToken.IsCancellationRequested ? 130 : 0;

            if (watch.ElapsedMilliseconds >= nextStopCheck)
            {
                if (!cleanedStaleSignal)
                {
                    File.Delete(StopFile);
                    cleanedStaleSignal = true;
                }
                else if (File.Exists(StopFile)) return 0;
                nextStopCheck = watch.ElapsedMilliseconds + 100;
            }

            // Async ignores /loop and stays alive until its timer, even after EOF.
            if (!asynchronous && !audio.IsPlaying)
            {
                completed++;
                if (loops != -1 && completed >= loops) return 0;
                if (!lifetime.IsCancellationRequested) audio.Play();
            }
        }
    }, CancellationToken.None);
}
