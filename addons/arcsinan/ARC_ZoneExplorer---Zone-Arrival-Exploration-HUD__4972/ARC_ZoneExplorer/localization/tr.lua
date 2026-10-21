-- ARC_ZoneExplorer Türkçe Yerelleştirme
-- ESOUI En İyi Uygulamalarına (Best Practices) Uygun Olarak Hazırlanmıştır
-- Default dil İngilizcedir; bu dosya yalnızca oyun dili Türkçe ise veya ayarlardan seçilirse uygulanır.

local strings = {
    -- Ayarlar & Panel
    SI_ARC_ZE_TITLE                 = "ARC Zone Explorer",
    SI_ARC_ZE_DESC                  = "Yeni bir bölgeye veya şehre ışınlandığınızda şık bir keşif ve durum paneli görüntüler. Bölge rehberi ilerlemesini, set koleksiyonlarını (stickerbook) ve günlük durumları gösterir.",
    SI_ARC_ZE_OPT_LANGUAGE          = "Dil / Language",
    SI_ARC_ZE_OPT_LANGUAGE_TIP      = "Eklenti arayüz dilini seçin (Varsayılan: İngilizce). Değişiklik için /reloadui gerekir.",

    -- Genel Ayarlar
    SI_ARC_ZE_HDR_GENERAL           = "Genel & Görünüm Ayarları",
    SI_ARC_ZE_OPT_ENABLE            = "ARC Zone Explorer'ı Etkinleştir",
    SI_ARC_ZE_OPT_ENABLE_TIP        = "Bölgeye varış bilgi panelini açar/kapatır.",
    SI_ARC_ZE_OPT_AUTO_SHOW         = "Bölgeye Varışta Otomatik Göster",
    SI_ARC_ZE_OPT_AUTO_SHOW_TIP     = "Yeni bir bölgeye ışınlanma veya yükleme ekranı sonrasında paneli otomatik görüntüler.",
    SI_ARC_ZE_OPT_DURATION          = "Görünme Süresi (Saniye)",
    SI_ARC_ZE_OPT_DURATION_TIP      = "Panelin ekranda kaç saniye kalıp kaybolacağını belirler (0 = kapatılana kadar açık kalır).",
    SI_ARC_ZE_OPT_OPACITY           = "Pencere Arka Plan Saydamlığı",
    SI_ARC_ZE_OPT_OPACITY_TIP       = "Panel arka planının saydamlık seviyesini ayarlar.",
    SI_ARC_ZE_OPT_SCALE             = "Arayüz Boyutu / Ölçeği",
    SI_ARC_ZE_OPT_SCALE_TIP         = "Zone Explorer panelinin genel boyut ve ölçeğini ayarlar (%50 - %130).",
    SI_ARC_ZE_OPT_COMPACT           = "Kompakt Mini Mod",
    SI_ARC_ZE_OPT_COMPACT_TIP       = "Ekranda çok daha az yer kaplayan tek sütunlu ve derli toplu bir mini görünüm kullanır.",
    SI_ARC_ZE_OPT_SHOW_SETS         = "Bölge Eşya Setlerini Göster (Stickerbook)",
    SI_ARC_ZE_OPT_SHOW_SETS_TIP     = "Bu bölgede düşen overland set parçalarının toplanma ilerlemesini listeler.",
    SI_ARC_ZE_OPT_HIDE_COMPLETED_SETS = "Tamamlanan Setleri Gizle",
    SI_ARC_ZE_OPT_HIDE_COMPLETED_SETS_TIP = "Stickerbook'ta tüm parçaları toplanmış olan setleri listede göstermez.",
    SI_ARC_ZE_OPT_SHOW_DAILIES      = "Günlük Durumları Göster",
    SI_ARC_ZE_OPT_SHOW_DAILIES_TIP  = "At eğitimi ve günlük zanaat görevleri durumunu gösterir.",
    SI_ARC_ZE_OPT_TRACK_RIDING      = "At Eğitimini Göster",
    SI_ARC_ZE_OPT_TRACK_RIDING_TIP  = "At eğitimi kalan süre veya hazır bildirimini gösterir.",
    SI_ARC_ZE_OPT_TRACK_WRITS       = "Günlük Zanaat Görevlerini Göster",
    SI_ARC_ZE_OPT_TRACK_WRITS_TIP   = "Günlük zanaat (crafting writ) görevleri durumunu gösterir.",

    -- Ayrıntılı Aktivite Filtreleri
    SI_ARC_ZE_OPT_HIDE_COMPLETED    = "Tamamlanan Aktiviteleri Gizle",
    SI_ARC_ZE_OPT_HIDE_COMPLETED_TIP = "Mevcut bölgede %100 tamamlanan aktiviteleri gizleyerek yalnızca eksik hedefleri listeler.",
    SI_ARC_ZE_SUBMENU_ACTIVITIES    = "Aktivite Filtreleri (Bölge Rehberi)",
    SI_ARC_ZE_SUBMENU_ACTIVITIES_DESC = "Panelde hangi keşif hedeflerinin görüntüleneceğini tek tek seçin.",
    SI_ARC_ZE_OPT_TRACK_SKYSHARDS   = "Skyshard'ları Takip Et",
    SI_ARC_ZE_OPT_TRACK_WAYSHRINES  = "Wayshrine'ları Takip Et",
    SI_ARC_ZE_OPT_TRACK_DELVES      = "Delve'leri Takip Et",
    SI_ARC_ZE_OPT_TRACK_DUNGEONS    = "Halka Açık Zindanları Takip Et",
    SI_ARC_ZE_OPT_TRACK_BOSSES      = "Dünya Boss'larını Takip Et",
    SI_ARC_ZE_OPT_TRACK_EVENTS      = "Dünya Olaylarını (Dolmen vb.) Takip Et",
    SI_ARC_ZE_OPT_TRACK_LOCALES     = "Keşif Noktalarını Takip Et",
    SI_ARC_ZE_OPT_TRACK_STORY       = "Bölge Hikaye Görevlerini Takip Et",

    -- HUD UI Etiketleri
    SI_ARC_ZE_HUD_WELCOME           = "HOŞ GELDİNİZ:",
    SI_ARC_ZE_HUD_EXPLORATION       = "Bölge Keşfi",
    SI_ARC_ZE_HUD_SETS              = "Bölge Eşya Setleri",
    SI_ARC_ZE_HUD_DAILIES           = "Günlük Durumlar",

    -- Aktiviteler
    SI_ARC_ZE_ACT_SKYSHARDS         = "Skyshard'lar",
    SI_ARC_ZE_ACT_WAYSHRINES        = "Wayshrine'lar",
    SI_ARC_ZE_ACT_DELVES            = "Delve'ler",
    SI_ARC_ZE_ACT_DUNGEONS          = "Halka Açık Zindanlar",
    SI_ARC_ZE_ACT_BOSSES            = "Dünya Boss'ları",
    SI_ARC_ZE_ACT_EVENTS            = "Dünya Olayları (Dolmen/vb.)",
    SI_ARC_ZE_ACT_LOCALES           = "Keşif Noktaları",
    SI_ARC_ZE_ACT_STORY             = "Bölge Hikaye Görevleri",

    -- Günlükler
    SI_ARC_ZE_RIDING_READY          = "At Eğitimi: Hazır!",
    SI_ARC_ZE_RIDING_COOLDOWN       = "At Eğitimi: %s sonra",
    SI_ARC_ZE_RIDING_MAX            = "At Eğitimi: Tamamlandı (60/60/60)",
    SI_ARC_ZE_WRITS_DONE            = "Günlük Zanaat Görevleri: Tamamlandı",
    SI_ARC_ZE_WRITS_PENDING         = "Günlük Zanaat Görevleri: Bekliyor (%d aktif)",

    -- Destek & Bağış
    SI_ARC_ZE_HEADER_DONATE         = "Geliştiriciye Destek (@arcsinan)",
    SI_ARC_ZE_DONATE_DESC           = "ARC Zone Explorer tamamen ücretsiz ve açık kaynaklıdır. Tamriel'de bu eklentiyi kullanmaktan keyif alıyorsanız, oyun içinden @arcsinan (PC/EU) hesabına altın veya teşekkür mesajı göndererek destek olabilirsiniz!",
    SI_ARC_ZE_BTN_DONATE_5K         = "5.000 Altın Gönder",
    SI_ARC_ZE_BTN_DONATE_5K_TT      = "@arcsinan hesabına 5.000 Altın eklenmiş posta ekranını açar.",
    SI_ARC_ZE_BTN_DONATE_25K        = "25.000 Altın Gönder",
    SI_ARC_ZE_BTN_DONATE_25K_TT     = "@arcsinan hesabına 25.000 Altın eklenmiş posta ekranını açar.",
    SI_ARC_ZE_BTN_DONATE_100K       = "100.000 Altın Gönder",
    SI_ARC_ZE_BTN_DONATE_100K_TT    = "@arcsinan hesabına 100.000 Altın eklenmiş posta ekranını açar. Çok teşekkürler!",
    SI_ARC_ZE_BTN_DONATE_CUSTOM     = "Özel Miktar / Geri Bildirim Mesajı",
    SI_ARC_ZE_BTN_DONATE_CUSTOM_TT  = "@arcsinan hesabına istediğiniz miktarda altın veya mesaj yazabileceğiniz posta ekranını açar.",
    SI_ARC_ZE_MAIL_BODY             = "ARC Zone Explorer eklentisi için teşekkürler!",
    SI_ARC_ZE_CHAT_SERVER_WARN      = "|cFFD700[ARC Zone Explorer]|r Not: @arcsinan öncelikli olarak PC/EU sunucusunda oynamaktadır (mevcut sunucu: %s).",
}

ARC_ZoneExplorer = ARC_ZoneExplorer or {}
ARC_ZoneExplorer.trStrings = strings

function ARC_ZoneExplorer.ApplyTurkishStrings()
    for stringId, stringValue in pairs(strings) do
        local id = _G[stringId] or stringId
        if id and SafeAddString then
            SafeAddString(id, stringValue, 2)
        end
    end
end

local clientLang = GetCVar and GetCVar("language.2")
if clientLang and string.lower(clientLang) == "tr" then
    ARC_ZoneExplorer.ApplyTurkishStrings()
end
