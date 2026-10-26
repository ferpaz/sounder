using System.CommandLine;
using System.Runtime.InteropServices;

namespace Sounder;

internal static class Program
{
    private static async Task<int> Main(string[] args)
    {
        if (!OperatingSystem.IsWindows() || RuntimeInformation.ProcessArchitecture is not (Architecture.X64 or Architecture.Arm64))
        {
            Console.Error.WriteLine("Sounder requires Windows x64 or ARM64.");
            return 1;
        }

        var stop = new Option<bool>("--stop", "-s", "/s", "/S", "/stop")
        { Description = "Create stopfile in the working directory to stop existing playback." };
        var loop = new Option<int>("--loop", "-l", "/l", "/L", "/loop")
        { Description = "Number of plays; -1 repeats until stopped, 0 plays nothing.", DefaultValueFactory = _ => 1 };
        var timer = new Option<int?>("--timer", "-t", "/t", "/T", "/timer")
        { Description = "Stop after this many milliseconds (positive integer)." };
        var asyncOption = new Option<bool>("--async", "-a", "/a", "/A", "/async")
        { Description = "Use asynchronous playback; stay alive for /timer, or 2000 ms. Ignores /loop." };
        var file = new Argument<string?>("filename.wav") { Arity = ArgumentArity.ZeroOrOne, Description = "WAV file to play." };
        var root = new RootCommand("Sounder 2.0.0 — Windows WAV player. Original Sounder by Eli Fulkerson (2012).")
        { stop, loop, timer, asyncOption, file };
        var helpOption = root.Options.Single(o => o.Name == "--help");
        foreach (var alias in new[] { "/h", "/H", "/?", "/help" }) helpOption.Aliases.Add(alias);
        var versionOption = root.Options.Single(o => o.Name == "--version");
        foreach (var alias in new[] { "-v", "/v", "/V", "/version" }) versionOption.Aliases.Add(alias);

        root.SetAction(async (result, cancellationToken) =>
        {
            var loops = result.GetValue(loop);
            var timeout = result.GetValue(timer);
            var path = result.GetValue(file);
            if (loops < -1 || timeout is <= 0)
            {
                Console.Error.WriteLine("/loop must be -1 or greater; /timer must be a positive 32-bit integer.");
                return 1;
            }
            try
            {
                if (result.GetValue(stop))
                {
                    using var request = File.Create(Playback.StopFile);
                }
                if (path is null)
                {
                    if (result.GetValue(stop)) return 0;
                    Console.Error.WriteLine("Specify a WAV filename, or use /help.");
                    return 1;
                }
                path = Path.GetFullPath(path);
                if (!File.Exists(path))
                    throw new FileNotFoundException("WAV file not found.", path);
                var asynchronous = result.GetValue(asyncOption);
                return await Playback.RunAsync(path, loops, timeout ?? (asynchronous ? 2000 : null), asynchronous, cancellationToken);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
            {
                Console.Error.WriteLine($"sounder: {ex.Message}");
                return 1;
            }
        });
        return await root.Parse(args.Length == 0 ? ["--help"] : args).InvokeAsync();
    }
}
