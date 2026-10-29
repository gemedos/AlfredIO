# Alfred + domótica de la habitación: plan de desarrollo conjunto y costes

Fecha: 28 de octubre de 2026. Preparado a partir de `context.md` (conversación sobre el asistente), `home automation.md` (conversación sobre domótica) y la investigación de esta sesión. Complementa el documento "Alfred: estudio de viabilidad, costes y plan de desarrollo".

Nota sobre fiabilidad de las cifras: solo el precio del mini PC (189 €) viene de ti. Los precios de piezas marcados con (V) los he visto en una tienda o fuente concreta (indicadas al final). Todo lo demás son estimaciones mías de orden de magnitud para España con IVA; compruébalas antes de comprar.

---

## 1. Resumen

**Se puede montar todo por unos 225-250 € (versión mínima) o unos 260-305 € (versión recomendada), contra los 560-755 € que costaría seguir al pie de la letra el diseño del otro hilo.** El ahorro viene de tres decisiones: no comprar una Raspberry Pi ni un receptor Bluetooth para el altavoz, empezar la voz con un micrófono USB en el propio mini PC en lugar de comprar un satélite caro, y reutilizar un móvil viejo como pantalla.

Las cinco decisiones que más pesan:

1. **El mini PC hace todo en la mesa.** Asistente, Home Assistant, dongle Zigbee opcional, micrófono USB y salida de audio. Está a un metro del altavoz, así que no hace falta ningún aparato de audio intermedio.
2. **El audio va por cable, no por Bluetooth.** El mini PC se conecta al altavoz con un cable (jack o DAC USB barato). Es mejor calidad que cualquier receptor Bluetooth y cuesta menos. El móvil usa el Bluetooth que ya trae el altavoz.
3. **El selector de entradas es un ESP32 con emisor infrarrojo** (unos 6-10 €), siempre que el altavoz tenga mando por infrarrojos con botones de entrada directos. Si no los tiene, se usa un relé (unos 10-14 €).
4. **La voz empieza barata y con una salida de emergencia.** Un micrófono USB (unos 10-15 €) más una tecla de "pulsar para hablar" en tu teclado. El satélite DIY con ESP32-S3 (unos 18-26 €) llega después y solo si lo necesitas.
5. **Todo lo de la habitación va en una red aislada** y Alfred solo puede tocarlo a través de Home Assistant con permisos por niveles (sección 6).

---

## 2. Qué necesitas, según el documento de domótica

El documento empieza a mitad de una conversación, así que no recoge tus peticiones originales. Esto es lo que se deduce de las respuestas y de tu último mensaje:

| Necesidad | Qué se pide |
| --- | --- |
| Luz LED con presets | Colores y escenas como "relax", "gaming" o "dormir", activables por voz |
| Voz | Hablar en alto en la habitación para despertar a Alfred |
| Pantalla de informes | Una pantalla de color donde Alfred muestre informes cortos |
| Encendido del PC | Encender el PC de sobremesa a distancia |
| Altavoz | "Conecta mi móvil al altavoz", "conecta el PC" (por cable) y "pon tal canción" (desde el mini PC) |
| Puerta y timbre | Avisos cuando se abre la puerta o suena el timbre; la puerta está dos plantas más abajo |

Tu distribución física importa mucho y cambia el diseño: PC de sobremesa en el escritorio, pantalla en una mesita auxiliar encima, y debajo el mini PC, el selector de audio y el teclado. El altavoz va sobre la mesita. Todo está a menos de dos metros.

---

## 3. ¿Hay una forma mejor o más barata? Sí, en seis puntos

Cada punto indica qué propone el otro hilo, qué propongo yo y cuánto ahorra.

### 3.1 Hub: Home Assistant en el propio mini PC
El otro hilo ya lo sugería como opción. Lo confirmo: Home Assistant en un contenedor Docker en el M80q cuesta 0 € y evita la Raspberry Pi (0-130 €). Home Assistant aporta las integraciones ya hechas (ESPHome, WLED, Zigbee, Wake-on-LAN, notificaciones), así que Alfred solo necesita hablarle a su API y no programar cada dispositivo.

### 3.2 Altavoz: cable en vez de receptor Bluetooth o Raspberry Pi
- **Otro hilo:** una Raspberry Pi con DAC como receptor Bluetooth y reproductor de red, más selector, por 120-230 € (sin contar el altavoz).
- **Mi propuesta:** como el mini PC está junto al altavoz, sale por cable directamente. Dos opciones: la salida de auriculares del propio mini PC (0 € más un cable de 3,5 mm a RCA de 4-6 €), o un DAC USB barato de 10-15 € si oyes ruido o quieres más calidad.
- **Ahorro:** unos 100-180 €.
- **Por qué es mejor sonido:** el Bluetooth comprime el audio y su calidad depende del códec, no del precio del receptor. Un cable lleva el audio sin comprimir.
- **Tu idea de "reproducir por Bluetooth hacia el mini PC":** no hace falta y empeora el sonido. La música que ponga Alfred sale por cable. El Bluetooth solo se usa para el móvil, y lo recibe el altavoz directamente con su propio Bluetooth.

### 3.3 Selector de entradas: infrarrojos antes que relés
Muchos altavoces con mando permiten cambiar de entrada con él. Un ESP32 con un LED infrarrojo (unos 6-10 €) puede imitar ese mando sin tocar la señal de audio ni abrir nada.
- **Condición clave:** el mando debe tener un botón directo por entrada. Si solo tiene un botón que recorre las entradas, el ESP32 no sabe en cuál está y se desincroniza. En ese caso se usa un relé de audio (unos 10-14 €, 4-6 € más), que sí es de estado conocido.
- **Qué comprobar antes de comprar el altavoz:** que tenga al menos tres entradas (cable del PC, cable del mini PC, Bluetooth) y mando con botones de entrada directos. Los Edifier de la serie R1280 que mencionaba el otro hilo tienen dos entradas RCA, óptica, coaxial, Bluetooth y mando que cambia de entrada; [la tienda de Edifier](https://edifier-online.com/es/collections/all/products/edifier-r1280db) no aclara si el mando tiene botones directos, así que mira el manual o una foto del mando antes de decidir.
- **Qué hace cada orden de voz:** "conecta mi móvil" envía el infrarrojo a la entrada Bluetooth. "Conecta el PC" selecciona la entrada del PC. "Pon X" selecciona la entrada del mini PC e inicia la reproducción.
- **Bluetooth y móvil:** Android suele reconectarse solo al activar la entrada Bluetooth del altavoz. En iPhone a veces hay que tocar el altavoz en la lista de dispositivos.

### 3.4 Música: servicios que ya conoces, sin hardware extra
La música que inicia Alfred sale del mini PC por el cable. Dos vías:
- **Spotify.** Alfred controla la reproducción a través de [la integración de Spotify de Home Assistant](https://www.home-assistant.io/integrations/spotify), que exige cuenta Premium (desde febrero de 2026 también para crear la aplicación de desarrollador) y que el dispositivo de reproducción esté ya registrado en tu cuenta. Para que el mini PC aparezca como dispositivo se instala un receptor de Spotify Connect como librespot (gratuito y de código abierto).
- **Biblioteca propia.** Si tienes música en archivos, Navidrome o MPD en el mini PC con Music Assistant: 0 € y sin suscripción.

### 3.5 Voz: empezar con micrófono USB y tecla de hablar
- **Otro hilo:** satélite ESP32-S3 (Atom Echo 15-20 €, ESP32-S3-BOX-3 55-70 € o Voice PE unos 60 €).
- **Mi propuesta, por etapas:**
  1. **Etapa 1 (10-15 €):** un micrófono USB de escritorio conectado al mini PC más una tecla de tu teclado para "pulsar para hablar". Pruebas todo el ciclo de voz el primer día y no dependes de entrenar una palabra de activación.
  2. **Etapa 2 (18-26 €):** un satélite hecho por ti con ESP32-S3 con PSRAM, micrófono INMP441 y amplificador MAX98357A con un altavoz pequeño. Una guía de [esp32.co.uk](https://esp32.co.uk/diy-home-assistant-voice-assistant-esp32-s3-esphome/) lo detalla, con detección de la palabra dentro del propio ESP32.
  3. **Etapa 3 (opcional, 59 €):** el [Home Assistant Voice Preview Edition](https://www.home-assistant.io/voice-pe/), que tiene dos micrófonos, un chip XMOS con cancelación de eco y salida de 3,5 mm. La página oficial no lista distribuidores en España, así que habría que importarlo; comprueba el envío antes.
- **Un problema real de tu colocación:** si el altavoz suena fuerte junto al micrófono, la palabra de activación fallará con cualquier micrófono barato. La guía de ESP32 lo reconoce: el montaje DIY no tiene cancelación de eco y depende de la separación física y de un volumen moderado. Solución barata: poner el micrófono lejos del altavoz o usar la tecla de hablar cuando suene música, y que Alfred pause la música al detectar la palabra.
- **Dónde habla Alfred:** por el altavoz pequeño del satélite o, en la etapa 1, por un altavoz económico de 3,5 mm (8-15 €) conectado al mini PC. El altavoz bueno queda solo para música.

### 3.6 Otros ahorros pequeños
- **Pantalla:** reutiliza un móvil o tablet viejo con un panel de Home Assistant (0 €), o simplemente muestra los informes en el monitor de tu PC o por Telegram. Comprar la pantalla de 12-18 € o la de 35-50 € solo si no tienes nada que reutilizar.
- **Luz LED:** usa WLED (firmware gratuito) en un ESP32 con tira WS2812B. Incluye presets y efectos listos y Home Assistant lo detecta solo. Unos 17-28 € frente a los 21-34 € del otro hilo.
- **Encender el PC:** Wake-on-LAN desde Home Assistant cuesta 0 € si tu placa lo permite desde apagado. El ESP32 con relé (8-12 €) queda como plan B.
- **Puerta:** un sensor Zigbee cuesta unos 9-10 € ([Sonoff SNZB-04P a 10,29 € y Avatto a 8,59 € en PcComponentes](https://www.pccomponentes.com/categorias/sensores-puertas-y-ventanas/zigbee)) pero necesita un dongle Zigbee de unos 21-30 € ([Sonoff ZBDongle-E](https://www.lesalexiens.fr/deal/soldes-sonoff-zb-dongle-e-compatible-matter-21e/), precio visto en una oferta francesa). Si solo vas a poner un sensor, el nodo ESP32-C3 de 18-29 € es más barato. Si vas a poner tres o más sensores (temperatura, ventanas), Zigbee gana, porque las pilas duran años y los enchufes repiten la señal.

---

## 4. Arquitectura conjunta

```
                    Tu móvil (Tailscale: red privada)
                              |
                         Telegram / web
                              |
 +---------------- Mini PC M80q (debajo de la mesa) ----------------+
 |  Alfred (agente + permisos + enrutador de modelos)               |
 |  Lector en cuarentena  |  Navegador ligero  |  Voz (Whisper/Piper)|
 |  Home Assistant        |  Modelo local      |  librespot / MPD   |
 |  Micrófono USB (entrada)  Salida de audio (jack o DAC USB)       |
 +------+------------------------+-----------------------+---------+
        | cable de audio         | Wi-Fi (red IoT)       | USB
        v                        v                       v
   Altavoz bueno          ESP32 infrarrojo         Dongle Zigbee (opc.)
   (entradas: PC,         (selector de entradas)
    mini PC, Bluetooth)   ESP32 + WLED (luz)
        ^                 ESP32-C3 (puerta/timbre)
        | cable          Satélite ESP32-S3 (etapa 2 de voz)
   PC de sobremesa
   (Wake-on-LAN desde HA)
```

Alfred nunca habla directamente con los ESP32: lo hace a través de la API de Home Assistant. Eso permite poner una lista de acciones permitidas en un solo sitio.

---

## 5. Cómo hablan las piezas con el altavoz

| Tú dices | Qué ocurre |
| --- | --- |
| "Alfred, conecta mi móvil al altavoz" | El ESP32 manda por infrarrojos la entrada Bluetooth; el móvil se reconecta al altavoz |
| "Alfred, conecta el PC" | El ESP32 manda la entrada del PC; Alfred pausa la música del mini PC |
| "Alfred, pon [canción]" | Alfred busca la canción, el ESP32 selecciona la entrada del mini PC y comienza la reproducción |
| "Alfred, sube el volumen" | Se usa el control de volumen del propio mini PC (software) para no depender de más infrarrojos |

Un límite de seguridad útil: Alfred tiene un volumen máximo configurado, para que ningún error o mensaje malicioso pueda subir el sonido de golpe a las tantas de la noche.

---

## 6. Seguridad ampliada con la domótica

1. **Red aparte para los dispositivos.** Crea en tu router una red de invitados o IoT solo para los ESP32 y la tira LED, sin acceso a tus ordenadores. Si un dispositivo barato se compromete, no llega al resto.
2. **Alfred solo toca la domótica a través de Home Assistant,** con una lista cerrada de acciones.
3. **Niveles de permiso aplicados a la habitación:**

| Nivel | Ejemplos |
| --- | --- |
| 1. Libre | Leer si la puerta está abierta, consultar el estado del PC, leer el informe |
| 2. Registrado | Cambiar la luz, cambiar entrada del altavoz, poner música, ajustar volumen (con tope) |
| 3. Con aprobación | Encender o apagar el PC, cualquier acción que afecte a otras personas |

4. **Micrófono:** la palabra de activación se detecta en el propio dispositivo, el audio solo viaja por tu red privada y debe existir un interruptor físico de silencio.
5. **Corriente de red (230 V):** no se toca. Para encender o apagar cosas con enchufe, solo módulos certificados como Shelly. Todo lo demás en esta lista es de baja tensión.
6. **Edificio compartido:** no se toca el portal ni el portero automático de la comunidad sin permiso. Un sensor en la puerta de tu propia vivienda sí es posible.

---

## 7. Plan de desarrollo conjunto con Claude Code

Se trabaja en dos vías que se juntan: el núcleo de Alfred (A) y la domótica (B). Las horas son tuyas (pruebas, cableado, revisión de código); Claude Code escribe la mayor parte del código.

Reglas de velocidad y seguridad:
- Pide hoy las piezas con envío lento (ESP32, micrófono, tira LED) para no esperar después.
- Programa el núcleo de Alfred en tu equipo de desarrollo con Docker antes de que llegue el M80q.
- No des a Claude Code acceso al servidor de producción ni a las claves de Alfred. Despliega con Git.
- Lee tú, línea por línea, el código que decide qué puede hacer Alfred sin pedirte permiso.

| Fase | Vía | Qué se hace | Criterio de éxito | Horas tuyas |
| --- | --- | --- | --- | --- |
| 0. Servidor | A | Instalar el sistema, cifrado de disco, SSH con clave, Tailscale, cortafuegos, copia de seguridad; Home Assistant en Docker | Entras por SSH desde el móvil con datos móviles y has restaurado una copia de prueba | 5-7 |
| 1. Núcleo de Alfred | A | Bucle de agente, enrutador de modelos, bot de Telegram restringido a tu usuario, registro de auditoría, comando `/stop`, órdenes fijas | Alfred responde en Telegram y `/stop` lo desactiva | 6-10 |
| 2. Seguridad | A | Contenedores sin privilegios, salidas de red limitadas, niveles de permiso con aprobación, lector en cuarentena, ataques de prueba | Un conjunto de al menos diez ataques de prueba no consigue acciones de nivel 2 o 3 sin aprobación | 6-8 |
| 3. Quick wins de la habitación | B | Luz con WLED, Wake-on-LAN, cable de audio del mini PC al altavoz, ESP32 infrarrojo, música (Spotify Connect o biblioteca propia) | Dices "relax", "pon X" y "conecta el PC" y cada cosa ocurre; el volumen tiene tope | 12-20 |
| 4. Búsqueda web y Bakit | A | SearXNG, lectura de páginas por el lector en cuarentena, detector de caídas y informe de diagnóstico | Una caída de prueba de Bakit llega a Telegram con diagnóstico citando los logs | 7-11 |
| 5. Voz | B | Etapa 1 (micrófono USB y tecla), luego etapa 2 (satélite ESP32-S3 DIY) con "hey jarvis" y después "Alfred" | Menos de cinco segundos desde que terminas de hablar hasta que empieza la respuesta (objetivo, a medir) y menos de un falso despertar al día | 10-16 |
| 6. Puerta, timbre y pantalla | B | Nodo de puerta y timbre, pantalla reutilizada | Recibes aviso en el móvil al abrir la puerta y al sonar el timbre | 6-10 |
| 7. Pisos turísticos | A | Informe matinal de solo lectura y borradores de mensajes con aprobación | El informe coincide con tu dashboard durante una semana; ningún mensaje sale sin aprobación | 6-10 |

**Total: unas 58-92 horas tuyas.** A 10 horas semanales son entre 6 y 9 semanas; a 20 horas semanales, entre 3 y 5. Una versión ya útil (fases 0 a 3, unas 29-45 horas) está en unas 3 a 5 semanas a 10 horas semanales, contando que el mini PC ya esté en tu mesa.

Lo que conviene no acelerar: la fase 2 (revisar a mano los permisos), las pruebas de voz con música real y la restauración de una copia de seguridad.

---

## 8. Desglose de costes

### 8.1 Asistente (sin domótica)

| Concepto | Coste |
| --- | --- |
| Mini PC Lenovo M80q (tu negociación en Wallapop) | 189 € |
| SAI o batería para cortes de luz (opcional, estimación) | 0-50 € |
| Ampliar a 32 GB de RAM | No hace falta; decídelo tras medir el modelo local |
| SSD más grande | No hace falta para empezar |

### 8.2 Domótica de la habitación: versión mínima y recomendada

| Bloque | Mínimo | Recomendado | Notas |
| --- | --- | --- | --- |
| Hub (Home Assistant en el mini PC) | 0 € | 0 € | Sin Raspberry Pi |
| Entrada de voz | 10-15 € | 18-26 € | Mínimo: micrófono USB y tecla. Recomendado: satélite DIY ESP32-S3 |
| Salida de audio mini PC al altavoz | 4-6 € | 14-21 € | Mínimo: jack y cable. Recomendado: DAC USB y cable |
| Selector de entradas (ESP32 infrarrojo) | 6-10 € | 6-10 € | Relé como alternativa: +4-6 € |
| Música (Spotify Connect o biblioteca propia) | 0 € | 0 € | No incluye tu suscripción de Spotify, si la tienes |
| Luz LED con presets (WLED) | 17-28 € | 17-28 € | ESP32, tira, fuente de 5 V y componentes |
| Encender el PC (Wake-on-LAN) | 0 € | 0 € | Plan B con ESP32: 8-12 € |
| Pantalla de informes | 0 € | 0 € | Reutilizando un móvil o tablet; comprar una: 12-18 € |
| Puerta y timbre (nodo ESP32-C3) | 0 € | 18-29 € | Mínimo: se deja para más adelante |
| **Subtotal domótica** | **~37-59 €** | **~73-114 €** | |

Contingencias que no están sumadas y que quizá no necesites: extensor Wi-Fi para llegar a la puerta (25-35 €), aislador de bucle de masa si oyes zumbido (unos 10 €), pantalla comprada (12-18 €), plan B del encendido del PC (8-12 €), relé de audio si el mando no tiene botones directos (4-6 €), herramientas si no las tienes (soldador y multímetro, 30-50 €).

### 8.3 Total y comparación

| | Mínimo | Recomendado | Siguiendo el otro hilo |
| --- | --- | --- | --- |
| Mini PC | 189 € | 189 € | 189 € |
| Domótica | 37-59 € | 73-114 € | ~320-515 € (rango medio del otro hilo con el bloque de altavoz sustituido por el de Pi y DAC) |
| SAI (opcional) | 0 € | 45-50 € | 45-50 € |
| **Inversión inicial** | **~225-250 €** | **~260-305 € (310-355 € con SAI)** | **~555-755 €** |

### 8.4 Gastos mensuales

| Concepto | Coste |
| --- | --- |
| Electricidad del mini PC en marcha las 24 horas (estimación, 35 W de potencia térmica de diseño, mucho menos en reposo) | ~3 € |
| Modelos por API (con un modelo de gama barata, uso normal) | 1-6 € |
| Copias de seguridad cifradas en la nube | 0-1 € |
| **Total mensual** | **~4-5 € (mínimo), ~5-8 € (recomendado)** |

Coste del primer año: unos 275-300 € (mínimo) y unos 330-400 € (recomendado, sin SAI).

### 8.5 Qué cambia respecto al estudio anterior
En el documento anterior, el escenario recomendado era de unos 330 € y 14 €/mes. Esta versión baja el gasto mensual (la API barata cuesta menos de lo supuesto) y sube algo la inversión inicial porque incluye la domótica. No incluye SSD más grande ni nodo de voz comprado.

---

## 9. Orden de compra para no gastar de más

1. **Ya:** cierra el M80q con las comprobaciones acordadas. Pide ESP32 (varios, con PSRAM si son S3), tira WS2812B, fuente de 5 V, micrófono USB y cable de audio.
2. **Cuando empieces la fase 3:** compra el DAC USB solo si el jack del mini PC tiene ruido o no te gusta cómo suena.
3. **Antes de comprar el altavoz bueno:** comprueba entradas y mando (sección 3.3).
4. **Después de usar la voz una semana:** decide si compras el satélite (etapa 2) o un Voice PE.
5. **Después de medir el Wi-Fi hasta la puerta:** decide entre nodo ESP32-C3, Zigbee o extensor.

---

## 10. Decisiones abiertas y preguntas que cambian el plan

| Pregunta | Por qué importa |
| --- | --- |
| ¿Qué altavoz vas a comprar y tiene mando con botones de entrada directos? | Decide entre infrarrojos (6-10 €) y relé (10-14 €) |
| ¿Tienes suscripción Premium de Spotify, o prefieres música propia? | Decide la vía de música |
| ¿Tu placa soporta Wake-on-LAN desde apagado? | Si falla, +8-12 € |
| ¿El Wi-Fi llega a la puerta? ¿Es edificio compartido? | Decide nodo propio, extensor o Zigbee |
| ¿Puedes acceder al circuito del timbre de tu vivienda? | Sin acceso, se sustituye por un sensor de sonido o se descarta |
| ¿Tienes soldador y multímetro? | Evita 30-50 € |
| ¿Android o iPhone? | El Bluetooth del móvil con el altavoz es más fiable en Android |
| ¿Cómo de grande es la habitación y cuánta música a volumen alto? | Decide si basta un micrófono en la mesa o hace falta un satélite aparte |

---

## 11. Fuentes consultadas en esta sesión

- [Home Assistant Voice Preview Edition](https://www.home-assistant.io/voice-pe/): 59 € de precio recomendado, jack de 3,5 mm, XMOS con cancelación de eco, palabra de activación en el dispositivo. No lista distribuidores en España.
- [Guía de satélite de voz DIY con ESP32-S3](https://esp32.co.uk/diy-home-assistant-voice-assistant-esp32-s3-esphome/): lista de piezas sin precios, limitaciones de eco.
- [Integración de Spotify de Home Assistant](https://www.home-assistant.io/integrations/spotify): exige Premium; hay que elegir antes el dispositivo de reproducción.
- [Sensores Zigbee de puerta en PcComponentes](https://www.pccomponentes.com/categorias/sensores-puertas-y-ventanas/zigbee): Avatto ZDS16 8,59 €, Sonoff SNZB-04P 10,29 €.
- [Oferta del dongle Sonoff ZBDongle-E](https://www.lesalexiens.fr/deal/soldes-sonoff-zb-dongle-e-compatible-matter-21e/): unos 21 € en una oferta francesa.
- [Edifier R1280DB en la tienda del fabricante](https://edifier-online.com/es/collections/all/products/edifier-r1280db): entradas y mando; precio en dólares, no en euros.
- Documentos de tu carpeta: `context.md` y `home automation.md`.
- Estudio anterior: [Alfred: estudio de viabilidad, costes y plan de desarrollo](https://claude.ai/artifact/6frYsH697xKAFQTtFCjCWB).
