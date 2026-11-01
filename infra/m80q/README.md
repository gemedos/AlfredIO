# Fase 0 — Preparar el M80q

Scripts para dejar el Lenovo M80q como servidor seguro de Alfred. **Los ejecutas tú en el M80q**, en orden; Claude Code no entra en el servidor (CLAUDE.md, Anexo F). Lee cada script antes de ejecutarlo: son cortos y están comentados.

| Paso | Script | Qué hace | ¿Destructivo? |
| --- | --- | --- | --- |
| 0 | `00-preflight.sh` | Comprueba Debian 13, UEFI, TPM, Secure Boot, discos, red y tu clave SSH | No (sólo lee) |
| 1 | `10-base.sh` | Actualiza, actualizaciones automáticas, sin suspensión, NTP, logs, zram, `alfred-notify` | No |
| 2 | `20-tailscale.sh` | Instala y conecta Tailscale con la etiqueta `tag:alfred` | No |
| 3 | `30-ssh-firewall.sh` | SSH sólo con clave, UFW denegar por defecto (SSH sólo por Tailscale), fail2ban | Puede dejarte fuera si lo saltas (tiene protecciones) |
| 4 | `40-data-luks.sh /dev/…` | Cifra la partición de datos, desbloqueo por TPM, clave de recuperación | **Sí: borra esa partición** |
| 5 | `50-docker-rootless.sh` | Docker sin root para el usuario `alfred`, datos en la partición cifrada | No |
| 6 | `60-backup.sh` | Copias restic diarias al disco USB + prueba de restauración | No (el formateo del disco lo haces tú) |
| 7 | `70-monitoring.sh` | Vigilancia de temperatura y consumo con avisos por Telegram | No |
| ✓ | `verify.sh` | Comprueba todo en un comando | No (sólo lee) |

Todos se pueden repetir: si un paso falla, corriges y lo vuelves a lanzar.

## Antes de empezar (lo haces tú)

1. **Instala Debian 13** siguiendo [`docs/INSTALAR_DEBIAN.md`](../../docs/INSTALAR_DEBIAN.md).
2. **Tailscale**: crea la cuenta en <https://login.tailscale.com>, instala Tailscale en tu PC y en el móvil, y en *Access controls* pega **entero** [`infra/tailscale/policy.hujson`](../tailscale/policy.hujson) y guarda.
3. **Bot de alertas de Telegram**: en Telegram, habla con **@BotFather** → `/newbot` → nombre p. ej. "Alfred alertas". Guarda el token en tu gestor de contraseñas (no lo pegues en el chat de Claude). Escribe "hola" a tu bot nuevo.

## 1. Tu clave SSH (desde tu PC con Windows, en PowerShell)

```powershell
# Si no tienes clave aún (pon una frase de paso):
ssh-keygen -t ed25519
# Copiarla al M80q (IP de la red local; te pedirá tu contraseña de Debian por última vez):
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh antonio@192.168.1.XX "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
ssh antonio@192.168.1.XX        # debe entrar sin pedir la contraseña de Debian
```

Para el **móvil** (p. ej. Termius): genera allí una clave ed25519 y añade su línea pública a `~/.ssh/authorized_keys` del M80q **antes del paso 3**.

## 2. Pasar los scripts al M80q (desde tu PC, en Git Bash)

```bash
cd /c/claude/alfredIO
git archive --format=tar.gz -o alfred-infra.tar.gz HEAD infra
scp alfred-infra.tar.gz antonio@192.168.1.XX:
ssh antonio@192.168.1.XX "rm -rf alfred && mkdir alfred && tar -xzf alfred-infra.tar.gz -C alfred && rm alfred-infra.tar.gz"
```

Cuando haya cambios en el repo, repite estos tres comandos (después del paso 3, usa la IP de Tailscale).

## 3. Ejecutar los pasos (en el M80q)

```bash
cd ~/alfred/infra/m80q
sudo ./00-preflight.sh
sudo ./10-base.sh
sudo nano /etc/alfred/secrets.env        # pega TELEGRAM_BOT_TOKEN (Ctrl+O, Intro, Ctrl+X)
sudo alfred-notify --discover-chat-id    # muestra tu chat id → ponlo en TELEGRAM_CHAT_ID
sudo nano /etc/alfred/secrets.env
sudo alfred-notify "Prueba de avisos del M80q"   # debe llegarte al móvil
sudo ./20-tailscale.sh                   # abre la URL que muestra y autoriza el equipo
```

**Ahora sal y vuelve a entrar por Tailscale** (`ssh antonio@100.x.y.z`, la IP que muestra el paso 2). Desde esa sesión:

```bash
cd ~/alfred/infra/m80q
sudo ./30-ssh-firewall.sh
# NO cierres la sesión: en OTRA terminal comprueba que entras por Tailscale. Si no, en la primera: sudo ufw disable
sudo ./40-data-luks.sh /dev/nvme0n1p3    # la partición que te indicó 00-preflight.sh
sudo reboot                              # prueba: debe volver solo, con /srv/alfred montada
sudo ./50-docker-rootless.sh
sudo ./60-backup.sh                      # cuando tengas el disco USB (ver abajo)
sudo ./70-monitoring.sh
sudo ./verify.sh
```

En el paso 4 aparece la **clave de recuperación** de la partición de datos: apúntala en papel o en tu gestor de contraseñas (nunca en el chat). El script te la pide para comprobar que está bien apuntada.

## Disco de copias (cuando tengas la caja USB)

> Esto **borra el disco**. Si el disco de 1 TB del PC viejo tiene algo que quieras, cópialo antes.

```bash
lsblk -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINTS   # identifica el disco USB (p. ej. sda) por tamaño y modelo
sudo wipefs -a /dev/sdX                        # sdX = el disco USB. ¡Comprueba dos veces!
sudo parted -s /dev/sdX mklabel gpt mkpart backup ext4 0% 100%
sudo mkfs.ext4 -L alfred-backup /dev/sdX1
sudo blkid /dev/sdX1                           # copia el UUID="..."
sudo nano /etc/alfred/m80q.env                 # BACKUP_DISK_UUID=ese-uuid
sudo ./60-backup.sh
```

El disco no necesita cifrado propio: restic cifra cada copia. Guarda la contraseña del repositorio (`sudo cat /srv/alfred/secrets/restic.pass`) en tu gestor de contraseñas: sin ella las copias no sirven.

## Shelly Plug M Gen3 (cuando lo tengas)

En su web local (`http://IP-del-shelly`), o en la app la primera vez:

1. Actualiza el firmware.
2. **Contraseña** de acceso local (usuario `admin`) → ponla en `SHELLY_PASSWORD` de `/etc/alfred/secrets.env`.
3. **Desactiva la nube** (Cloud) y Bluetooth si no los usas.
4. **Límite de potencia** ("Power limit / overpower protection"): unos **85 W** (estimación: el cargador original es de unos 90 W y el M80q gasta ~45-65 W a plena carga). Ajusta tras una semana de lecturas: `journalctl -t alfred-power --since -7d`.
5. **Estado al volver la luz**: encendido ("ON").
6. Reserva su IP en el router y ponla en `SHELLY_HOST` de `/etc/alfred/m80q.env`. Luego: `sudo ./70-monitoring.sh`.

Si el router tiene red de invitados/IoT aislada, el M80q debe poder llegar al Shelly: compruébalo con `sudo alfred-power-watch --read`.

## Pruebas de aceptación de la Fase 0

| Prueba | Cómo |
| --- | --- |
| Reinicio y todo vuelve solo | `sudo reboot`, espera 2 min, entra por Tailscale y `sudo ./verify.sh` → `RESULTADO: OK` |
| Cero puertos abiertos desde fuera | Desde tu PC por la red local: `Test-NetConnection 192.168.1.XX -Port 22` → debe **fallar**. Por Tailscale: `Test-NetConnection 100.x.y.z -Port 22` → debe **funcionar**. Con nmap (opcional): `nmap -Pn -p- 192.168.1.XX` → todo "filtered". Y en el router: sin redirección de puertos, UPnP apagado |
| Restauración probada | `sudo alfred-restore-test` → "Prueba de restauración OK" y aviso por Telegram |
| Aviso de temperatura simulado | `sudo alfred-temp-watch --simulate 96` → llega "[SIMULACIÓN] Temperatura alta…"; con `--sustained`, el aviso de apagado (sin apagar) |

## Arrancar, parar y estado

```bash
systemctl list-timers 'alfred-*'                 # copias, vigilancia y comprobaciones programadas
sudo systemctl stop alfred-temp-watch.timer      # parar una vigilancia (start para volver)
sudo systemctl start alfred-backup.service       # copia ahora
journalctl -t alfred-notify --since today        # avisos enviados hoy
sudo -iu alfred                                  # entrar como el usuario de Docker
systemctl --user stop docker                     # (como alfred) parar Docker
```

**Actualizaciones**: las de seguridad de Debian se instalan solas. Docker y Tailscale vienen de repositorios externos y **no** se actualizan solos (para no romper nada sin mirar): una vez al mes, `sudo apt update && sudo apt upgrade`.

## Restaurar

- **Un archivo o carpeta**:
  ```bash
  sudo mount /mnt/alfred-backup
  R="sudo restic -r /mnt/alfred-backup/restic --password-file /srv/alfred/secrets/restic.pass"
  $R snapshots
  $R restore latest --target /srv/alfred/restaurado --include /ruta/que/quieres
  sudo umount /mnt/alfred-backup
  ```
- **Desastre (SSD muerto o equipo nuevo)**: instala Debian (guía) y ejecuta los pasos 0-5. Pon en `/srv/alfred/secrets/restic.pass` la contraseña de restic que guardaste fuera, monta el disco USB y restaura `/etc/alfred`, `/srv/alfred/data` y `/srv/alfred/secrets` (no copies encima el `m80q.env` entero: el `DATA_LUKS_UUID` nuevo es otro). Después, pasos 6-7 y `verify.sh`.

## Si algo va mal

- **Te has quedado sin SSH**: teclado y pantalla en el M80q, entra con tu usuario y `sudo ufw disable` o revisa `/etc/ssh/sshd_config.d/10-alfred.conf`.
- **Aviso "la partición de datos NO se ha desbloqueado"** (pasa tras actualizar la BIOS o tocar Secure Boot): entra por SSH y `sudo alfred-unlock-data --reenroll-tpm` (pide la clave de recuperación dos veces).
- **No llegan avisos**: `sudo alfred-notify prueba` y mira el error; `journalctl -t alfred-notify`.

## Qué está probado y qué no

- **Probado en el repo** (`./check.sh`): shellcheck sin avisos en todos los scripts; 23 tests de la lógica de temperatura, consumo, avisos, red de Tailscale y configuración.
- **Sin probar en el M80q** (se prueba al ejecutarlo): instalación de paquetes, desbloqueo por TPM y reinicio, Docker rootless, restic, lectura de `coretemp`, URL del repositorio de Tailscale para Debian 13 (`trixie`).
- **Depende de hardware que no tienes aún**: copias (caja USB para el disco de 1 TB) y vigilancia de consumo (Shelly).
- **Estimaciones**: umbrales de temperatura (85/95 °C) y de consumo (65 W aviso, ~85 W corte).
