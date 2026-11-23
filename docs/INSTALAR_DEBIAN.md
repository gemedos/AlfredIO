# Instalar Debian 13 en el Lenovo M80q

Guía para dejar el M80q listo para los scripts de la Fase 0 (`infra/m80q/`). Tiempo estimado: 1-1,5 h.

> **Esto borra Windows 11 y todo lo que haya en el SSD.** Copia antes lo que quieras conservar. La licencia de Windows va grabada en la placa: si algún día quieres volver a Windows, se reactiva sola.

## Qué necesitas

- Un pendrive de 1 GB o más (se borrará).
- Cable de red del M80q al router (recomendado: más estable que el Wi-Fi para un servidor 24 h).
- Teclado y pantalla conectados al M80q durante la instalación.
- Tu PC con Windows en la misma red.

## 1. Antes de borrar Windows: actualiza la BIOS

Hazlo **ahora**, desde Windows, con Lenovo Vantage o descargando la BIOS de la página de soporte de Lenovo (busca por el número de serie de la etiqueta). Motivo: el disco de datos se desbloqueará con el chip TPM, y una actualización de BIOS posterior puede obligarte a desbloquearlo a mano una vez. Mejor actualizar antes.

## 2. Descargar Debian y preparar el pendrive (en tu PC)

1. Ve a <https://www.debian.org/distrib/netinst> y descarga la imagen **amd64 netinst** de Debian 13 (`debian-13.x.y-amd64-netinst.iso`).
2. Descarga también el archivo `SHA256SUMS` de la misma carpeta y comprueba la imagen en PowerShell:
   ```powershell
   Get-FileHash .\debian-13.*-amd64-netinst.iso -Algorithm SHA256
   ```
   El valor debe coincidir con la línea de ese archivo en `SHA256SUMS`. Si no coincide, no la uses.
3. Graba la imagen en el pendrive con **Rufus** (si pregunta "modo ISO o DD", elige **DD**) o con **balenaEtcher**.

## 3. Ajustes de BIOS del M80q

Enciende y pulsa **F1** repetidamente para entrar en la BIOS (F12 abre el menú de arranque). Los nombres exactos pueden variar según la versión:

| Dónde (aprox.) | Ajuste | Valor | Por qué |
| --- | --- | --- | --- |
| Security → Security Chip | TPM 2.0 | **Enabled** | Desbloqueo automático del disco de datos |
| Security → Secure Boot | Secure Boot | **Enabled** | El TPM sólo libera la clave si el arranque no se ha alterado. Debian arranca con Secure Boot sin hacer nada más. Si existe la opción "Allow Microsoft 3rd Party UEFI CA", ponla en **Enabled** (si no, Debian no arrancará) |
| Power → After Power Loss | Al volver la luz | **Power On** | Tras un corte de luz el servidor arranca solo |
| Power → Wake on LAN | Wake on LAN | **apunta el valor** que tiene | Lo pide la Fase 0 (Anexo H) |
| Power → Intelligent Cooling / modo | Rendimiento | Equilibrado ("Balanced") | Menos ruido y temperatura |
| Startup → Boot priority | Orden | Pendrive primero **sólo para instalar** | Después lo cambias (paso 6) |

Guarda con **F10**. Si al instalar Debian no arranca desde el pendrive con Secure Boot, revisa la opción de la "3rd Party UEFI CA" antes de desactivar nada.

**Apunta también** (te lo pedirá la Fase 0): modelo y vatios del cargador (etiqueta del transformador; debería ser el original de unos 90 W), versión de BIOS, tamaño del SSD y RAM.

## 4. Instalación de Debian

Arranca desde el pendrive y elige **Install** (o "Graphical install", da igual).

1. **Idioma**: Español. **Ubicación**: España. **Teclado**: Español.
2. **Red**: si pregunta qué interfaz, elige la de cable (`eno1`, `enp...`).
3. **Nombre de la máquina**: `alfred-m80q`. **Dominio**: vacío.
4. **Contraseña de root**: **déjala vacía** (dos veces). Así root queda deshabilitado y tu usuario podrá usar `sudo`.
5. **Usuario**: tu nombre y un nombre de usuario corto (por ejemplo `antonio`). **Contraseña larga** y que no uses en otro sitio: sólo servirá para `sudo` y la consola física (SSH irá sólo con clave).
6. **Zona horaria**: Madrid (península).
7. **Particionado**: elige **Manual**.
   1. Selecciona el disco (SSD, `nvme0n1`) y acepta **crear una tabla de particiones nueva vacía** (GPT). Esto borra Windows.
   2. Sobre el espacio libre, crea estas particiones, en este orden:

      | # | Tamaño | Utilizar como | Punto de montaje |
      | --- | --- | --- | --- |
      | 1 | 1 GB | Partición de sistema EFI | — |
      | 2 | 60 GB | Sistema de ficheros ext4 | `/` |
      | 3 | **todo lo que queda** | **no utilizar la partición** | — |

   3. **No crees swap** (el script usará swap comprimida en RAM). El instalador avisará de que no hay swap: contesta **No** a "volver al menú de particionado" y continúa.
   4. **No cifres nada en el instalador.** La partición 3 la cifrará `40-data-luks.sh` con desbloqueo por TPM; si la cifras aquí, el servidor pediría contraseña en cada arranque.
   5. Termina y confirma escribir los cambios.
8. **Réplica de paquetes**: España, `deb.debian.org`. Proxy: vacío.
9. **Encuesta de popularidad**: No.
10. **Selección de programas**: **desmarca** "Entorno de escritorio Debian" y cualquier escritorio (GNOME, etc.). **Marca sólo** "Servidor SSH" y "Utilidades estándar del sistema".
11. Al terminar, quita el pendrive y reinicia.

## 5. Primer arranque

En la consola del M80q, entra con tu usuario y anota la IP:

```bash
ip -4 addr show | grep inet
sudo apt update          # comprueba que sudo e internet funcionan
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
```

En `lsblk` la partición 3 (`nvme0n1p3`) debe aparecer **sin FSTYPE**: es la de datos.

En el **router**: reserva esa IP para el M80q (reserva DHCP) y comprueba que **no hay redirección de puertos** hacia él y que **UPnP está desactivado**.

## 6. Cierra la BIOS

Vuelve a la BIOS (F1): pon el **SSD primero** en el orden de arranque (o quita el USB), y pon una **contraseña de supervisor** (apúntala en tu gestor de contraseñas). Así nadie puede arrancar otro sistema o desactivar Secure Boot sin ella.

## 7. Siguiente paso

Sigue con [`infra/m80q/README.md`](../infra/m80q/README.md): copiar tu clave SSH, pasar los scripts al M80q y ejecutarlos en orden.

## Si algo falla

- **No arranca el pendrive con Secure Boot**: activa "Allow Microsoft 3rd Party UEFI CA"; si no existe, desactiva Secure Boot sólo para instalar y vuelve a activarlo después (Debian arranca igual).
- **El TPM da error en `00-preflight.sh`**: en la BIOS, Security → Security Chip → "Clear Security Chip" (borra el estado que dejó Windows; no afecta a Debian) y vuelve a probar.
- **Sin red tras instalar**: `sudo systemctl status networking` y revisa `/etc/network/interfaces`.
