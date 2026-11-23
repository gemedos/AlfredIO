# Conflictos Alfred ↔ Clipmation en el M80q

Revisión del 2026-11-23 del plan para alojar Clipmation en el mismo servidor que Alfred. Resultado: **encaja con el diseño de seguridad de Alfred, con los cambios de abajo**. Todo lo marcado como "sin verificar" es estimación o depende de hardware que no se ha medido.

## Qué es Clipmation en el servidor (según el plan recibido)

- Un **trabajador**, no un servicio que se visite: sin web, sin base de datos, sin API, sin puertos de entrada. La app del móvil habla con GitHub; los datos (issues) y los vídeos (releases) viven en GitHub.
- **Runner de GitHub Actions** en Docker Compose (fase 1, carpeta `runner/`): genera clips cada 2 h (descarga, Whisper, ffmpeg, control de calidad), busca campañas una vez al día y atiende tareas a mano.
- **Grabador de directos** (fase 5): graba 1-2 directos de Twitch/YouTube en trozos, lee chat y clips, detecta picos.
- **Seguidor de fuentes** (fase 4): RSS de YouTube y API de Twitch; ligero.
- Solo sale por HTTPS (443) a GitHub, Anthropic, Composio, ntfy, Hugging Face, YouTube/Drive/Content Rewards y Twitch. Entrada: ninguna. Acceso del dueño: SSH por Tailscale.

## Qué encaja sin tocar nada

- Cero puertos abiertos, SSH solo por Tailscale y cortafuegos que deniega la entrada: Clipmation no necesita nada más.
- Los datos importantes están en GitHub: si el M80q muere no se pierde el negocio. Solo hay datos temporales y algunos secretos (credenciales del runner, claves de las tareas, claves de Twitch).
- Puede estar caído mientras se reinicia o actualiza: los trabajos esperan en cola en GitHub hasta 24 h.
- El repo es **privado**, y debe seguir siéndolo: un runner propio en un repo público podría ejecutar código de un PR de cualquiera.

## Cambios acordados al plan

1. **Usuario y Docker rootless separados.** Hoy Docker rootless corre solo para el usuario `alfred`. El runner debe ir con otro usuario (p. ej. `clips`) y su propio Docker rootless. Motivo: el runner ejecuta código del repo y procesa vídeos de terceros (yt-dlp, ffmpeg), que es lo más expuesto. Hay que generalizar `infra/m80q/50-docker-rootless.sh` para aceptar otro usuario y repetir la condición de "no arrancar si `/srv/alfred` no está montada".
2. **Cable en vez de wifi para la fase 5.** El M80q va ahora por wifi. Un directo son 6-8 Mbps constantes y un corte deja un hueco en la grabación. Para el runner basta el wifi.
3. **CPU: límite de 8 hilos, no 10**, y prioridad baja (`nice`) para el runner. Deja 4 hilos libres para el sistema, Alfred y el grabador, y evita que la transcripción retrase la voz de Alfred (Fase 3, Whisper local).
4. **Temperatura.** 2-5 h diarias de CPU al máximo en un mini PC pueden activar los umbrales de Alfred (aviso a 85 °C; a 95 °C sostenidos el script avisa del apagado). **Hay que medir** con una tanda real y comprobar qué hace el script en modo real antes de dar esto por bueno.
5. **Disco.** El plan pide 256-500 GB y la partición de datos tiene unos **181 GB**, compartidos con Docker y Alfred. Estimación de pico: 100-130 GB con directos y tandas a la vez (sin verificar). Medidas: guardia que se niega a descargar si quedan menos de ~30 GB libres, y aviso por Telegram al 80 % de uso. Empezar solo con el runner (fases 1-4) y dejar los directos (fase 5) hasta medir el uso real o cambiar el SSD por uno de 512 GB.
6. **Reinicio automático a las 04:30** (actualizaciones de Alfred): corta cualquier tanda o directo en curso. Aceptable para el runner (la siguiente tanda lo recupera), pero a tener en cuenta en la fase 5.
7. **Runner acotado.** Sin workflows de forks, imagen del runner con versión fija (como pide Alfred para sus imágenes) y actualización mensual.

## Qué se reutiliza de Alfred

- Tailscale con sus ACL, cortafuegos, actualizaciones automáticas y partición cifrada con TPM (el volumen del runner y los `.env` van ahí).
- `alfred-notify` para avisos por Telegram ("runner caído", "disco casi lleno"), llamado desde un chequeo en el host (el usuario `clips` no puede leer el token del bot).
- Vigilancia de temperatura y, cuando haya Shelly, de consumo.
- Copias con restic (cuando haya disco USB): solo `compose.yml` y `.env`; no hace falta copiar volúmenes, el runner se vuelve a registrar en minutos.
- `verify.sh`, ampliado con las comprobaciones de Clipmation.

## Sin verificar (hacerlo antes de fiarse)

- Pasar `/dev/dri` (Intel UHD 630, VA-API) a un contenedor de Docker rootless: permisos de grupos `video`/`render`.
- Que los límites de CPU y memoria de Docker funcionen en modo rootless en este equipo.
- La RAM real (el plan dice 16 GB) y las cifras de consumo eléctrico y de uso de disco.
- El comportamiento del script de temperatura con carga real sostenida.

## Pasos pendientes

1. Decidir si el runner va como `clips` (recomendado) o con el usuario `alfred`.
2. Generalizar el script 50 para otro usuario.
3. Probar una tanda real de transcripción midiendo temperatura, CPU y disco.
4. Añadir el chequeo de disco y de runner al host y al `verify.sh`.
5. Decidir cuándo pasar a cable y si se amplía el SSD antes de la fase 5.

## Condiciones aplicadas en Clipmation (comunicadas el 2026-11-23)

Resumen de lo que Clipmation ha incorporado a su propio repo (carpeta `runner/` y `runner/README.md`). **No lo he revisado en ese repo**: lo recojo tal como me lo contó Antonio.

| Condición | Cómo se cumple en Clipmation |
| --- | --- |
| Usuario y Docker separados | Usuario `clips` con su propio Docker rootless; nada compartido con `alfred` |
| CPU | Runner con 8 de 12 hilos como máximo y prioridad baja (`nice` 10). Falta comprobar que el límite funciona en rootless |
| RAM | 8 GB como máximo |
| Temperatura | Alfred avisa a 85 °C y a 95 °C sostenidos. Antes de activar el runner se mide una tanda de transcripción completa |
| Disco | ~181 GB compartidos. El runner no descarga si quedan menos de 30 GB; aviso por Telegram al 80 % desde el host |
| Red | El wifi vale para el runner; los directos (fase 5) necesitan cable |
| Reinicio de las 04:30 | Corta lo que esté en curso. Para el runner no importa (la siguiente tanda retoma); para directos sí |
| Runner acotado | Repo privado, sin workflows de forks, imagen y runner con versión fija |
| Avisos y copias | `alfred-notify` desde un chequeo en el host (runner caído, disco), restic para `compose.yml` y `.env`, `verify.sh` ampliado |

### Reparto de trabajo entre repos

- **En el repo de Clipmation** (hecho según Antonio): límites de CPU y RAM, prioridad, guardia de disco, versiones fijas y su README.
- **En este repo (Alfred), pendiente**:
  1. ~~Generalizar el script 50 para otro usuario~~ **Hecho en el repo (sin ejecutar en el M80q)**: `infra/m80q/55-clips-user.sh`, que crea `clips` con su Docker rootless, datos en `/srv/alfred/clips` y los límites en `user-UID.slice`. Se dejó el 50 intacto para no tocar lo ya probado.
  2. ~~Chequeo del disco~~ **Hecho en el repo (sin ejecutar en el M80q)**: `alfred-disk-check` (timer cada 10 min, aviso al 80 % y 90 %), instalado por `70-monitoring.sh`. **Sigue pendiente** el aviso de "runner caído": hace falta saber el nombre del contenedor.
  3. Incluir `compose.yml` y `.env` de Clipmation en las copias de restic.
  4. ~~Ampliar `verify.sh`~~ **Hecho** (sección "Clipmation", sólo si existe el usuario `clips`).
  5. Medir temperatura, CPU y disco con una tanda real **antes** de activar el runner.

### Consecuencia para el plan

Se empieza **solo con el runner (fases 1-4 de Clipmation)**. Los directos (fase 5) esperan a tener cable, a medir el uso real de disco y de temperatura y, probablemente, a un SSD de 512 GB o más.
