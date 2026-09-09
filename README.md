# F1Dash

iPhone'u F1 26'nin gercek direksiyon ekranina ceviren SwiftUI dashboard.
Oyunun UDP telemetri cikisini (packetFormat **2026**) dogrudan dinler, ara sunucu yok.

## Neler var

- 15 LED'lik devir seridi (`m_revLightsBitValue`); shift noktasinda tum ekran yanip soner
- Dev vites gostergesi, hiz, RPM ve RPM bari
- Gaz / fren cubuklari
- Dort kose lastik (yuzey + ic) ve fren diski sicakliklari, calisma araligina gore renkli
- Tur suresi ve yaninda onundeki araca delta: yaklasiyorsa yesil, uzaklasiyorsa kirmizi
- 2026 kurallari: **OVERTAKE** (manual override) ve **AERO X/Z** (aktif aero) — DRS yok
- En iyi tura gore canli delta ve renk kodlu sektor sureleri
- Wi-Fi degisince otomatik yeniden baglanma; IP degistiyse bekleme ekraninda uyari
- FIA bayraklari (`m_vehicleFiaFlags`) ve gecersiz tur uyarisi
- Pit limiter uyarisi
- Ekran uyku kilidi kapali, sadece yatay

## Tasarim temalari

Ekrana dokunup secilir, yana kaydirarak da gecis yapilir; secim saklanir.
Ayni cubuktaki **TR / EN** dugmesi arayuz dilini degistirir; uygulama telefonun
dili Turkce degilse Ingilizce baslar (gosterge etiketleri
her iki dilde de ayni kalir).

| Tema | Gorunum |
| --- | --- |
| `MODERN` | Bosch DDU tarzi, yuksek kontrastli temiz duzen |
| `DOT MATRIX` | **Varsayilan.** Gercek direksiyon LCD'si gibi nokta-matris panel; her sekil LED noktalarina ayrilir. Ustte iki gosterge: sari **BATTERY** (arka plani sarj oraninda dolar, depo dolunca yanip soner) ve mor **STRAIGHT MODE** (aktif aero hazir olup gecilmediyse yanip soner, gecilince tam yanar). Nokta dokusu ekranin tamamini kaplar |
| `REALISTIC` | Gercek F1 direksiyon ekraninin (Bosch / McLaren Applied tipi) taklidi: koyu zemin, ustte delta / durum / tur suresi, solda hiz, ortada dev vites ve altinda batarya, sagda yakit, altta lastik ve fren sicakliklari, en altta batarya seridi. Ekran, LED seridini tasiyan bir govde cercevesinin icinde oturur; iki yanindaki dikey kumeler FIA bayraklarini gosterir (sari ve mavi yanip soner, tur sayilmiyorsa yesil yanip soner). **Pit limiter devredeyken LCD sariya doner**, gercek araclardaki gibi |
| `YAYIN` | Yayin grafiklerindeki mavi HUD: ortada kalkan bicimli hiz gostergesi (km/h ve mph), BOOST ile overtake pili ve batarya cubugu, iki yanda gaz/fren ve RECHARGE/DEPLOY sutunlari, sagda aktif aero, vites siralamasi ve devir cetveli |
| `OYUN` | F1 26'nin kokpit ici direksiyon ekraninin birebir kopyasi: KPH / tur suresi + delta / yakit, ortada dev vites, L ve P kutulari, dort kose lastik sicakligi ve segmentli ERS bandi |

## Kurulum ekrani

Ilk acilista cikar; bekleme ekranindaki **KURULUMU AC / OPEN SETUP** dugmesiyle
her zaman geri gelir. Dinlenen portu buradan degistirirsin (dinleyici aninda
yeniden kurulur), telefonun IP adresini kopyalarsin ve oyunda girilecek butun
degerler karsi sutunda yazar.

## Bekleme ekrani

Veri gelene kadar pistteki baslangic isiklari yanar: bes kolon soldan saga
yanar, hepsi yanik kalir, soner ve bastan baslar. Altinda oyunda yapilmasi
gereken ayarlar ve telefonun IP adresi yazar.

## Oyun ayarlari (Ayarlar › Telemetri)

| Ayar | Deger |
| --- | --- |
| UDP Telemetry | On |
| UDP Broadcast Mode | **Off** |
| UDP IP Address | iPhone'un IP'si (uygulama sag altta gosterir) |
| UDP Port | 20777 (uygulamadaki kurulum ekraninda degistirilebilir) |
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
| 2 | Lap Data | 1399 | 57 byte |
| 16 | Car Telemetry 2 (aktif aero, overtake) | 269 | 10 byte |

## Tur kaydi ve web

Tamamlanan turlar sektor sureleriyle saklanir. Tema cubugundaki **TURLAR /
LAPS** dugmesi listeyi acar: en iyi tur mor, sektorler kendi renkleriyle.
Gonderim otomatiktir: eslestikten sonra her tur bitisinde turlarin tamami
gonderilir, ayrica yirmi saniyede bir tekrar denenir; panonun alt satirinda
`WEB <kod>` yaziyorsa baglanti ayakta demektir.

**Laptopta izlemek icin:** <https://f1dash-app.vercel.app> adresini ac; sayfa
bir oturum kodu ve QR gosterir. Telefondaki TURLAR ekraninda **QR OKUT**'a
basip o QR'i okut; bundan sonra her tur bitisinde turlar sayfaya kendiliginden
duser (sayfa uc saniyede bir yoklar). Baglanmadan da **CSV PAYLAS** ile dosyayi
disari cikarip sayfaya birakabilirsin.

## Sirada

- Sektor sureleri ve en iyi tura gore canli delta (paket 2 + 11)
- Lastik asinma ve hasar (paket 10), lastik basinci
- ERS deploy modunun ekranda gosterilmesi
- Takim renk temalari, ozellestirilebilir kutu yerlesimi
