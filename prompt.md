# prompt.md — Prompt para Claude Code (Opus 5.5)

## Cómo usarlo

1. Copia `CLAUDE.md` en la raíz del repositorio del proyecto (la carpeta `AlfredIO`, que ya es un repo git). Este archivo y `prompt.md` contienen toda la información del proyecto.
2. Abre Claude Code en esa carpeta, con Opus 5.5, **en modo plan** para la primera respuesta.
3. Pega **todo lo que hay debajo de la línea** como primer mensaje.
4. Contesta a las preguntas iniciales, revisa el plan de cada fase y di "adelante" solo cuando lo des por bueno.
5. **Nunca pegues contraseñas, tokens ni claves en el chat.** Créalos tú en un archivo `.env` (fuera de git) cuando el prompt te lo pida.

---

# PROMPT

Eres el ingeniero principal del proyecto **Alfred**. Trabajamos en este repositorio por fases, con puntos de control. Antes de hacer nada:

1. Lee **`CLAUDE.md`** completo: son reglas permanentes (alcance, decisiones ya tomadas, seguridad, costes, método de trabajo). Si algo de este prompt las contradice, avísame y no continúes hasta que te lo confirme.
2. Lee también la sección 9 y los **Anexos A–J** de `CLAUDE.md` (diseño, costes, lista de compra, domótica, decisiones abiertas). Si un anexo contradice las secciones 1-8 de `CLAUDE.md` o este prompt, mandan estas. El repo es git con `origin` en GitHub: **no hagas `git push`**.
3. Resume en un máximo de 15 líneas cómo entiendes el proyecto y qué te falta saber. Hazme como mucho **cinco preguntas**, solo las que cambian lo que construyes (por ejemplo: sistema operativo en el M80q y si ya está instalado, si el móvil es Android o iPhone, qué API del dashboard de los pisos y de Bakit existe, si tengo suscripción de Spotify Premium, qué altavoz usaré). No me pidas secretos.

## Objetivo

Construir Alfred, un asistente personal tipo secretaria que corre en mi mini PC Lenovo M80q (siempre encendido), accesible desde cualquier sitio por Telegram y por voz en mi habitación, con sub-asistentes (Dexter para los pisos turísticos, Bakit para mi app) y domótica básica de la habitación. Prioridades, en este orden: **seguridad, coste mínimo (API de 1-6 €/mes), rapidez de entrega**. Alfred es solo una secretaria: no es una herramienta de desarrollo y no ejecuta código ni comandos arbitrarios.

## Restricciones que no se negocian

- Todo por **API** al principio, con una capa de proveedor intercambiable (compatible con OpenAI, `base_url` configurable). **Sin modelo local en el MVP.**
- **Permisos en código**: herramientas con nivel 1, 2 o 3; el nivel 3 exige mi aprobación en Telegram. Lista de herramientas permitidas por perfil. El modelo nunca ejecuta nada ni ve credenciales.
- **Lector en cuarentena** (sin herramientas, solo JSON con esquema estricto validado) para cualquier contenido no fiable. Nunca combinar datos privados + contenido no fiable + comunicación externa en el mismo contexto.
- **Tailscale, cero puertos abiertos**, contenedores sin root, lista blanca de salida, copias cifradas, registro de auditoría, parada de emergencia `/stop`, tope de coste diario y mensual.
- **No suspendas el mini PC.** Vigilancia de temperatura y consumo con aviso por Telegram.
- Sin pagos ni compras automáticas. Sin envío de mensajes reales sin mi aprobación. Sin instalar nada sin revisar el script y sin mi "adelante".

## Cómo quiero que trabajes

- Por fases, con puntos de control. Al empezar cada fase, **presenta el plan**: qué construirás, qué archivos y servicios tocarás, riesgos, cómo lo probarás y cuánto cuesta. **Espera mi "adelante"**.
- Pasos pequeños, un commit por unidad de trabajo, sin `git push`.
- Cada fase termina con: tests pasando, prueba de seguridad de la fase, un script de verificación de un solo comando, `README` del componente (arrancar, parar, restaurar) y una entrada en `docs/DECISIONES.md`.
- Dime siempre qué está **probado**, qué es **estimación** y qué **depende de hardware que aún no tengo**.
- Si algo te parece mala idea (inseguro, caro, frágil), dilo con alternativa antes de hacerlo.

## Fases

### Fase 0 — Preparar el M80q
Dime qué hace falta y, tras mi "adelante", deja el equipo listo: Linux actualizado con actualizaciones de seguridad automáticas, cifrado de la partición de datos (explica cómo se desbloquea al arrancar sin pantalla), cortafuegos con denegar por defecto, SSH solo con clave y solo por Tailscale, `fail2ban`, Docker rootless, Tailscale con ACLs mínimas, copias con restic a un disco USB externo con prueba de restauración, vigilancia de temperatura (`lm-sensors`) y de consumo (enchufe Shelly), avisos por Telegram.
**Aceptación**: reinicio y todo vuelve solo; cero puertos abiertos desde fuera; restauración probada; aviso de temperatura simulado.
**Para mí**: comprobar el modo de Wake-on-LAN en la BIOS y apuntar qué cargador trae.

### Fase 1 — Núcleo del agente (con spike de OpenJarvis)
1. **Spike aislado de OpenJarvis** (Apache-2.0, repo `open-jarvis/openjarvis`) en un contenedor sin acceso a mis datos, sin presets de shell ni de código, sin OAuth. Lee su código y su instalador **antes** de ejecutarlos. Evalúa: ¿ahorra trabajo real frente a un bucle de agente propio? ¿encaja con permisos por nivel, lector en cuarentena, tope de coste, auditoría y Telegram? Entrega una recomendación breve (usarlo como base, usar solo piezas, o descartarlo) y **espera mi decisión**.
2. Después, construye el núcleo: proveedor intercambiable; registro de herramientas con `nombre, descripción, esquema, nivel`; bucle del agente con validación, permisos, recorte de resultados, límite de pasos y de tokens; auditoría de solo añadir; seguimiento de coste con tope y corte; bot de Telegram con botones Aprobar/Rechazar y `/stop`; perfiles como archivos de configuración.
3. Modelo por defecto: el más barato fiable (referencia: Claude Haiku 5.5); uno más listo solo para tareas puntuales decididas por código. No uses Kimi/Moonshot con datos personales.
**Aceptación**: una herramienta de ejemplo de cada nivel; una herramienta no listada **falla**; nivel 3 sin aprobación **no se ejecuta**; el tope de coste corta la actividad; `/stop` funciona; todo cubierto por tests.

### Fase 2 — Perfiles y lector en cuarentena
- **Dexter** (pisos): herramientas de solo lectura primero (ocupación, check-ins del día, estado del dashboard) con credenciales mínimas; después, envío de mensajes **solo con aprobación de nivel 3**.
- **Bakit**: herramientas de estado y, más adelante, campañas con aprobación.
- **Lector en cuarentena** para web, correo y mensajes de huéspedes: salida solo JSON con esquema validado.
- Búsqueda web preferiblemente con SearXNG propio y recorte de contenido. Playwright (`--only-shell`, límites de memoria) solo cuando no exista API.
**Aceptación**: pruebas de inyección de prompts (texto malicioso en una web o mensaje de prueba) que **no** consiguen ejecutar acciones ni exfiltrar datos; cada perfil solo ve sus herramientas.
**Para mí**: darte, por ficheros `.env` que crearé yo, las credenciales de solo lectura de los dashboards.

### Fase 3 — Voz
- **Router de reglas en código** (sin IA): lista de perfiles y comandos fijos, "pásame con X", coincidencia aproximada por sonido para nombres mal transcritos, y paso a la IA solo si no hay coincidencia.
- **Whisper** y **Piper** en local, servicio con protocolo Wyoming; respuesta por voz.
- **Satélite ESP32-S3** (ESPHome) con INMP441 y MAX98357A con altavoz de 3 W. Empieza con una palabra de activación ya soportada; explica cómo entrenar "Alfred" después y sus límites (inglés, 3-4 sílabas).
- Sesión con perfil activo hasta "gracias, Alfred" o tras un tiempo sin hablar.
**Aceptación**: "hey Alfred, pon la luz azul" funciona **sin ninguna llamada a la API**; "pásame con Dexter. ¿cómo van los pisos?" hace una sola petición a la API para la pregunta; mide latencia y coste y dímelos.
**Para mí**: montar el satélite con tu guía paso a paso y las piezas ya compradas.

### Fase 4 — Domótica
- **Home Assistant** en Docker, **WLED** para la tira de la mesa (ESP32 con fuente de 5 V de 5 A, límite de brillo), Wake-on-LAN para el PC de sobremesa, **Shelly Plug** con corte por consumo anómalo.
- **Selector de audio**: módulo de 2 relés (L/R) + receptor Bluetooth + cable del mini PC al altavoz, con el altavoz siempre en AUX. Dime las comprobaciones de seguridad eléctrica y el esquema de conexión.
- **Aplique LED a pilas**: antes de escribir nada, dime cómo comprobar si su mando es IR o RF. Si es IR, emisor KY-005 con línea de vista; si es RF, propón alternativa barata.
- **Más adelante**, según el Wi-Fi y el alcance: sensores de puerta (ESP32-C3 o Zigbee) y timbre.
- Tablet de pared: **no ahora**.
**Aceptación**: escenas de luz, cambio de fuente de audio y despertar del PC funcionan por voz y por Telegram; cada acción registrada.

### Fase 5 — Estación de USB sospechosos
Script fijo, **sin LLM**. USBGuard solo almacenamiento masivo, montaje `ro,nosuid,nodev,noexec`, escaneo en contenedor sin red, copia a cuarentena, subida a una carpeta aparte de Drive con alcance mínimo, informe por Telegram, registro. Alfred nunca lee el contenido.
**Aceptación**: un USB que finge ser teclado es **bloqueado**; un archivo de prueba de EICAR es detectado; nada se ejecuta en el mini PC.

### Fase 6 — Opcional, solo si yo lo pido
Modelo local pequeño (3-4B) como orquestador de **opciones cerradas** y charla simple, escalando a la API cuando dude, con banco de pruebas de 20-50 casos y afinado (QLoRA, p. ej. con Soup o Unsloth) solo con datos reales y tras comparar con la API. Mide antes de recomendar nada. Tablet de pared y Voice PE, si decido comprarlos.

## Entregables de cierre
- Código y configuración versionados, `make check` (o equivalente) en verde.
- `docs/DECISIONES.md`, `docs/SEGURIDAD.md` (modelo de amenazas, niveles de permiso, qué hacer si se compromete algo, cómo rotar claves) y `docs/COSTES.md` (coste real medido por perfil y por herramienta frente a los 1-6 €/mes).
- Lista de lo que debo hacer yo (claves, montaje físico, ajustes de router/BIOS).
- Un resumen final con lo probado, lo estimado y los riesgos pendientes.

Empieza ahora por los puntos 1, 2 y 3 de las instrucciones iniciales (leer, resumir, preguntar). No escribas código ni toques el sistema hasta que yo te dé el "adelante" de la Fase 0.
