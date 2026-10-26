# Instrucciones para agentes

- El producto es Sounder 2.0.0: reproductor WAV de consola, C#, .NET 10, exclusivamente Windows x64 y ARM64. No añadir soporte para otros sistemas ni ARM32/x86.
- La solución es `src/sounder.slnx`; el proyecto principal es `src/sounder/sounder.csproj`.
- Preservar todos los parámetros y alias documentados en README, incluido `/async`, `/loop -1`, `/stop` sin archivo y la comunicación mediante `stopfile` en el directorio de trabajo.
- Conservar el crédito a Eli Fulkerson, creador del original en 2012; 2017 corresponde al último instalador encontrado, no al año de creación confirmado.
- Mantener System.CommandLine como analizador. No sustituirlo por un parser manual. Actualizar `packages.lock.json` si cambian dependencias.
- Mantener el límite predeterminado de 2000 ms para `/async`, su precedencia sobre `/loop`, la limpieza inicial de `stopfile` tras 150 ms y la comprobación posterior cada 100 ms. Documentar cualquier cambio deliberado de compatibilidad.
- La interoperabilidad está en NativeAudio.cs: MCI waveaudio con comandos Unicode y códigos de error MCI. Ejecutar apertura, reproducción, estado y cierre en el mismo trabajador; mantener compatibilidad ARM64.
- Detener el audio y esperar al trabajador al terminar; evitar tareas o procesos huérfanos. Verificar temporizador, cancelación y señal externa al modificar la concurrencia.
- Compilar: `dotnet build src/sounder.slnx -c Release`. Validar: `pwsh -NoProfile -File src/tests/Smoke.ps1`. Las pruebas de reproducción necesitan un dispositivo de audio Windows y usan WAV silenciosos.
- Publicar mediante `src/Publish.ps1` o `dotnet publish` con un RID explícito. Mantener un único EXE autocontenido en `publish/<Version>/<RuntimeIdentifier>/`. Probar el EXE x64 en este host; no afirmar ejecución nativa ARM64 sin un host ARM64.
- No versionar `publish/`, `bin/`, `obj/`, herramientas locales, archivos del IDE ni artefactos temporales. Revisar `git status` y `git diff --check` antes de terminar.
- Mantener README orientado al uso y desarrollo del producto. Las notas de análisis del ejecutable pertenecen a `docs/RECONSTRUCTION.md`, no al README.
- Al cambiar la versión, actualizar Version, AssemblyVersion, FileVersion y el texto de presentación. No asignar una licencia al código original sin evidencia de su licencia.
