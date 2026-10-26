# Sounder 2.0.0

Reproductor de archivos WAV desde la línea de comandos para **Windows x64 y Windows ARM64**, desarrollado en **.NET 10**.

El Sounder original fue creado por **Eli Fulkerson en 2012**. El último instalador encontrado por el responsable de este proyecto data de **2017**; la versión original está sin mantenimiento. Esta versión continúa su utilidad con una implementación actualizada. Autor original: [Eli Fulkerson](https://www.elifulkerson.com/).

## Uso

```powershell
sounder.exe "C:\Sonidos\aviso.wav"
sounder.exe /loop 3 "C:\Sonidos\aviso.wav"
sounder.exe /loop -1 /timer 10000 "C:\Sonidos\aviso.wav"
sounder.exe /async /timer 2000 "C:\Sonidos\aviso.wav"
sounder.exe --background "C:\Sonidos\aviso.wav"
sounder.exe -b --loop 3 "C:\Sonidos\aviso.wav"
sounder.exe /stop
sounder.exe /help
sounder.exe /version
```

| Parámetro | Alias compatibles | Comportamiento |
| --- | --- | --- |
| `/stop` | `-s`, `/s`, `/S`, `--stop` | Crea `stopfile` en el directorio de trabajo para detener las reproducciones iniciadas allí. |
| `/loop times` | `-l`, `/l`, `/L`, `--loop` | Reproduce el número indicado de veces. `-1`: indefinidamente; `0`: ninguna. Por defecto reproduce una vez. |
| `/timer ms` | `-t`, `/t`, `/T`, `--timer` | Limita la ejecución a un número positivo de milisegundos. |
| `/async` | `-a`, `/a`, `/A`, `--async` | Reproduce una vez de forma asíncrona; mantiene el proceso vivo hasta el límite de `/timer` (2000 ms por defecto), aunque termine el WAV. Ignora `/loop`. |
| `--background` | `-b` | Inicia una instancia oculta y devuelve el control inmediatamente. Por defecto reproduce el WAV completo; respeta `/loop`, `/timer` y `/stop`. |
| `/help` | `-h`, `/h`, `/H`, `/?`, `--help`, `-?` | Muestra ayuda en la consola. Sin argumentos también muestra ayuda. |
| `/version` | `-v`, `/v`, `/V`, `--version` | Muestra la versión. |

Normalmente el proceso espera hasta terminar la reproducción, recibir `/stop`, alcanzar el temporizador o recibir Ctrl+C. `/async` cambia el modo de reproducción, pero no convierte la aplicación en un proceso desligado de la consola.

Con `-b` o `--background`, la instancia inicial termina después de iniciar otra instancia de Sounder sin ventana de consola, usando el mismo directorio de trabajo. El WAV continúa hasta terminar: **no hay un límite de 2000 ms por defecto en este modo**. Puedes combinarlo con `--loop` o `--timer` y detenerlo ejecutando `sounder.exe /stop` desde ese mismo directorio. Ctrl+C en la consola original no detiene la instancia oculta. Si agregas también `--async`, se conserva su comportamiento original, incluido el límite predeterminado de 2000 ms y la precedencia sobre `/loop`.

El código de salida de la instancia inicial indica si se pudo iniciar el proceso: `0` significa que Windows lo creó. Los argumentos y la existencia del archivo se validan antes del lanzamiento; los errores posteriores de audio ocurren en la instancia oculta y no se devuelven a la consola original. Para diagnosticarlos, ejecuta el mismo comando sin `--background`.

`/stop` puede utilizarse sin archivo. Si también se indica un WAV, envía la señal y comienza la nueva reproducción. Los procesos que se deban comunicar tienen que compartir el **directorio de trabajo**, que debe ser escribible. Al iniciar, cada reproductor descarta un `stopfile` anterior después de 150 ms; las señales posteriores se comprueban cada 100 ms. Evita enviar `/stop` durante ese período inicial. El archivo de señal permanece hasta que otra reproducción lo limpia.

Se admiten rutas con espacios y caracteres Unicode; usa comillas y, para nombres que comiencen con un guion, `--` antes de la ruta. Windows debe disponer de un dispositivo de audio y admitir el formato WAV. Los valores numéricos ausentes, no enteros o fuera de rango generan un error. La ayuda y la versión se muestran en consola. Los códigos de salida son `0` para finalización normal, temporizador o `/stop`, `1` para errores y `130` para cancelación con Ctrl+C.

## Desarrollo

Requiere Windows y el SDK de .NET 10. Abre `src/sounder.slnx` en una versión de Visual Studio compatible con .NET 10, o abre el repositorio en Visual Studio Code con C# Dev Kit.

Desde la raíz:

```powershell
dotnet restore .\src\sounder.slnx --locked-mode
dotnet build .\src\sounder.slnx -c Release --no-restore
dotnet run --project .\src\sounder -- /help
pwsh -NoProfile -File .\src\tests\Smoke.ps1
```

Los parámetros se analizan con [System.CommandLine 2.0.13](https://www.nuget.org/packages/System.CommandLine/2.0.13), paquete de Microsoft ampliamente utilizado en NuGet. La reproducción usa la API de audio de Windows.

## Publicación: un EXE por arquitectura

Desde la raíz del repositorio:

```powershell
# Publica ambas arquitecturas
pwsh -NoProfile -File .\src\Publish.ps1

# O publica solo una
pwsh -NoProfile -File .\src\Publish.ps1 -Runtime win-x64
pwsh -NoProfile -File .\src\Publish.ps1 -Runtime win-arm64
```

También puedes ejecutar directamente:

```powershell
dotnet publish .\src\sounder\sounder.csproj -c Release -r win-x64 --self-contained true
dotnet publish .\src\sounder\sounder.csproj -c Release -r win-arm64 --self-contained true
```

El proyecto configura la publicación como archivo único, incluye el runtime .NET y lleva los símbolos de depuración dentro del binario. Los resultados se ubican automáticamente en:

```text
publish/
  2.0.0/
    win-x64/sounder.exe
    win-arm64/sounder.exe
```

Cada distribución contiene un único `sounder.exe`; el usuario no necesita instalar .NET. Durante la ejecución, .NET puede extraer sus bibliotecas nativas en su directorio temporal. `winmm.dll` es un componente de Windows. El archivo WAV se proporciona por separado. No se admiten Windows x86, ARM de 32 bits, Linux ni macOS. La arquitectura ARM soportada es ARM64.

La versión se define en `src/sounder/sounder.csproj`. Al incrementarla, actualiza también `AssemblyVersion`, `FileVersion` y el texto de presentación. La ruta de publicación usa esa versión automáticamente. `publish/` y los archivos generados de compilación y del IDE están excluidos de Git.
