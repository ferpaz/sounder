# Registro del análisis

## Identidad del artefacto

- Archivo suministrado: `E:\vh4\MSBuild\sounder.exe`, 21 504 bytes.
- SHA-256: `6749f81e19c9646e24f3b271e8cdc0ae0163a169c9981a95d45cf10cfc323c63`.
- Ensamblado VB.NET/WinForms, CLR v2.0.50727, IL AnyCPU, versión 1.0.0.0.
- MVID: `5feef4a5-a3a5-48a9-8780-f7024b748585`.
- La ayuda integrada identifica la versión como August 3, 2012 y acredita a Eli Fulkerson. El usuario aclara que 2017 es la fecha del último instalador encontrado.

## Evidencia estática

REA inspeccionó metadatos y miembros sin ejecutar el original:

- Identidad: `ev_0d541917ded0d7054e0955e2b4ca03d7427cf429c02eb91ecb3a3950117bc78d`.
- Miembros de sounder.Form1: `ev_50409031c2e661e7437ba7a13608234ed756c864d9e7988591db22adbeb15a56`.
- Reconstrucción adicional con ILSpy CLI 11.1.0.9782, tipo `sounder.Form1`, contrastada con las cadenas y llamadas IL. Su salida es reconstrucción, no el código fuente original.

`Form1_Load` contiene todos los alias conservados. Activa temporizadores de comprobación, interpreta `/loop` y `/timer`, crea `stopfile` para `/stop`, y para `/async` agrega SND_ASYNC. `PlayWav` hace llamadas síncronas repetidas a sndPlaySoundA; `-1` significa bucle indefinido. El modo asíncrono omite ese trabajador y por ello ignora `/loop`. Tanto `/async` como `/timer` activan el temporizador de terminación; su valor predeterminado es 2000 ms. La limpieza inicial de stopfile tiene intervalo de 150 ms; la comprobación de parada usa el intervalo WinForms predeterminado de 100 ms. El proceso original termina mediante Process.Kill.

## Decisiones de implementación

Se creó una aplicación de consola sin WinForms en C#/.NET 10 con System.CommandLine y MCI waveaudio (winmm.dll). Conserva las opciones y el comportamiento válido descrito, además de ampliar el uso a rutas Unicode. Sustituye terminación forzada por cancelación y cierre explícito del dispositivo. Una prueba inicial con PlaySound síncrono mostró que la parada esperaba hasta finalizar el WAV; por eso la implementación final consulta el estado MCI y puede detener el dispositivo desde su trabajador propietario. La ayuda y versión van a la consola en vez de una ventana. Se rechazan argumentos numéricos inválidos en vez de usar silenciosamente 2000/-1; se rechazan opciones desconocidas y múltiples archivos en lugar de tomar el último token como ruta. Los errores de reproducción generan código 1. No se pretende conservar fallos accidentales del parser original.

El original no fue ejecutado; la correspondencia procede de inspección estática. Las verificaciones de la implementación se automatizan en `src/tests/Smoke.ps1`. La audibilidad física y la ejecución nativa ARM64 requieren verificación en el hardware correspondiente.

## Verificación de la versión 2.0.0

- SDK utilizado: .NET 10.0.402; compilación Release sin advertencias ni errores.
- Restauración con `--locked-mode` verificada.
- Smoke.ps1 completado tanto con el ejecutable de compilación como con el EXE x64 autocontenido publicado. Cubre todos los alias, ayuda/versión, valores inválidos, ruta Unicode con espacios, duración de una y dos reproducciones, bucle infinito, temporizador, duración asíncrona predeterminada, `/stop` desde otro proceso y limpieza de una señal anterior. Usa audio PCM silencioso; no demuestra audibilidad física.
- Publicaciones x64 y ARM64: cada carpeta contiene únicamente `sounder.exe`. Cabeceras PE verificadas: AMD64 `0x8664` y ARM64 `0xAA64` respectivamente.
- Publicación sin RID rechazada con un mensaje que solicita `win-x64` o `win-arm64`. Ejecución ARM64 pendiente de hardware compatible.
