# Decisiones del proyecto Alfred

Registro de lo que se decide y por qué. Lo más reciente, arriba. Las decisiones de base están en `CLAUDE.md` (sección 3).

## 2026-11-01 — Fase 0: preparar el M80q

**Sistema: Debian 13 (estable), sin escritorio, instalación limpia sobre Windows 11.**
Mínimo, estable, sin snaps, con actualizaciones de seguridad automáticas maduras. Ubuntu Server LTS habría valido igual.

**Scripts de bash numerados que ejecuta Antonio, no Ansible ni acceso de Claude al servidor.**
CLAUDE.md, Anexo F: Claude Code no entra en el servidor de producción. Bash es más fácil de revisar línea a línea que un playbook y no añade dependencias. Cada script se puede repetir.

**Cifrado sólo de la partición de datos (`/srv/alfred`), con desbloqueo por TPM 2.0 sellado a PCR 7.**
- El sistema (raíz) va sin cifrar y no guarda datos de Alfred; así Tailscale y SSH arrancan siempre, aunque falle el desbloqueo.
- El TPM desbloquea solo al arrancar (sin pantalla ni teclado) mientras no cambie el estado de Secure Boot. PCR 7 sólo: las actualizaciones de kernel no rompen el desbloqueo.
- Si el TPM falla: aviso por Telegram y desbloqueo por SSH con la clave de recuperación (`alfred-unlock-data`).
- `headless=true,nofail` en crypttab: nunca se queda esperando una contraseña en una pantalla que no hay.
- El punto de montaje es inmutable (`chattr +i`) mientras no está montado: si falla el desbloqueo, nada escribe datos en el disco sin cifrar.
- Límite conocido: protege contra el robo del disco, **no del todo contra el robo del equipo entero** (el TPM lo desbloquea en esa máquina). Lo atenúan Secure Boot, la contraseña de BIOS y que sólo arranque desde el SSD.
- Descartado: cifrado completo con contraseña al arrancar (rompe "reinicio y todo vuelve solo") y desbloqueo remoto con dropbear en initramfs (Tailscale no existe en ese momento; sólo valdría por la red local).

**Sin swap en disco; zram.** La swap en disco sin cifrar podría guardar secretos de la memoria.

**Reinicio automático a las 04:30 si una actualización lo pide.** El TPM hace que vuelva solo. La copia diaria va antes, a las 03:30.

**SSH: OpenSSH con clave, sólo para el usuario de Antonio, y UFW sólo permite el 22 por `tailscale0`.** No se usa Tailscale SSH: la autenticación queda en una clave que controla Antonio, no en la cuenta de Tailscale.
- Matiz verificado sólo en la documentación, no en el equipo: Tailscale mete sus propias reglas de iptables y puede aceptar el tráfico de `tailscale0` antes que UFW. Por eso **la ACL de Tailscale es el filtro principal dentro de la tailnet** (sólo puerto 22) y UFW la segunda barrera. `verify.sh` lo detecta y lo informa.
- Tailscale usa el puerto UDP 41641 para conexiones directas; no se abre en el router y no responde a paquetes no autenticados.

**ACL de Tailscale: el M80q no puede iniciar conexiones hacia los dispositivos de Antonio.** Si el servidor se comprometiera, no podría saltar al PC ni al móvil por la tailnet. Etiqueta `tag:alfred`, que además desactiva la caducidad de clave del servidor.

**Bot de Telegram de alertas separado del de Alfred, con el token en `/etc/alfred/secrets.env` (partición del sistema).**
- Las alertas siguen llegando aunque Alfred esté parado con `/stop`.
- El token está fuera de la partición cifrada a propósito: así puede avisar de que esa partición no se ha desbloqueado. Es un secreto de poco valor (sólo envía avisos a Antonio).
- El token y la contraseña del Shelly nunca van en la línea de comandos (se verían en `ps`): se pasan a `curl` por stdin. Hay un test que lo comprueba.

**Docker rootless para el usuario `alfred`; el Docker con root, apagado.**
- Un contenedor comprometido no es root en el equipo, y los puertos publicados no se saltan UFW (el Docker con root sí lo hace).
- Datos de Docker en la partición cifrada. Si no está montada, Docker no arranca.
- Riesgo para la Fase 4: Home Assistant en rootless no ve la red local directamente (mDNS, descubrimiento de WLED). Se resolverá entonces (IPs fijas o una excepción justificada).
- Los paquetes de Docker y Tailscale **no** se fijan a una versión en apt, para recibir correcciones de seguridad; se actualizan a mano cada mes (las de Debian, solas). Las versiones instaladas quedan en `/etc/alfred/versions-docker.txt`. Las **imágenes** de contenedores sí se fijarán a una versión desde la Fase 1.

**Copias: restic al disco USB, montado sólo durante la copia.**
- Restic cifra; el disco no necesita cifrado propio.
- Diaria a las 03:30; se guardan 7 diarias, 4 semanales y 6 mensuales; los domingos se verifica un 5 % de los datos; el día 1 de cada mes, prueba de restauración automática con un archivo "canario".
- La contraseña de restic va en la partición cifrada: quien robe sólo el SSD y el disco de copias no puede leerlas. Antonio guarda una copia fuera del equipo.
- No se copian las imágenes de Docker (se reconstruyen desde el repo).
- Límite: un atacante con root en el M80q podría borrar las copias. Se recomienda una copia sin conexión de vez en cuando.

**Vigilancia: temperatura con coretemp cada minuto; consumo con el Shelly, que corta solo.**
- El corte por consumo lo hace el propio Shelly (límite de potencia interno), porque funciona aunque el M80q esté colgado. El M80q sólo lee y avisa.
- Umbrales (estimaciones, a calibrar con datos reales): aviso a 85 °C, apagado ordenado tras 5 min por encima de 95 °C; aviso de consumo tras 10 min por encima de 65 W; corte del Shelly a ~85 W.

**Pendiente o descartado por ahora**
- Aviso de "el M80q ha dejado de dar señales" con un servicio externo (healthchecks.io): más adelante, si Antonio lo quiere.
- `./check.sh` ejecuta shellcheck y los tests en un contenedor Debian 13 en el PC de desarrollo; `infra/m80q/verify.sh` es la verificación en el servidor.
