# Derin Deniz

Su altında geçen 2D çok oyunculu keşif ve koleksiyon oyunu.
Derine dal, nadir canlıları yakala, oksijenin bitmeden geri dön, üssünü kur.
Godot 4.7 (GDScript).

## Çalıştırma

1. Godot 4.7'yi indir: https://godotengine.org/download (normal sürüm, .NET değil).
2. Godot'ta **Import** → bu klasördeki `project.godot` dosyasını seç → **F5**.
3. Menüde adını yaz, takım rengini seç.
   - **Dünya Kur ve Oyna**: yazdığın adla dünya açılır (yoksa yeni üretilir). Sen sunucu olursun.
   - **Katıl**: aynı ağdaki dünyalar sağdaki listede kendiliğinden görünür, tıkla ve gir.
     Görünmüyorsa kurucunun Esc menüsünde yazan adresi elle yaz.
4. Aynı bilgisayarda iki oyuncu denemek için Godot'ta *Debug → Customize Run Instances*
   ile 2 kopya çalıştır.

## Arkadaşınla oynamak (bağlanamıyorsanız buraya bakın)

**Aynı evde / aynı Wi-Fi'de:** Biri "Dünya Kur ve Oyna" der. Windows Güvenlik Duvarı sorarsa
**İzin ver** (özel ve ortak ağ ikisini de işaretle). Diğerinin menüsünde dünya sağdaki listede
kendiliğinden çıkar. Telefon ile bilgisayar da böyle birlikte oynar.

**Farklı evlerde:** İnternet üzerinden doğrudan bağlanmak için kurucunun modeminde port açık
olmalı. Oyun bunu UPnP ile **kendisi açmayı dener**; Esc menüsünde sonucunu ve internet
adresini yazar. Türkiye'de birçok internet sağlayıcısı ortak IP (CGNAT) kullandığı için bu
çoğu zaman yetmez. En kolay ve kesin yol:

1. İkiniz de **Radmin VPN**'i kurun (ücretsiz, radmin-vpn.com).
2. Biriniz "Ağ oluştur" deyip bir ağ adı ve şifre belirlesin, diğeri "Mevcut ağa katıl" ile girsin.
3. Kurucu oyunda "Dünya Kur ve Oyna" desin. Diğerinin menüsünde dünya listede görünür.
   Görünmezse kurucunun Radmin'de yazan `26.x.x.x` adresini elle yazın.

Bağlanılamazsa oyun 8 saniye sonra nedenlerini sıralayan bir mesaj gösterir.
İki tarafın oyun sürümü farklıysa bağlanırken bunu açıkça söyler; ikiniz de aynı sürümü kullanın.

## Android

`DerinDeniz.apk` dosyasını telefona at ve aç. "Bilinmeyen kaynaklardan yüklemeye izin ver"
sorulursa izin ver. Dokunmatik kontroller telefonda otomatik açılır:
sol altta joystick, sağ altta **KIR / KOY** modu (dokununca değişir), sağda Üretim,
Ansiklopedi, Sohbet ve Menü düğmeleri. Dünyaya dokun: Kır modunda basılı tut = kır,
Koy modunda dokun = seçili bloğu koy, parıldayan canlıya dokun = yakala.

PC ile telefon aynı Wi-Fi'deyse birlikte oynayabilirsiniz (biri kurar, diğeri IP ile katılır).

APK `android/derindeniz.keystore` anahtarıyla imzalı (şifre: `derindeniz123`). **Bu dosyayı
sakla:** güncellemeleri aynı anahtarla imzalamazsan telefon eski sürümün üstüne kurmaz.
Google Play'e çıkarken yeni ve gizli bir anahtar oluştur.

## Kontroller

| Tuş | İş |
|---|---|
| W A S D / ok tuşları / Boşluk | Yüz |
| Sol tık (basılı tut) | Bloğu kır |
| Sol tık (canlının üstünde) | Ağ ile yakala |
| Sağ tık | Seçili bloğu koy |
| 1–9 / fare tekerleği / hotbar'a tıkla | Hotbar yuvası seç |
| Sağ tık (akvaryumun üstünde) | Akvaryuma canlı koy |
| E (ya da C, I, Tab) | Envanter ve üretim |
| K | Deniz Ansiklopedisi |
| M | Harita |
| T | Oyuncular ve takas |
| Enter | Sohbet |
| Esc | Paneli kapat / menüye dön |

## Oyun

### Görevler
Sağ üstteki görev kartı ne yapacağını söyler. 15 adımlık zincir oyunu öğretir (ilk dalış,
yosun, tahta, ağ, ilk yakalama, hazine, istasyon, katmanlar, ansiklopedi, akvaryum, ekipman,
Fener Balığı, Uçurum, Altın Fener Balığı). Bitince sürekli yeni rastgele görevler gelir.
Her görev inci kazandırır.

### Envanter ve üretim (Minecraft tarzı, E)
- 36 yuvalı envanter: altta 9'luk hotbar (1-9 ile seçilir), üstte 27 yuvalı çanta. Eşyalar 99'a
  kadar yığılır (Ağ yığılmaz).
- **Sol tık:** yığını al / bırak / değiştir. **Sağ tık:** yarısını al / tek tek bırak.
  **Shift + tık:** hotbar ile çanta arasında hızlı taşı; sonuç yuvasında: yapabildiğin kadar üret.
- **3x3 üretim ızgarası:** malzemeleri desene göre diz, sağdaki sonuç yuvasından al. Desen
  ızgaranın herhangi bir yerinde olabilir, yatay aynası da olur. Pencereyi kapatınca ızgarada
  kalanlar envantere döner.
- **Tarif kitabı:** sağdaki listede her tarifin deseni görünür. "Diz" düğmesi malzemeleri
  envanterden alıp ızgaraya kendisi dizer.
- **Çöp yuvası:** imleçteki yığını siler.
- Telefonda sağ tık ve Shift yok: pencerede "Tek tek koy" ve "Hızlı taşı" anahtarlarını kullan.

Tarifler (S kum, R kaya, C mercan, K yosun, G cam, P inci, A uçurum taşı, T tahta, L fener, . boş):

| Sonuç | Desen |
|---|---|
| 2 Cam | `SSS` |
| 4 Deniz Tuğlası | `RR / RR` |
| 2 Batık Tahta | `K / K / K` (dikine) |
| Ağ | `.KK / .KK / T..` |
| Deniz Feneri | `CPC` |
| Oksijen İstasyonu | `GPG / GPG / KPK` |
| 2 Işıl Mantar | `A / K` |
| Akvaryum | `G.G / GSG` |
| Hızlı Palet (+%20 hız, 2 seviye) | `KPK / R.R / RPR` |
| Güçlü Fener (+%35 ışık, 2 seviye) | `LGL / P.P` |
| Büyük Fileye (+2 yer, 2 seviye) | `KPK / K.K / KPK` |
| Büyük Tüp (+30 sn oksijen, 3 seviye) | `PAP / A.A / PAP` |

### Ayarlar (Esc > Ayarlar)
Üç sekme:
- **Görüntü:** kalite ön ayarı (Düşük / Orta / Yüksek / Ultra / Özel), kare hızı sınırı
  (30-144 ya da sınırsız), VSync, pencere / tam ekran / kenarlıksız, FPS göstergesi. Ayrıntılar:
  ışık sayısı, parçacıklar, ışık huzmeleri, deniz karı, canlı yoğunluğu, kenar gölgesi,
  kamera yakınlığı ve arayüz boyutu. Ayrıntılardan birini değiştirince ön ayar "Özel" olur.
  Zayıf bilgisayar ya da telefonda "Düşük" seç; telefonda varsayılan "Orta"dır.
- **Ses:** ana ses, efekt, müzik, ortam.
- **Oyun:** dokunmatik kontroller (Otomatik / Açık / Kapalı), oyuncu adları, konuşma
  balonları, mini harita, titreşim, tuş listesi.
"Varsayılan" düğmesi her şeyi ilk haline getirir.

### Takas (T)
T'ye bas (telefonda "Oyuncular"), oyuncunun yanındaki "Takas" düğmesine tıkla. Karşı taraf
kabul edince takas penceresi açılır: envanterinden eşyaya tıkla, teklife girsin (sol tık yığın,
sağ tık / "Tek tek ekle" bir adet). İkiniz de "Onayla"ya basınca değiş tokuş olur.
- Teklif değişirse iki onay da sıfırlanır; son anda eşya değiştirme hilesi yapılamaz.
- Eşyalar teklif sırasında envanterden çıkmaz; sunucu son anda yeniden kontrol eder. Eşya
  eksikse ya da birinin envanterinde yer yoksa hiçbir şey değişmez.
- Yakaladığın canlılar dahil envanterdeki her şey takas edilebilir. Ekipman seviyeleri edilemez.

### Harita (M)
Gezdiğin yerler haritada açılır (keşif sisi). Katman sınırları ve oyuncular görünür; sağ
üstte mini harita var. Keşif, dünya ve oyuncu adına göre kaydedilir.

### Keşif ve koleksiyon (ana döngü)
- **Ağ** üret (4 Yosun + 2 Batık Tahta). Parıldayan canlıların üstüne gelip sol tıkla.
- Yakaladıkların **fileyende** durur (en fazla 5). Yüzeye ya da bir **oksijen istasyonunun**
  yanına dönünce koleksiyonuna geçer. **Oksijenin biterse fileyendekiler kaçar.**
  Her dalış bir karar: biraz daha derine mi, geri mi?
- **Deniz Ansiklopedisi (K):** 24 tür, her biri kendi derinliğinde ve nadirliğinde
  (Yaygın, Nadir, Çok Nadir, Efsanevi). Bir türü ilk kez koleksiyonuna kattığında inci ödülü
  alırsın; nadir türler çok daha fazla verir.
- **Akvaryum:** Üssüne akvaryum koy, sağ tıklayıp koleksiyonundan bir canlı yerleştir,
  içinde yüzsün. Akvaryumu kırarsan canlı koleksiyonuna geri döner.
- **Elektrikli yılanbalığı:** 120 m'den derinde. Yaklaşınca üstüne gelir, çarparsa
  12 saniyelik oksijenini sömürür ve seni iter. Yakalanabilir de (cesaretin varsa).
- **Mavi köpekbalığı:** Alacakaranlıkta dolaşır, yakına gelirsen saldırır: ısırığı 16 saniyelik
  oksijen götürür.
- **Derinlik rekorları:** Her katmana ilk ulaşışında inci ödülü (60 m, 130 m, 200 m, 240 m).

### Türler
Tüm canlılar `tools/art_creatures.py` ile anatomiye dayalı çizildi (gövde profili, sırt
koyu / karın açık gölgelendirme, pul dokusu, yan çizgi, türüne göre kuyruk ve yüzgeçler).

| Tür | Derinlik | Nadirlik |
|---|---|---|
| Sarı Cerrah, Palyaço Balığı, Lüfer, Çipura | yüzeye yakın | Yaygın |
| Mavi Kromis, Gümüş Sardalya, Barbunya, Pembe Denizanası | orta | Yaygın |
| Denizatı, Deniz Kaplumbağası, Balon Balığı (şişer), Mavi Yengeç, Vatoz | sığ-orta | Nadir |
| Ahtapot, Işıklı Denizanası, Orfoz, Kılıç Balığı | orta-derin | Nadir / Çok Nadir |
| Fener Balığı, Hayalet Kalamar, Ay Balığı | derin | Çok Nadir |
| Altın Fener Balığı, Dev Kalamar | uçurum | Efsanevi |
| Elektrikli Yılanbalığı, Mavi Köpekbalığı | orta-derin | Tehlikeli |

### Dünya

- **Katmanlar:** Güneşli Katman → Alacakaranlık → Gece Katmanı → Uçurum. Derine indikçe
  karanlık artar, oksijen daha hızlı biter.
- **Oksijen:** Yüzeyde dolar. **Oksijen İstasyonu** koyarsan çevresindeki 3 hücrede de dolar,
  böylece derinde üs kurabilirsin. **Büyük Tüp** üreterek oksijeni kalıcı artırırsın (3 seviye).
- **Hazine:** Batık gemilerde ve mağara tabanlarında hazine sandıkları var. Derindekiler daha
  çok inci verir. İnci damarlarını kırınca da inci çıkar.
- **Dünya boyutu:** 480 x 320 hücre. 7 batık gemi, mağaralarda ~60 hazine sandığı.
  Katmanlar: 0-60 m Güneşli, 60-140 m Alacakaranlık, 140-230 m Gece, 230 m altı Uçurum.
  Önceki küçük dünyalar açılırken `.eski` uzantısıyla yedeklenir; oyuncuların envanteri,
  koleksiyonu ve görevleri yeni büyük dünyaya taşınır.

- **Balık sürüleri** süs amaçlıdır (dalgıçtan kaçarlar). Yakalanabilir canlılar parıldar ve
  sunucu tarafından yönetilir; herkes aynı canlıları görür.
- **Kayıt:** Dünya her dakika ve çıkışta otomatik kaydedilir. Oyuncuların envanteri,
  koleksiyonu, ansiklopedisi ve rekoru adlarına göre saklanır; aynı adla geri gelen kaldığı
  yerden devam eder. Akvaryumlar da kaydedilir.
  Kayıt yeri (Windows): `%APPDATA%\DerinDeniz\worlds`

## Ağ mimarisi

Sunucu yetkilidir (ENet). İstemci "şu hücreyi kır / şuraya şunu koy / şunu üret / şu mesajı
gönder" diye **istek** yollar; sunucu menzili, hızı, stoğu, tarifi ve çakışmayı kontrol edip
sonucu herkese yayınlar. Envanter sunucuda tutulur. Yeni katılana dünya ve arka duvarlar
sıkıştırılmış olarak gönderilir.

Bilinen sınır: oyuncu hareketi ve oksijen istemcide hesaplanır. Arkadaş oyunları için yeterli,
herkese açık sunucu için sunucu tarafı hareket doğrulaması eklenmeli.

Sunucu, yerel ağdan gelen "dünya var mı?" sorgularına UDP 7778'den cevap verir (menüdeki
liste böyle dolar). Bağlanan istemci sürümünü bildirir; uyuşmazsa sunucu nedenini söyleyip
bağlantıyı keser. Kurucu tarafta UPnP ile UDP 7777 modemde otomatik açılmaya çalışılır.
Envanter tıklamaları istemcide anında gösterilir, sunucu aynı işlemi doğrulayıp kesin durumu yollar.

Sadece sunucu (ekransız): `godot --headless --path . -- --server --port 7777 --world okyanus`

## Görselleri ve sesleri değiştirmek

Tüm görseller `assets/` klasöründe PNG olarak duruyor; herhangi bir piksel çizim programıyla
(Aseprite, LibreSprite, Piskel, hatta Paint) açıp boyayabilirsin. Boyutları koru.

| Dosya | İçerik |
|---|---|
| `tiles.png` | 16x16 karolar. Satır = blok numarası (1 kum, 2 kaya, 3 mercan, 4 yosun, 5 cam, 6 inci damarı, 7 uçurum taşı, 8 taban, 9 fener, 10 oksijen istasyonu, 11 tuğla, 12 tahta, 13 sandık, 14 ışıl mantar, 15 akvaryum). Sütun 0–3: varyantlar ya da animasyon kareleri. Sütun 4: üstünde su olan hali (kum, kaya, uçurum taşı). |
| `diver_base.png` | Dalgıç, 24x24'lük 8 kare (0–3 dik duruş, 4–7 yatay yüzme). Maske, tüp, paletler. |
| `diver_suit.png` | Dalgıç takımı, gri tonlarda. Oyunda oyuncunun rengine boyanır. |
| `creatures/*.png` | Her canlının 4 karelik animasyonu (yan yana). Oyunda yarı boyutta çizilir, yani 2 kat ayrıntılı çizebilirsin. |
| `icons.png` | İnci, Büyük Tüp ve Ağ simgeleri. |
| `sfx/*.wav` | Ses efektleri ve ortam sesi. |

Görseller `tools/generate_assets.py` ile üretildi (Python + Pillow). Bu betiği tekrar
çalıştırırsan **elle yaptığın değişikliklerin üzerine yazar**, önce yedek al.

## Yeni blok eklemek

1. `scripts/blocks.gd`: sabit ekle, `COUNT`'u artır, `DEFS`'e satır ekle.
2. `assets/tiles.png`: o satıra karoyu çiz (gerekirse resmi aşağı doğru büyüt).
3. Koyulabilsin istiyorsan `PLACEABLE` listesine, üretilsin istiyorsan `RECIPES`'e ekle.

## Dosyalar

    scripts/main.gd            menü, bağlantı, komut satırı
    scripts/menu_background.gd menünün hareketli arka planı
    scripts/world.gd           dünya, kırma/koyma, üretim, sohbet, hazine, kayıt (sunucu mantığı)
    scripts/world_gen.gd       dünya üretimi: katmanlar, mağaralar, resif, batık gemiler
    scripts/blocks.gd          blok/eşya türleri, tarifler
    scripts/player.gd          dalgıç: yüzme, animasyon, oksijen, girdi
    scripts/hud.gd             oksijen, derinlik çubuğu, hotbar, sohbet, üretim paneli
    scripts/ambience.gd        gökyüzü, su yüzeyi, ışık huzmeleri, deniz karı
    scripts/fauna.gd           süs balık sürüleri
    scripts/species.gd         yakalanabilir türler: derinlik, nadirlik, ödül  <- yeni tür buraya
    scripts/wildlife.gd        sunucuda simüle edilen yakalanabilir canlılar
    scripts/sfx.gd             sesler
    scripts/save_store.gd      dünya kayıtları
    scripts/tile_atlas.gd      karo seti ve simgeler
    scripts/ui_theme.gd        arayüz teması
    scripts/inventory.gd       envanter mantığı: yuvalar, tıklama kuralları, şekilli tarifler
    scripts/inventory_window.gd envanter ve üretim penceresi, tarif kitabı
    scripts/slot_grid.gd       envanter yuva ızgarası
    scripts/net_tools.gd       IP adresleri, sürüm
    scripts/lan_discovery.gd   yerel ağda dünya bulma
    scripts/upnp_helper.gd     modemde otomatik port açma
    scripts/quests.gd          görev zinciri ve rastgele görevler
    scripts/settings.gd        ayarlar ve ses kanalları
    scripts/settings_panel.gd  ayarlar penceresi
    scripts/touch_controls.gd  telefon kontrolleri
    scripts/trade.gd           takas (sunucu yetkili)
    scripts/trade_window.gd    takas penceresi
    scripts/world_map.gd       harita resmi ve keşif sisi
    scripts/map_view.gd        tam harita ve mini harita çizimi
    tools/art_creatures.py     gerçekçi canlı çizim motoru
    export_presets.cfg         Windows ve Android dışa aktarma ayarları
    tests/                     otomatik testler (tests/run_all.sh)
    tools/                     görsel/ses üretim betikleri

## Testler

    GODOT=/yol/godot ./tests/run_all.sh

Fare girdisini taklit eden oynanış testi (kırma, koyma, üretim, hazine, oksijen, sohbet,
kayıt) ve sunucu + 3 istemcili ağ testi (hile denemeleri, menzil, hız sınırı, sohbet,
geç katılma) ve iki istemcili takas testi (ret, kabul, onay sıfırlama, hile, değiş tokuş)
çalışır.

## Yeni tür eklemek

1. `assets/` içine sprite sayfasını koy (kareler yan yana).
2. `scripts/species.gd` içindeki `LIST`'e bir satır ekle: id (sıradaki sayı), ad, doku adı,
   kare boyutu, kare sayısı, derinlik aralığı, ağırlık, nadirlik, ödül, hız, hareket tarzı
   (`swim`, `hover`, `jelly`, `eel`, `bottom`, `glide`, `crawl`, `puffer`, `shark`, `drift`).
   Saldıran tür için `"attack": "shock"` ya da `"bite"`.

## Sıradaki fikirler

Yapılabilir denizaltı, haftalık değişen derin bölgeler (seferler), ekip görevleri,
Steam entegrasyonu (GodotSteam ile davetle bağlanma), sunucu tarafı hareket doğrulaması,
haritaya işaret koyma.
