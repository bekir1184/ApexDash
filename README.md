# F1Dash

iPhone'u F1 26'nin gercek direksiyon ekranina ceviren SwiftUI dashboard.
Oyunun UDP telemetri cikisini (packetFormat **2026**) dogrudan dinler, ara sunucu yok.

## Faz 1 kapsami

- 15 LED'lik devir seridi (`m_revLightsBitValue`) + shift flash
- Dev vites gostergesi, hiz, RPM ve RPM bari
- Gaz / fren cubuklari
- 2026 kurallari: **OVERTAKE** (manual override) ve **AERO X/Z** (aktif aero) rozetleri — DRS yok
- Pit limiter uyarisi
- Ekran uyku kilidi kapali, sadece yatay

## Oyun ayarlari (Ayarlar › Telemetri)

| Ayar | Deger |
| --- | --- |
| UDP Telemetry | On |
| UDP Broadcast Mode | **Off** |
| UDP IP Address | iPhone'un IP'si (uygulama sag altta gosterir) |
| UDP Port | 20777 |
| UDP Send Rate | 60 Hz |
| UDP Format | 2026 |
| Your Telemetry | Public |

> **Broadcast neden kapali?** iOS 14'ten beri broadcast/multicast trafigi almak
> Apple onayli `com.apple.developer.networking.multicast` yetkisi gerektiriyor.
> Unicast (dogrudan iPhone IP'sine) bu yetkiye ihtiyac duymaz. iPhone'un IP'si
> degismesin diye modemde DHCP rezervasyonu vermek isabetli olur.

## Gelistirme

```bash
xcodegen generate                 # F1Dash.xcodeproj uretir
open F1Dash.xcodeproj
```

Oyun acik olmadan test icin sahte telemetri:

```bash
python3 Tools/f1_sim.py 127.0.0.1      # iOS Simulator
python3 Tools/f1_sim.py 192.168.1.42   # gercek iPhone
```

## Paket duzeni

Spesifikasyon: EA Forums "F1 25: 2026 Season Pack UDP Specification".
Header 29 byte, little-endian, packed. Kullanilan paketler:

| ID | Paket | Boyut | Arac basina |
| --- | --- | --- | --- |
| 6 | Car Telemetry | 1448 | 59 byte |
| 7 | Car Status | 1445 | 59 byte |
| 16 | Car Telemetry 2 (aktif aero, overtake) | 269 | 10 byte |

## Sirada (faz 2)

- Tur suresi, son/en iyi tur, sektorler, canli delta (paket 2)
- Lastik sicaklik/basinc/asinma ve fren sicakliklari (paket 6 + 10)
- ERS deploy modu, batarya %, yakit delta (paket 7)
- Takim temalari, ozellestirilebilir ekran duzeni
