# App Review 2.1 — Information Needed (reply for version 1.0)

Apple asks every new developer account for this. Nothing is wrong with the
build: they want a screen recording from a real device and written answers to
six questions. Send the answers as a reply in App Store Connect **and** paste
the same text into App Review Information → Notes, so later submissions carry it.

## 1. The screen recording

Record on the iPhone or iPad itself (Control Centre → Screen Recording), on the
latest iOS, with the build that was submitted. Landscape, sound on, about two
minutes. There is no account, no user-generated content and nothing paid, so
only the normal flow has to be shown.

1. Home screen → tap Apex Dash, so the recording starts with the launch.
2. Let the splash and the menu appear. Swipe once or twice through the
   dashboards so the carousel is visible.
3. Open Settings (bottom right) and turn on **Demo drive**. Come back.
4. Tap a dashboard to go full screen: revs, gear, speed, tyre temperatures and
   the lap delta are all moving. Wait for one shift so the rev lights flash.
5. Tap the screen, use the back button in the top left, swipe to another
   dashboard, open it full screen too (Broadcast or Cluster reads well here).
6. Open **Laps** and show a finished lap in the list.
7. Open the connection card at the top right: it shows the address and port
   the game should send telemetry to, and the address to open in a browser.
8. Optional but convincing: on a computer or a second phone on the same Wi-Fi,
   open that address and film the analysis page with the track map and traces.
9. Finish in Settings, showing that there is no account and no purchase.

Attach the file to the reply in App Store Connect (Review messages take
attachments). If it is too large, trim it or upload it unlisted to YouTube and
put the link in the reply as well as in the Notes field.

## 2. The written reply (paste as is)

The Reply box and the Notes field hold 4000 characters, so paste
`review-reply.txt` (3,616 characters) — the same answers, tightened. The longer
version below is kept for reference only.

```
Thank you for reviewing Apex Dash. There is no account, no user-generated
content and no paid content in the app, so the recording shows the normal
flow: launch, the dashboard menu, the built-in demo drive, a dashboard in
full screen, the lap list and the connection details.

1. SCREEN RECORDING
A screen recording captured on a physical iPhone running the latest iOS is
attached. It begins with launching the app and shows the typical user flow.
The app has no account registration, login or deletion, no user-generated
content, and no paid content or features.

2. PURPOSE AND TARGET AUDIENCE
Apex Dash turns an iPhone or iPad into the steering wheel display of a racing
game. Racing games such as EA SPORTS F1 25 and F1 26 broadcast the car's
telemetry over the local network sixty times a second. The app listens to that
stream and draws it the way a real wheel display would: revs and shift lights,
gear, speed, tyre and brake temperatures, sector times and the live delta to
the player's best lap. Every completed lap is recorded at 20 Hz and can be
studied afterwards in a browser.

The audience is people who play racing games at home. Hardware wheel displays
cost a few hundred dollars, and the existing phone apps need companion software
running on a PC, which console players cannot use. Apex Dash needs no companion
software: the game sends its data straight to the phone, so it also works on
PlayStation and Xbox. It is free, has no advertising, no accounts, no analytics
and no purchases, and the full source code is public under the GPLv3.

3. SETTING UP AND ACCESSING THE MAIN FEATURES
No login credentials or sample files are required.

A game is not needed to review the app. A built-in simulation drives a lap so
every screen works:
  1. Launch the app.
  2. Tap Settings at the bottom right of the menu.
  3. Turn on "Demo drive".
  4. Go back and tap any dashboard to open it full screen.
It can also be started from the connection card: tap the "Not connected" badge
at the top right, then "Demo drive".

With a real game: in EA SPORTS F1 25 or F1 26, open Settings > Telemetry, turn
UDP Telemetry on, leave Broadcast Mode off, and enter the IP address and port
shown on the app's connection card. Data then appears as soon as a session
starts.

Lap analysis: after a lap is completed, the app shows a local address such as
http://192.168.1.20:8777. Opening it in any browser on the same Wi-Fi shows the
track map, speed and pedal traces and a corner-by-corner table. That page is
served by the phone itself.

Permissions:
  - Local Network: required, to receive the game's UDP telemetry and to serve
    the lap analysis page to browsers on the same Wi-Fi. Please accept the
    prompt on first launch.
  - Camera: optional, used only to scan the pairing QR code shown on
    apexdash.pro so a browser can find the phone. The app also displays the
    address for manual entry, and the app works fully without camera access.

The app is landscape only. This is intentional: it imitates a steering wheel
display and is meant to stand in front of the player.

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS
The app's core functionality uses no external services. All telemetry parsing,
lap recording and lap analysis happen on the device, and the analysis page is
served by the device itself over the local network. There is no backend, no
data provider, no authentication service, no payment processor, no advertising
SDK, no analytics SDK and no AI service. The app uses only Apple frameworks
(Network, AVFoundation, SwiftUI).

One optional convenience feature touches the internet: if the user opens
apexdash.pro in a browser and scans the QR code, the app publishes the phone's
local IP address once to the public notification relay ntfy.sh, so that the
browser can redirect itself to the phone. Only the local address is sent; no
telemetry, no lap data and no personal information. The feature is skipped
entirely if the user types the address manually, and the app is fully usable
without it.

5. REGIONAL DIFFERENCES
There are none. The app behaves identically in every region. It is localised in
English and Turkish, following the device language; no feature, content or
behaviour differs by country.

6. REGULATED INDUSTRY OR PROTECTED THIRD-PARTY MATERIAL
The app is not part of a regulated industry and contains no protected
third-party material. All artwork, code, fonts and sounds are original or
openly licensed, and none of the game's assets, liveries, logos or track
imagery are reproduced. The app only reads the UDP telemetry stream that EA
SPORTS F1 titles publish for this purpose; the packet format is documented
publicly by the publisher for third-party developers.

Trademarks are used only nominatively, to state which games the app can read
telemetry from. The app is not affiliated with, endorsed by or connected to
Formula One, the FIA, Electronic Arts or Codemasters, and the App Store
description says so. The app name and icon contain no third-party trademark.

Please let me know if anything else would help.
```

## 3. What to do in App Store Connect

1. App Review → the message from Apple → **Reply**, paste the text above and
   attach the recording (or include its link).
2. App Store Connect → the version → **App Review Information → Notes**: paste
   the same text there as well (Apple explicitly asks for this), keeping the
   existing demo-drive instructions.
3. Nothing else changes: no new build, no new screenshots. The submission stays
   in "Waiting for Review" once the reply is sent.
