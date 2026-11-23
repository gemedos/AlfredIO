# Spike de OpenJarvis y Hermes Agent (Fase 1) — BORRADOR PARCIAL

Fecha: 2026-11-23. Estado: **parte A incompleta**. Se leyó documentación pública oficial; **no se ha leído código ni instaladores** y varias páginas clave (repositorios de GitHub, página de seguridad de OpenJarvis, `install.sh`) no se pudieron abrir. Nada se ha instalado ni ejecutado. Lo que no está verificado se marca como **[sin verificar]**; lo que viene de un resumen automático de la página y no del texto literal, como **[resumen]**.

## Fuentes leídas

- OpenJarvis: [README oficial](https://raw.githubusercontent.com/open-jarvis/OpenJarvis/main/README.md), [web de documentación](https://open-jarvis.github.io/OpenJarvis/) (mitad en [resumen]), [instalación](https://open-jarvis.github.io/OpenJarvis/getting-started/installation/) (mitad en [resumen]) y el [blog de Stanford](https://scalingintelligence.stanford.edu/blogs/openjarvis).
- Hermes Agent (Nous Research): [web oficial](https://hermes-agent.nousresearch.com/), su documentación (instalación, seguridad, mensajería; parte en [resumen]) y su página de comparación.
- **No leído** (bloqueado por la herramienta de lectura): los repositorios de GitHub de ambos, las páginas de seguridad, agentes, canales y acceso al sistema de OpenJarvis, y los scripts `install.sh`/`install.ps1` de los dos.
- Ojo: existen **forks no oficiales** de OpenJarvis en GitHub con nombres casi idénticos. Usar solo la organización `open-jarvis` (repositorio `OpenJarvis`). Ojo también con mayúsculas: `CLAUDE.md` escribe el repo en minúsculas.
- La documentación de Hermes no compara con OpenJarvis; que sean "competidores directos" es un encuadre nuestro, no una afirmación de sus fuentes.

## Resumen de lo leído

| | OpenJarvis | Hermes Agent |
| --- | --- | --- |
| Licencia | Apache-2.0 | MIT |
| Versión | 0.1.0 en un ejemplo de la documentación [resumen]; fecha no consta | No consta (instala "la última estable") |
| Lenguaje | Python 3.11–3.13, extensión en Rust, frontend Node 22+ | Python 3.14, Node.js; lenguaje del repo [sin verificar] |
| Instalación | `curl … \| bash` (instala uv, Ollama y un modelo local); en desarrollo, además Rust y npm | `curl … \| bash` (instala Python, Node, pnpm, ripgrep, FFmpeg, Chromium y `cua-driver`); puede pedir sudo para `libatomic` |
| Acceso al sistema | Preset `code-assistant` con shell, archivos y código; agente `native_openhands` ejecuta Python. Cómo se desactiva: [sin verificar] | Herramientas de terminal, archivos, ejecución de código, navegador y subagentes. Terminal con backend local (sin aislamiento) o Docker/SSH/Modal/otros. Cuál es el de por defecto: [sin verificar] |
| Permisos / aprobación | **No consta** (página de seguridad no leída) | Modos `smart` (por defecto: un LLM evalúa el riesgo), `manual` y `off`; modo YOLO; espera de 300 s y deniega; lista de bloqueo fija; reglas `deny` por patrones. La propia documentación avisa de que no son un sandbox |
| Telegram | Módulo `telegram` existe; configuración y quién puede hablar: [sin verificar] | Token por variable de entorno; **deniega por defecto a quien no esté en la lista** de usuarios permitidos; `allow all` desaconsejado con acceso a terminal |
| Tope de coste | No consta (registra coste por consulta) | No consta (`/usage` muestra tokens); límite por herramienta MCP [sin verificar] |
| Memoria y skills | Memoria semántica local, formato y lugar [sin verificar] | Memoria en `~/.hermes/`; **el agente crea y mejora skills por su cuenta**; Skills Hub; hooks que se cargan sin consentimiento adicional |
| Tareas programadas | Sí (cron, `scheduled-monitor`); detalle [sin verificar] | Sí; en cron y modos desatendidos, comandos peligrosos denegados por defecto |
| Telemetría | Existe un módulo `analytics` y comandos `telemetry`/`tunnel`; destino **[sin verificar]** | No consta |

## Contraste con los requisitos de Alfred (según lo leído)

1. **Niveles 1/2/3 aplicados por código, con aprobación del nivel 3 por Telegram.** Ninguno lo documenta tal cual. La aprobación `smart` de Hermes depende de un modelo, y para Alfred la decisión de permisos tiene que ser código, no IA.
2. **Herramientas por perfil.** No consta en ninguno; Hermes habla de *toolsets* (el de Telegram incluye terminal).
3. **Lector en cuarentena (salida JSON validada).** Ninguno lo trae. Hermes escanea archivos de contexto buscando inyección de prompts, que es algo distinto.
4. **Tope de coste con corte.** Ninguno lo documenta.
5. **Auditoría de solo añadir y `/stop`.** No consta en ninguno.
6. **Aislamiento y superficie.** Los dos instalan con `curl | bash` y arrastran muchas dependencias (modelo local, Rust, Chromium, Node). Alfred, en el MVP, no usa modelo local y parte de "cero puertos y mínimo software".
7. **Cadena de suministro.** Skills que se auto-generan o se descargan (Hermes) y presets con shell/código (OpenJarvis) chocan con la regla de revisar todo antes de ejecutarlo.

## Recomendación PROVISIONAL (juicio mío, sujeto a leer el código)

- **No usar ninguno de los dos como base de Alfred por ahora.** Con lo leído, ninguno cubre lo que Alfred exige y los dos meterían mucha superficie nueva en el servidor.
- **Escribir a mano el primer bucle de agente** (unas 60 líneas, como ya dice `CLAUDE.md`) con los niveles de permiso, el tope de coste y la auditoría en código.
- **Ideas que sí merece la pena copiar** (patrones, no código): lista de usuarios permitidos con "denegar por defecto" para el canal de Telegram; modos desatendidos que deniegan lo peligroso; una lista de bloqueo fija que ningún ajuste pueda saltar; quitar del entorno de las herramientas las variables con KEY, TOKEN o SECRET.
- Esta recomendación **puede cambiar** si el código o la documentación de seguridad de OpenJarvis (aún sin leer) resulta mejor de lo que parece.

## Pendiente para cerrar la parte A

1. Leer los repositorios `open-jarvis/OpenJarvis` y `NousResearch/hermes-agent` (estrellas, última versión y fecha, `SECURITY.md`, actividad, issues de seguridad).
2. Leer `install.sh` de los dos, completos, antes de ejecutarlos.
3. Leer la documentación de seguridad, sistema, agentes y canales de OpenJarvis, y las de cron, memoria, skills y Telegram de Hermes.
4. Confirmar el destino de la analítica de OpenJarvis y si Hermes envía telemetría.
5. Confirmar el backend de terminal por defecto de Hermes en instalación de servidor.
6. Solo entonces, decidir si merece una parte B (prueba en contenedor aislado sin datos).

## Decisiones tomadas tras este borrador (2026-11-24)

Antonio quiere que Alfred tenga autoaprendizaje como Hermes, pero con aprobación automática y reversible, y reutilizar skills útiles de los repos ajenos tras comprobar que son seguras. El diseño (categoría de aprendizaje aparte del nivel 3, solo texto, lo derivado de contenido externo queda pendiente, temas vetados, comandos de listado y reversión, consolidación semanal en local) está en `docs/DECISIONES.md`, entrada del 2026-11-24. Para copiar patrones concretos de Hermes sigue haciendo falta leer su repositorio.

## Segunda lectura (2026-11-24): repos y documentación ampliada

Fuentes leídas por la web (páginas de GitHub y documentación, **no código fuente**): `NousResearch/hermes-agent` (README, SECURITY.md, LICENSE y documentación de seguridad, skills, memoria, mensajería y configuración), `NousResearch/hermes-agent-self-evolution` (README) y `open-jarvis/openjarvis` (página principal, última release e índice de la documentación). **Siguen sin leerse** los `install.sh`/`install.ps1` de ambos, los releases de Hermes, el código de aprobación y toda la documentación de seguridad, telemetría, canales y skills de OpenJarvis (rechazadas por la herramienta de lectura). Cifras de estrellas y forks varían entre capturas; no se han verificado.

### Hermes Agent (MIT; ~260k estrellas según la página)
- **Terminal por defecto: local, sin aislamiento** ("commands run directly on your machine"). Docker es opcional. Su `SECURITY.md` dice que la única frontera real contra un modelo adversario es el sistema operativo.
- **Aprobación de comandos:** `smart` (por defecto, un LLM auxiliar valora el riesgo), `manual` y `off`; lista fija de bloqueo que ni YOLO salta; reglas `deny` por patrón; si no hay respuesta en 300 s, se deniega.
- **Skills:** archivos `SKILL.md` con subcarpetas opcionales (`scripts/`, etc.); **pueden ejecutar Python al cargarse** (lo dice su `SECURITY.md`). El agente las crea solo y por defecto **sin pedir confirmación** (`skills.write_approval: false`); con `true` quedan pendientes hasta `/skills approve`. Las skills de un repo de git no se cargan hasta `hermes skills trust`.
- **Memoria:** `MEMORY.md` (2.200 caracteres) y `USER.md` (1.375), fijadas al inicio de la sesión; el agente escribe sin permiso por defecto y las entradas se escanean contra patrones de inyección. Búsqueda de sesiones en SQLite local.
- **Telegram:** deniega por defecto a quien no esté en la lista (`TELEGRAM_ALLOWED_USERS`) o emparejado por DM con un código que caduca en 1 hora; `GATEWAY_ALLOW_ALL_USERS` desaconsejado con acceso a terminal.
- **Coste:** sin tope global de gasto. Solo un límite de tokens por revisión en segundo plano y la opción de desactivarla.
- **Telemetría:** las páginas leídas no la mencionan; comprueba actualizaciones contra la API de GitHub como mucho cada 24 h. **No se puede afirmar que no haya telemetría** sin leer código e instalador.
- **Instalación:** `curl | bash` desde su dominio; contenido **no leído**.

### hermes-agent-self-evolution (MIT; repositorio aparte, ~5k estrellas)
- **No es aprendizaje en vivo.** Es una herramienta fuera de línea que optimiza skills, descripciones de herramientas, prompts y (planificado) código con DSPy + GEPA y propone el resultado como **PR contra hermes-agent**. Solo la fase 1 (skills) figura como implementada; las fases 2 a 5, como planificadas.
- **Salvaguardas que enumera:** la suite de tests debe pasar al 100 %, skills de máximo 15 KB, descripciones de herramientas de máximo 500 caracteres, sin cambios a mitad de conversación y sin desviarse del propósito original, más **revisión humana del PR**.
- **No aparece** ninguna defensa contra inyección o envenenamiento de las trazas de sesión. Con la opción `sessiondb` el historial real de sesiones sale hacia las APIs de modelos configuradas.
- Coste declarado: unos 2-10 USD por ejecución. Una de sus dependencias (Darwinian Evolver) es AGPL v3, usada como herramienta externa.

### OpenJarvis (Apache-2.0; ~17,5k estrellas según la página)
- Última release visible: `desktop-v1.0.2` (app de escritorio, 25 de mayo; el año se deduce). En la raíz del repo no aparece `SECURITY.md`.
- Por nombres de módulos del índice de la documentación existen `guardrails`, `file_policy`, `taint`, `injection_scanner` y `approval_routes`/`approval_store`: **solo por el nombre; no se sabe qué hacen ni si están activos por defecto.**
- Skills según el estándar abierto agentskills.io, importables desde Hermes u otros repos de GitHub; existe `jarvis optimize skills`. No se leyó si pueden ejecutar código ni si piden aprobación.
- Módulo `analytics` (cliente, identidad, redacción, eventos): destino de los datos **sin verificar**. Sin tope de gasto encontrado, solo seguimiento de coste.
- Los presets con shell, archivos y ejecución de código siguen siendo un riesgo.

### Qué cambia para Alfred
1. **Se mantiene la recomendación:** ninguno como base. El hallazgo clave es que la forma en que Hermes aprende por defecto (skills que pueden ejecutar Python, creadas sin confirmación, terminal local sin aislamiento) es justo lo que Alfred descarta. Confirma la regla de que **una skill es solo texto**.
2. **Ideas que sí se adoptan (patrones, no código):** interruptor explícito de aprobación de escritura de aprendizaje; tope de tamaño para memoria y skills; escaneo de las entradas de memoria contra patrones de inyección; emparejamiento por código de un solo uso y con caducidad para añadir usuarios; "denegar por defecto" y lista de bloqueo fija; versionado de las skills en git para revertir; y **puertas automáticas antes de aplicar un cambio** (tamaño, formato, que no cambie el propósito), que encajan con la aprobación automática de Alfred.
3. **Formato de skills:** valorar el estándar agentskills.io (texto con `SKILL.md`) por compatibilidad, **restringido a markdown sin scripts**. Falta leer su especificación.
4. **Lo que ninguno cubre y Alfred sí debe hacer:** separar lo aprendido de contenido externo (queda pendiente de aprobación), temas vetados, tope de gasto con corte y auditoría de solo añadir.
5. **Pendiente de leer** si se quiere profundizar: `install.sh` de ambos, el código de aprobación de Hermes y los módulos `injection_scanner`, `taint` y `approval_*` de OpenJarvis (por si hay ideas aprovechables). Antes de ejecutar nada de esto, parte B en contenedor aislado y solo si Antonio lo pide.

### Formato Agent Skills (agentskills.io) — leído el 2026-11-24
Especificación y repositorio oficial leídos por la web. Detalles y decisión de usar solo el subconjunto markdown (sin `scripts/`, sin `allowed-tools`) en `docs/DECISIONES.md`. Sin versión de la especificación en las páginas leídas; las instrucciones de instalación de `skills-ref` no se leyeron.
