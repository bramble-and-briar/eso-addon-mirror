-- ARC_NetGraph Türkçe Yerelleştirme
-- ESOUI En İyi Uygulamalarına (Best Practices) Uygun Olarak Hazırlanmıştır
-- Default dil İngilizcedir; bu dosya yalnızca oyun dili Türkçe ise veya ayarlardan seçilirse uygulanır.

local strings = {
    -- Ayarlar & Panel
    SI_ARC_NG_TITLE                 = "ARC NetGraph",
    SI_ARC_NG_DESC                  = "Ping, Jitter (gecikme dalgalanması), min/max gecikme sıçramaları ve FPS değerlerini canlı gösteren gerçek zamanlı ağ telemetri arayüzü.",
    SI_ARC_NG_OPT_LANGUAGE          = "Dil / Language",
    SI_ARC_NG_OPT_LANGUAGE_TIP      = "Eklenti arayüz dilini seçin (Varsayılan: İngilizce). Değişiklik için /reloadui gerekir.",

    -- Genel Ayarlar
    SI_ARC_NG_HDR_GENERAL           = "Genel & Performans Ayarları",
    SI_ARC_NG_OPT_ENABLE            = "ARC NetGraph'ı Etkinleştir",
    SI_ARC_NG_OPT_ENABLE_TIP        = "Canlı ağ göstergesini açar veya kapatır.",
    SI_ARC_NG_OPT_UPDATE_INTERVAL   = "Güncelleme Aralığı (ms)",
    SI_ARC_NG_OPT_UPDATE_INTERVAL_TIP = "Ağ verilerinin ne kadar sıklıkla ölçülüp ekranda yenileneceğini belirler (Varsayılan: 500ms).",
    SI_ARC_NG_OPT_LAYOUT_MODE       = "Görünüm Düzeni",
    SI_ARC_NG_OPT_LAYOUT_MODE_TIP   = "Tek satır kompakt şerit, ayrıntılı kart veya minimalist rozet görünümlerinden birini seçin.",
    SI_ARC_NG_LAYOUT_COMPACT        = "Kompakt Şerit (Tek Satır)",
    SI_ARC_NG_LAYOUT_DETAILED       = "Ayrıntılı Kart (Tablo)",
    SI_ARC_NG_LAYOUT_MINIMAL        = "Minimalist (Rozet)",

    -- Metrikler
    SI_ARC_NG_HDR_METRICS           = "Görüntülenecek Metrikler",
    SI_ARC_NG_OPT_SHOW_PING         = "Ping (Gecikme) Göster",
    SI_ARC_NG_OPT_SHOW_PING_TIP     = "Megaserver sunucusuna olan anlık gidiş-dönüş süresini milisaniye cinsinden gösterir.",
    SI_ARC_NG_OPT_SHOW_JITTER       = "Jitter (Dalgalanma) Göster",
    SI_ARC_NG_OPT_SHOW_JITTER_TIP   = "Paket varış sürelerindeki sapmayı ve bağlantı kararsızlığını ölçer (RFC 3550 standart varyansı).",
    SI_ARC_NG_OPT_SHOW_FPS          = "Kare Hızı (FPS) Göster",
    SI_ARC_NG_OPT_SHOW_FPS_TIP      = "Anlık ekran kare yenileme hızını gösterir.",
    SI_ARC_NG_OPT_SHOW_MINMAX       = "Min / Max Sıçrama (Spike) Göster",
    SI_ARC_NG_OPT_SHOW_MINMAX_TIP   = "Son ölçüm aralığında kaydedilen en düşük ve en yüksek ping değerlerini gösterir.",
    SI_ARC_NG_OPT_SHOW_SERVER       = "Sunucu Adını Göster",
    SI_ARC_NG_OPT_SHOW_SERVER_TIP   = "Bağlı olunan megaserver adını (EU / NA / PTS) gösterir.",

    -- Görünüm & Konum
    SI_ARC_NG_HDR_VISUAL            = "Görsel Tasarım & Konum",
    SI_ARC_NG_OPT_LOCK              = "Pencere Konumunu Kilitle",
    SI_ARC_NG_OPT_LOCK_TIP          = "Pencereyi kilitler ve fare tıklamalarını arkaya geçirir (tıklanamaz/kaydırılamaz mod).",
    SI_ARC_NG_OPT_SCALE             = "Arayüz Boyutu / Ölçeği",
    SI_ARC_NG_OPT_SCALE_TIP         = "NetGraph arayüzünün genel boyutunu ayarlar (%50 - %150).",
    SI_ARC_NG_OPT_OPACITY           = "Arka Plan Saydamlığı",
    SI_ARC_NG_OPT_OPACITY_TIP       = "Arka planın koyuluğunu ayarlar (%0 = tamamen saydam / çerçevesiz).",
    SI_ARC_NG_OPT_COLOR_CODING      = "Dinamik Ağ Sağlığı Renklendirmesi",
    SI_ARC_NG_OPT_COLOR_CODING_TIP  = "Ping ve Jitter durumuna göre renkleri otomatik değiştirir (Yeşil = Harika, Sarı = Normal, Kırmızı = Dalgalı/Yüksek).",

    -- Arayüz İçi Etiketler
    SI_ARC_NG_LBL_FPS               = "FPS",
    SI_ARC_NG_LBL_PING              = "PING",
    SI_ARC_NG_LBL_JITTER            = "JITTER",
    SI_ARC_NG_LBL_SPIKES            = "SPIKE",
    SI_ARC_NG_LBL_SERVER            = "SUNUCU",

    -- Bağış Bölümü
    SI_ARC_NG_HEADER_DONATE         = "Geliştiriciye Destek Olun (@arcsinan)",
    SI_ARC_NG_DONATE_DESC           = "ARC NetGraph eklentisini beğendiyseniz, oyun içi altın bağışları çalışmalarımızı desteklemek için büyük bir motivasyondur! Butona tıkladığınızda oyun içi posta penceresi @arcsinan adına otomatik açılır.",
    SI_ARC_NG_BTN_DONATE_5K         = "5.000 Altın Gönder",
    SI_ARC_NG_BTN_DONATE_5K_TT      = "@arcsinan kullanıcısına 5.000 Altın gönderir.",
    SI_ARC_NG_BTN_DONATE_25K        = "25.000 Altın Gönder",
    SI_ARC_NG_BTN_DONATE_25K_TT     = "@arcsinan kullanıcısına 25.000 Altın gönderir.",
    SI_ARC_NG_BTN_DONATE_100K       = "100.000 Altın Gönder",
    SI_ARC_NG_BTN_DONATE_100K_TT    = "@arcsinan kullanıcısına 100.000 Altın gönderir.",
    SI_ARC_NG_BTN_DONATE_CUSTOM     = "Özel Miktar / Geri Bildirim",
    SI_ARC_NG_BTN_DONATE_CUSTOM_TT  = "Özel miktarda bağış veya teşekkür mesajı yazabileceğiniz posta penceresini açar.",
    SI_ARC_NG_CHAT_SERVER_WARN      = "|cFF9900[ARC NetGraph]|r Uyarı: '%s' sunucusundasınız. Oyun içi postalar yalnızca EU Megaserver üzerinden teslim edilebilir.",
    SI_ARC_NG_MAIL_BODY             = "ARC NetGraph eklentisini severek kullanıyorum! Emeğiniz ve katkılarınız için teşekkür ederim.",
}

ARC_NetGraph = ARC_NetGraph or {}

function ARC_NetGraph.ApplyTurkishStrings()
    for stringId, stringValue in pairs(strings) do
        SafeAddString(_G[stringId], stringValue, 2)
    end
end

if GetCVar("Language.2") == "tr" then
    ARC_NetGraph.ApplyTurkishStrings()
end
