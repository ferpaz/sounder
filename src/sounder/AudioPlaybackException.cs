namespace Sounder;

// Only audio failures can be ignored by scripts. File/argument/launch errors stay errors.
internal class AudioPlaybackException(string message) : IOException(message);

internal sealed class NoAudioDeviceException() : AudioPlaybackException(
    "No hay un dispositivo de sonido disponible para reproducir archivos de audio.");
