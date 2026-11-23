# Decisiones del proyecto Alfred

Registro de lo que se decide y por qué. Lo más reciente, arriba. Las decisiones de base están en `CLAUDE.md` (sección 3).

## 2026-11-24 — Fase 1: diseño del autoaprendizaje (solo diseño, sin código)

**Hermes y OpenJarvis: no se usan como base.** Con lo leído (documentación pública; el código y los instaladores no se pudieron leer), ninguno documenta niveles 1/2/3 por código, tope de coste, auditoría de solo añadir ni lector en cuarentena. El primer bucle de agente se escribe a mano. Del repositorio de Hermes solo se copian patrones, nunca código: lista de usuarios permitidos con "denegar por defecto", lista de bloqueo fija, modos desatendidos que deniegan lo peligroso y quitar del entorno de las herramientas las variables con KEY, TOKEN o SECRET. Estado: provisional hasta leer los repos (ver `docs/spike-openjarvis.md`).

**Autoaprendizaje: categoría propia "aprendizaje", con aprobación automática, reversible y auditada.**
No es una excepción al nivel 3: el nivel 3 sigue exigiendo la aprobación de Antonio sin excepciones. Esta categoría solo puede escribir texto en la memoria o en las skills y nunca toca permisos ni herramientas.
- Una skill es solo texto (markdown): sin scripts ni comandos. Una skill mala puede dar un mal consejo, no actuar.
- **Auto-aprobado solo lo que viene de Antonio** (sus mensajes, correcciones y feedback directo).
- **Lo derivado de contenido externo** (correos, webs, documentos) **queda pendiente de su visto bueno.** Motivo: evitar que un correo o web maliciosa haga que Alfred "aprenda" una instrucción persistente (inyección de prompts a largo plazo).
- **Temas vetados** (nunca se aprenden solos): dinero, credenciales, permisos, contactos de confianza, reglas del tipo "siempre aprueba/envía X".
- Límites: máximo de lecciones por día y tamaño máximo de memoria; el coste cuenta dentro del tope de gasto.
- Los recuerdos son datos personales: solo en la partición cifrada, no se envían a modelos baratos con los que no se comparten datos personales, y se pueden exportar y borrar.

**Visibilidad y reversión (Telegram):** `/aprendizajes` (lista: id, fecha, resumen, origen, activa), `/aprendizaje <id>` (texto completo, versión anterior, origen), `/revertir <id>`, `/revertir hoy`, resumen semanal (nuevo, más usado, dudoso) e interruptor para pausar el autoaprendizaje. Todo cambio va a la auditoría de solo añadir; revertir no borra el rastro. Los nombres de comandos son provisionales.

**Skills importadas de repos ajenos:** solo texto; se lee entera antes de aceptarla; se revisa (inyección de instrucciones, URLs, comandos, peticiones de claves); se fija por hash de commit con copia local; se asigna a un perfil concreto, no a todos; si hace falta, se reescribe con palabras propias.

**Consolidación semanal (para que no haya "aprendizaje sobre aprendizaje" sin estructura).**
Una pasada que fusiona duplicados, resuelve contradicciones (gana lo más reciente), agrupa por tema y perfil, archiva lo que lleva meses sin usarse (sin borrar) y deja un informe.
- Antes de empezar guarda una copia completa; `/revertir consolidación` vuelve atrás.
- Solo reorganiza y resume: no añade lecciones nuevas ni toca permisos; mantiene el origen de cada una y respeta pendientes y temas vetados.
- Lo que fusione sin perder información se aplica solo; descartar algo o resolver una contradicción dudosa se propone en el informe semanal.
- **Se ejecuta en local, con el mismo modelo barato por API que usa Alfred.** Motivo: una tarea programada de la cuenta Pro corre en la nube sin acceso al M80q, obligaría a sacar la memoria del servidor (choca con "cero puertos" y con los datos personales), y usar la suscripción para automatizaciones de Alfred es una zona gris **sin comprobar**. Opción futura anotada: tarea programada en la cuenta Pro con una copia sin datos sensibles, cuando se sepa cuánto crece la memoria y estén comprobadas las condiciones.

**Formato de las skills: subconjunto del estándar abierto Agent Skills (agentskills.io), solo markdown.**
Leído en su especificación (Apache 2.0 el código, CC-BY-4.0 la documentación; originado en Anthropic): una skill es una carpeta con un `SKILL.md` (frontmatter YAML + markdown); solo `name` (1-64 caracteres, minúsculas, números y guiones, igual que la carpeta) y `description` (1-1024) son obligatorios; `scripts/`, `references/` y `assets/` son opcionales; se cargan por niveles (nombre y descripción al inicio, el cuerpo al activarse). La especificación no tiene sección de seguridad ni modelo de confianza.
- Alfred acepta **solo `SKILL.md`**: sin `scripts/` ni `assets/`, y rechaza cualquier skill que los traiga.
- El campo `allowed-tools` (herramientas "pre-aprobadas", experimental en el estándar) **se rechaza o se ignora**: los permisos los deciden los niveles en código, nunca una skill.
- Campos permitidos: `name`, `description` y `metadata` (para origen, fecha, versión e id de la lección). Tamaño máximo propio y más estricto que el estándar (a fijar al diseñar el núcleo; Hermes y GEPA usan 15 KB como referencia).
- El validador de Alfred lo escribimos nosotros (formato, tamaño, sin URLs ni comandos, patrones de inyección). El validador oficial `skills-ref` queda como referencia, no como dependencia, hasta revisarlo.
- Ventaja: las skills quedan compatibles con el estándar sin heredar la parte de ejecución.

**Herramientas nuevas creadas por el autoaprendizaje, y `references/` de texto.** (Refina la regla anterior de que los scripts nunca entran por el autoaprendizaje.)
- Las skills admiten una carpeta `references/` con **solo texto o markdown**; siguen prohibidos `scripts/`, `assets/` y binarios.
- Alfred puede **redactar el borrador** de una herramienta con código, pero **no activarla**: queda en cuarentena, y activarla es nivel 3 (Antonio lee el código y aprueba una vez). El nivel lo asigna el código a partir de lo que la herramienta declara necesitar, siempre el más alto, y el sandbox hace cumplir lo declarado. Se fija por hash; cualquier cambio vuelve a pedir aprobación.
- Solo puede nacer de peticiones o patrones de Antonio, nunca de contenido externo, con máximo de borradores por semana, pruebas en contenedor sin red ni secretos y revisión de patrones peligrosos.
- **Excepción, «nivel 0: cálculo puro»:** se activa sola (sin red, sin archivos, sin secretos, sin efectos fuera de devolver un resultado; contenedor con límite de tiempo y memoria; tests y revisión superados; comprobado por el sandbox, no por la declaración del script). Auditada, fijada por hash y revertible. Decisión de Antonio el 2026-11-24.
- **`CLAUDE.md` y `prompt.md` modificados** para reflejarlo: alcance (sección 1), niveles (5.1), nueva sección 5.7, cadena de suministro (5.6), OpenJarvis/Hermes y pago (sección 3), Fase 1 (sección 8 y `prompt.md`). Estas son las **únicas** excepciones a «instalar o activar un skill/herramienta es nivel 3».

**Pago del modelo: clave de API de Claude Console (pago por uso).** Decidido el 2026-11-24; sustituye a la opción de suscripción/tareas programadas, que queda solo como idea futura sin comprobar.
- La clave va en el almacén de secretos del servidor (partición cifrada), nunca en el repo, en la línea de comandos ni en prompts.
- Clave exclusiva para Alfred, separada de la de Clipmation y de cualquier otro uso, para poder revocarla sin afectar al resto.
- Dos topes de gasto superpuestos: el del código de Alfred (que corta) y uno mensual en Claude Console para esa clave o espacio de trabajo, si la consola lo permite (**por comprobar en la consola**). El del código es el que manda; el de la consola es la red de seguridad.
- Pendiente: elegir el modelo por defecto y el importe mensual del tope al diseñar el núcleo, con precios actuales comprobados.

## 2026-11-23 — Fase 0 ejecutada en el M80q

**El M80q va, de momento, por wifi con una antena USB Realtek, no por cable.**
La guía recomienda cable para un servidor 24 h. Se usa wifi mientras no hay cable disponible. Hizo falta `firmware-realtek` y NetworkManager (`eno1` queda "sin gestión"). La IP wifi tiene reserva DHCP en el router. Riesgo conocido: el wifi es menos estable que el cable y el DNS tuvo que arreglarse reiniciando NetworkManager. Se vuelve a cable en cuanto se pueda; no hay que cambiar nada en los scripts, que no dependen del nombre de la interfaz.

**Resultado de la ejecución.** Pasos 0, 10, 20, 30, 40, 50 y 70 y `verify.sh`: OK, con dos avisos esperados (copias: falta el disco USB; consumo: falta el Shelly). Desbloqueo por TPM comprobado tras reiniciar. Pendientes: paso 60 y la parte de consumo del 70.

**Corrección en `50-docker-rootless.sh`.** `install -d` creaba `~/.config` a nombre de root y Docker rootless no podía crear `~/.config/systemd`. Ahora se crea `~/.config` a nombre de alfred antes. Se comprobó a mano (`chown` y repetir el script) y el script corregido no se ha vuelto a ejecutar entero.

**Clipmation comparte el M80q con límites** (detalle en `docs/conflict-alfred-clipmation.md`).
Usuario `clips` con su propio Docker rootless (`55-clips-user.sh`), sin sudo ni SSH y con datos en `/srv/alfred/clips` (0700, cifrado). Los límites (8 hilos = `CPUQuota=800%`, `CPUWeight=20`, `MemoryMax=8G`, `TasksMax=4096`) se ponen en el `user-UID.slice` de systemd, no en Docker: así valen para todo lo que corra ese usuario aunque los límites de cgroup de Docker rootless no estén delegados. Es una estimación sin probar en el M80q. `alfred-disk-check` avisa por Telegram al 80 % y al 90 % de la partición de datos. Pendiente: medir una tanda real (temperatura, CPU, disco) antes de activar el runner, y el aviso de "runner caído" cuando exista el contenedor.

**Vigilante de red `alfred-net-watch` (por el wifi inestable).**
El wifi se cayó varias veces: el registro muestra `4WAY_HANDSHAKE_TIMEOUT` y, tras la última caída, ningún intento más hasta reiniciar (causa del cuelgue sin confirmar). Cada minuto se comprueba si llega al router y se escala: reconectar a los 3 min, reiniciar NetworkManager y recargar el driver a los 6 y reiniciar el equipo a los 15 (máximo una vez cada 6 h, para no entrar en un bucle de reinicios). Los tiempos son una elección, ajustables en `m80q.env`. Sin red no hay aviso por Telegram hasta recuperarse. No sustituye al cable ni a mejorar la señal. Probado con tests en el repo, no en el M80q.

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
