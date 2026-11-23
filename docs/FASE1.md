# Fase 1 — Informe de traspaso para Claude Code

Este documento resume lo decidido hasta el 2026-11-24 para que quien retome la Fase 1 (Claude Code en este repositorio) no dependa de ninguna conversación anterior. Si algo contradice a `CLAUDE.md`, manda `CLAUDE.md`; las decisiones con su porqué están en `docs/DECISIONES.md`.

## Lectura obligatoria, por orden
1. `CLAUDE.md` (sobre todo secciones 1, 5 —incluida la **5.7**—, 6, 7 y el Anexo A).
2. `prompt.md`, sección «Fase 1».
3. `docs/DECISIONES.md` (entrada del 2026-11-24 y las anteriores).
4. `docs/spike-openjarvis.md` (qué se leyó de OpenJarvis y Hermes y qué **no**).
5. `infra/m80q/README.md` (cómo está montado el servidor).

## Punto de partida
- Fase 0 terminada en el M80q (Debian 13, `alfred-m80q`, acceso por Tailscale, UFW, partición de datos cifrada en `/srv/alfred`, Docker rootless para el usuario `alfred`, alertas por Telegram con un bot **separado** del de Alfred, vigilancia de temperatura y de red). Pendientes de Fase 0: copias a disco USB y medición de consumo con Shelly.
- El servidor **comparte** máquina con Clipmation (usuario `clips`, Docker propio y límites de CPU/RAM). Alfred no debe tocar nada de eso. Ver `docs/conflict-alfred-clipmation.md`.
- Spike de OpenJarvis y Hermes: parte A hecha (lectura). **No se usan como base.** No hay parte B salvo que Antonio la pida.
- No hay código de Alfred todavía.

## Decisiones ya tomadas que afectan a la Fase 1
- **Primer bucle de agente escrito a mano** (unas 60 líneas) antes de añadir ningún framework.
- **Modelo por API**, con una capa de proveedor intercambiable (`base_url` configurable). Clave de **Claude Console exclusiva de Alfred**, en el almacén de secretos del servidor, nunca en el repo, en comandos ni en prompts. Modelo por defecto: el más barato que sea fiable (referencia en `prompt.md`; **comprobar nombres y precios actuales antes de fijarlo**). Sin Kimi/Moonshot con datos personales.
- **Tope de gasto doble:** el del código de Alfred (corta y avisa al 80 %) y uno mensual en la consola si la consola lo permite (por comprobar).
- **Niveles 1/2/3 aplicados por código.** Nivel 3 = aprobación de Antonio por Telegram con el resumen exacto. Lista de herramientas por perfil. Detalle en `CLAUDE.md` 5.1.
- **Autoaprendizaje (sección 5.7 de `CLAUDE.md`):** categoría «aprendizaje» con aprobación automática solo para texto que venga de Antonio; lo derivado de contenido externo queda pendiente; temas vetados; skills **solo texto** (`SKILL.md` + `references/` de texto, sin scripts, sin `allowed-tools`); herramientas nuevas redactadas en cuarentena y activadas por Antonio (nivel 3), salvo el **nivel 0 de cálculo puro**; consolidación semanal en local; comandos de listado y reversión.
- **Patrones a copiar de Hermes (ideas, no código):** lista de usuarios permitidos con «denegar por defecto», emparejamiento por código de un solo uso que caduca, lista de bloqueo fija, modos desatendidos que deniegan lo peligroso, quitar del entorno de las herramientas las variables con KEY/TOKEN/SECRET, tope de tamaño de la memoria, escaneo de entradas contra inyección, versionado en git de lo aprendido, y puertas automáticas antes de aplicar un cambio (tamaño, formato, que no cambie el propósito).

## Cómo trabajar (orden)
1. **Primero, un documento de diseño, sin código:** `docs/DISENO-NUCLEO.md` con arquitectura, estructura de carpetas, interfaces (proveedor, registro de herramientas, bucle, auditoría, coste, Telegram, perfiles), modelo de amenazas, esquema de la memoria y de las skills, y plan de tests. **Espera el «adelante» de Antonio** antes de escribir código.
2. Después, el núcleo en pasos pequeños y con tests, un commit por unidad de trabajo. Sin `git push` sin pedirlo (`CLAUDE.md` sección 7).
3. Autoaprendizaje: primero memoria y skills de texto con listado y reversión; las herramientas nuevas (borradores, cuarentena, nivel 0) **al final** de la fase, cuando lo demás pase las pruebas.

## Pruebas de aceptación (además de las de `prompt.md`)
- Una herramienta de cada nivel; una no listada **falla**; nivel 3 sin aprobación **no se ejecuta**; el tope de coste corta; `/stop` funciona.
- Aprendizaje de contenido externo **no** se aplica solo; un tema vetado **no** se aprende; `/revertir` deja el estado anterior y la auditoría conserva el rastro.
- El validador de skills **rechaza** `scripts/`, `assets/`, `allowed-tools`, URLs, comandos y patrones de inyección, y respeta el tamaño máximo.
- Una herramienta que intenta usar red o archivos no declarados **se bloquea**; el nivel lo asigna el código y no se puede bajar; una herramienta de nivel 0 que no cumple las condiciones **no** se activa sola.
- Un correo o web con una instrucción oculta no consigue crear una lección ni una herramienta activa.

## Lo que sigue abierto (preguntar a Antonio, no decidir solo)
- Modelo por defecto concreto, importe de los topes diario y mensual, y si la consola permite un límite por clave.
- Tamaños máximos de skills, memoria y herramientas.
- Nombres definitivos de los comandos de Telegram (`/aprendizajes`, `/aprendizaje`, `/revertir`).
- Qué telemetría o llamadas externas tendría cualquier componente de terceros que se quiera usar: **no se leyeron** los instaladores ni el código de OpenJarvis y Hermes.
- Opción futura (no decidida): consolidación mediante tarea programada de la cuenta Pro, solo con una copia sin datos sensibles y tras comprobar las condiciones de uso.

## Reglas que no se negocian
Sin pagos ni compras automáticas, sin mensajes reales sin aprobación, sin secretos pegados en el chat, sin instalar nada sin leerlo antes, y marcar siempre lo que sea estimación o no se haya probado.
