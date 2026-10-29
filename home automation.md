Claude

Sumando los costes totales y las opciones de compra.

Room automation devices and costs (Spain, VAT included)

These are approximate prices from Amazon.es, AliExpress and Spanish shops like BricoGeek. I haven’t checked live listings, so verify before buying, since electronics prices move around a lot.



How it fits together

Every ESP32 runs ESPHome and shows up in Home Assistant (HA). Your local AI talks to HA through its REST API or MQTT, which is how it can change lights, push reports to the screen, or start music. Voice goes satellite mic → speech-to-text → your AI → text-to-speech, using HA’s Assist pipeline with your AI plugged in as the conversation agent.



1\. Hub (optional)

You probably don’t need to buy anything here. Home Assistant can run in Docker or a VM on the machine that runs your AI, or on any old PC.



Item	Cost

Raspberry Pi 45 kit with PSU, case and SSDSD (only if you want a dedicated box)	€0 – €130

2\. Voice input and the LED light with colour presets

Item	Purpose	Cost

ESP32 DevKit (classic or S3)	Drives the LEDs	€6 – 9

WS2812B strip (1 m, 60 LEDs) or a 16-LED ring	The light itself	€5 – 12

5V 3A power supply	Powers the LEDs	€7 – 10

330Ω resistor, 1000µF capacitor, optional 74AHCT125 level shifter	Protects the first LED and gives a clean signal	€3

Subtotal		€21 – 34

Presets like “relax”, “gaming” or “sleep” are just ESPHome effects or HA scenes, and the voice satellite triggers them.



Voice satellite. This must be an ESP32-S3, because voice needs the extra RAM.



Option	Notes	Cost

M5Stack Atom Echo	Cheapest, but the mic and speaker are mediocre	€15 – 20

ESP32-S3-BOX-3	Good mic array, speaker and a colour touch screen	€55 – 70

Home Assistant Voice Preview Edition	Best audio quality and the most plug-and-play	\~€60

My pick is the Voice PE if you want it to work reliably, or the Atom Echo if you want to start cheap.



3\. Colour screen for AI reports

Option	Notes	Cost

“Cheap Yellow Display” (ESP32-2432S028, 2.8)	Good for short summaries	€12 – 18

LilyGO T-Display-S3	Sharper, but small	€18 – 25

Waveshare ESP32-S3 touch LCD, 4.3	Better for longer text	€35 – 50

The AI publishes the report text to an MQTT topic, or renders it as a PNG that the ESP32 downloads. If you want AI-written paragraphs rather than short summaries, go for the 4.3.



4\. PC power-on

You may not need hardware here. Wake-on-LAN from HA works on most motherboards and costs nothing. If it’s unreliable, or you want to power on from a fully-off state



Item	Cost

ESP32 or ESP32-C3 board	€4 – 7

5V optocoupler or relay module	€2 – 3

2-pin cable and Dupont wires	€2

Subtotal	€8 – 12

It’s wired in parallel with your case’s power button header, so it’s low voltage and safe. Power it from a USB header that stays live on standby.



5\. Speaker control

A speaker’s Bluetooth connection is normally remembered. Once it’s paired with your phone or PC, it reconnects on its own when powered on. So “put it in Bluetooth mode” usually just means “power it on and select the right input”. There are two routes.



Option A hack the speaker you have. An ESP32 plus 2 optocoupler channels is wired across the speaker’s power and mode buttons, which means opening the speaker. It’s cheap (\~€10 – 14) but specific to your model, and it can void the warranty.



Option B the clean build, using powered speakers or an amp.



Item	Purpose	Cost

Smart plug (Shelly Plug S or Sonoff)	Power onoff	€10 – 25

ESP32 + PCM5102 DAC board	Bluetooth receiver (use the classic ESP32, since S3 and C3 lack Bluetooth audio)	€10 – 12

2-channel relay board	Switches between the PC’s cable input and the Bluetooth input	€4 – 6

Audio cables and jacks		€5 – 8

Subtotal		€29 – 51

A ready-made Bluetooth receiver costs €15 – 25 and saves the DIY step.



Music started by the AI can come from the PC through the cable input, so no extra hardware is needed for that.



6\. Door and bell alerts

Item	Purpose	Cost

ESP32-C3 board (e.g. XIAO)	Door node	€5 – 8

Magnetic reed switch	Detects the door opening	€2 – 4

ACDC optocoupler detector module	Detects the bell circuit (low voltage only)	€3 – 5

18650 battery, holder and TP4056 charger	Battery power if there’s no outlet nearby	€8 – 12

Subtotal		€18 – 29

Because the door is a couple of floors down, check whether your Wi-Fi reaches. If it doesn’t



A Wi-Fi extender or mesh node costs about €25 – 35.

A wired option is an ESP32 with Ethernet (WT32-ETH01, \~€12) if you can run a cable.

Alerts reach you as phone notifications through the HA app (free), plus an LED flash, a chime on the speaker, or a message on the screen.



If it’s a shared building, don’t touch the community’s portal door or intercom without permission. You can still put a sensor on your own flat door.



7\. Tools and consumables

Skip whatever you already own.



Item	Cost

Soldering iron and solder	€20 – 30

Multimeter	€12 – 20

Breadboards, jumper wires, perfboard, heat shrink	€10 – 15

Enclosures, USB cables, chargers	€10 – 15

Subtotal	€30 – 60

Total cost

Block	Low	High

Hub	€0	€130

LED light	€21	€34

Voice satellite	€15	€70

Screen	€12	€50

PC power-on	€8	€12

Speaker control	€14	€51

Door and bell	€18	€29 (+€35 if you need Wi-Fi range)

Tools and consumables	€0	€60

Total	\~€90	\~€470

A realistic mid-range build, with HA running on your existing machine, the Voice PE, a 4.3 screen and the clean speaker option, comes to about €250 – 300.



Buying tips for Spain

Amazon.es and BricoGeek are quicker, and the price already includes 21% VAT.

AliExpress is cheaper but takes 1 – 3 weeks. VAT is collected at checkout, and there may be a small flat EU customs fee on low-value parcels, so check at checkout.

Mains wiring keep all 230V work to certified modules like Shelly, as I mentioned earlier. Everything above is low voltage, which is deliberate.

Suggested build order

Voice satellite plus the LED light, since that proves the whole voice → AI → device loop.

PC power-on, the quickest win.

Door and bell alerts.

Screen reports from the AI.

Speaker control, the fiddliest part, so do it last.

Which speaker do you have, or plan to buy That decides between Option A and B. Also, is the door in a house you own or in a shared building



okay the ai assistant will be hosted in its own minipc and accesed by all my devices using  a private network. Regarding the speaker i want to be able to tell the microphone hey connect my phone to the speaker and so it does. Connect the speaker to the pc and it does via the cable. And play x song and it plays it from a bluetooth connection to the mini pc. Also im planning on buying  a somewhat decent speaker so im concerned about the quality of a external bluetooth receiver



Weighing wired versus network audio for the speaker endpoint.

Your concern is valid, and it changes my earlier recommendation. Skip the ESP32 Bluetooth receiver. It only does basic SBC Bluetooth, and with a decent speaker you’d hear the difference.



Where the quality is lost

Bluetooth from your phone quality is capped by the codec (SBC, AAC, aptX, LDAC), not by how expensive the receiver is. The receiver’s DAC matters for the analog stage, but it’s a smaller factor.

PC over cable lossless, so it will always sound best.

Music the AI plays it doesn’t need Bluetooth at all. Streaming over your network (Wi-Fi or Ethernet) is lossless, so it’s better than Bluetooth.

So Bluetooth is only needed for the phone, and everything else can be lossless.



Recommended design

Put a small audio endpoint next to the speaker. It’s a Raspberry Pi with a good DAC, and it handles two jobs



Phone audio it acts as a Bluetooth receiver (A2DP, via PipeWireBlueZ).

AI music it acts as a network player (Music AssistantSnapcastSqueezelite). Your AI says “play X” and the audio streams from the mini PC over the network.

Its DAC output goes to speaker input 1. Your PC’s cable goes to speaker input 2. An ESP32 relay selector (or IR control, if your speaker has a remote) switches between the two inputs by voice.



If the mini PC sits right next to the speaker, you can skip the Pi and use a USB DAC plugged into the mini PC. The mini PC then does both jobs.



How your voice commands work

You say	What happens

“Connect my phone to the speaker”	The AI tells the endpoint to run bluetoothctl connect phone, and the ESP32 switches to input 1

“Connect the PC”	The ESP32 switches to input 2, and the endpoint disconnects Bluetooth and stops playback

“Play X”	The AI finds the song (Spotify, local library or YouTube Music via Music Assistant), the endpoint plays it, and the ESP32 switches to input 1

One caveat is that connecting from the receiver’s side works reliably with Android, but iPhones are sometimes stubborn. If it’s flaky, the fallback is that the phone auto-reconnects when you press play, while the switching still happens by voice.



Parts and costs (Spain, VAT included, approximate)

Speaker. You need at least two wired inputs. Check that before buying.



Option	Notes	Cost

Edifier R1700BT  R1280DB	Several inputs and an IR remote, good value	€100 – 150

Edifier S3000 Pro or Audioengine A2+	Clearly better sound	€280 – 450

Passive speakers + a small amp (e.g. Fosi Audio or SMSL)	Best quality per euro, but more parts	€150 – 300

Audio endpoint.



Item	Cost

Raspberry Pi 4 (2 GB) with PSU and case	€60 – 80

DAC HiFiBerry DAC2 Pro or a USB DAC (e.g. FiiO K3, Topping E30)	€40 – 120

Total	€100 – 200

If you want LDAC or aptX HD from an Android phone, use a dedicated receiver instead. The FiiO BR13 or Qudelix 5K cost about €50 – 100, and they output to the same input. The Pi’s own Bluetooth is limited to SBCAAC.



Input selector.



Item	Cost

ESP32 + 2-channel signal relay board (audio-grade DPDT relays)	€8 – 12

RCA3.5 mm cables and ground-loop isolator if you hear hum	€10 – 20

Total	€18 – 32

If the speaker has an IR remote, an ESP32 with an IR LED (\~€8) can change inputs instead, which means no relays in the audio path at all.



Totals



Setup	Cost (excluding speaker)

Budget (USB DAC on mini PC, relay selector)	\~€70 – 100

Recommended (Pi endpoint + DAC + selector)	\~€120 – 230

Audiophile (dedicated LDAC receiver, better DAC)	\~€250 – 350

Add this to the previous estimate in place of the old speaker block (€14 – 51).



Things to know

Mute while switching. Relays can click or pop, so have the ESP32 mute the source briefly before switching.

Hum. If you hear it when PC and endpoint share a ground, a ground-loop isolator (\~€10) fixes it.

Latency. Network audio and Bluetooth both lag by 100 ms or more, which is fine for music but bad for video. Use the cable for movies and games.

Is the mini PC in the same spot as the speaker, or in another room That decides whether you need the Pi endpoint or can use just a USB DAC. And what speaker budget are you thinking of





Se ha quedado sin mensajes gratuitos hasta las 2150

do you



Claude es una IA y puede cometer errores. Comprueba las respuestas.



