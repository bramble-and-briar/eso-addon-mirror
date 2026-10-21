-- ARC_CustomFonts Türkçe Yerelleştirme
-- ESOUI En İyi Uygulamalarına (Best Practices) Uygun Olarak Hazırlanmıştır
-- Default dil İngilizcedir; bu dosya yalnızca oyun dili Türkçe ise veya ayarlardan seçilirse uygulanır.

local strings = {
    -- Ayarlar Paneli
    SI_ARC_CF_TITLE                 = "ARC Custom Fonts",
    SI_ARC_CF_DESC                  = "ESO için yüksek kaliteli, tamamen telifsiz ve açık kaynaklı (SIL OFL) yazı tipleri. Otomatik olarak LibMediaProvider (LMP) kütüphanesine kaydedilir ve oyun içi arayüze uygulanabilir.",
    SI_ARC_CF_OPT_LANGUAGE          = "Dil / Language",
    SI_ARC_CF_OPT_LANGUAGE_TIP      = "Eklenti arayüz dilini seçin (Varsayılan: İngilizce). Değişiklik için /reloadui gerekir.",
    SI_ARC_CF_HEADER_LMP            = "LibMediaProvider (LMP) Durumu",
    SI_ARC_CF_LMP_REGISTERED        = "11 özel yazı tipinin tümü LibMediaProvider'a başarıyla kaydedildi. Bandit UI, pChat, AUI vb. tüm eklentilerden seçilebilir.",
    SI_ARC_CF_LMP_NOT_FOUND         = "LibMediaProvider-1.0 kütüphanesi bulunamadı. Yazı tiplerini diğer eklentilerde kullanmak için Minion üzerinden kurabilirsiniz.",

    -- Genel Yazı Tipi Değiştirme
    SI_ARC_CF_HEADER_OVERRIDES      = "Genel Oyun İçi Yazı Tipi Değiştirme",
    SI_ARC_CF_OVERRIDES_DESC        = "İsteğe bağlı olarak ESO'nun varsayılan arayüz yazı tiplerini seçtiğiniz özel yazı tipleriyle değiştirir. Tam etki için /reloadui gerekir.",

    SI_ARC_CF_ENABLE_OVERRIDES      = "Genel Değiştirmeyi Etkinleştir",
    SI_ARC_CF_ENABLE_OVERRIDES_TIP  = "Etkinleştirildiğinde, aşağıdaki seçilen yazı tipleri varsayılan oyun yazı tiplerinin yerini alır.",

    SI_ARC_CF_CHAT_FONT             = "Sohbet (Chat) Yazı Tipi",
    SI_ARC_CF_CHAT_FONT_TIP         = "Sohbet pencerelerinde ve metin girişinde kullanılan yazı tipini seçin.",

    SI_ARC_CF_UI_FONT               = "Genel Arayüz Yazı Tipi",
    SI_ARC_CF_UI_FONT_TIP           = "Menüler, düğmeler, etiketler ve envanter listesinde kullanılan genel yazı tipini seçin.",

    SI_ARC_CF_HEADER_FONT           = "Başlıklar & İsimler Yazı Tipi",
    SI_ARC_CF_HEADER_FONT_TIP       = "Pencere başlıkları, bölüm başlıkları ve karakter isimlerinde kullanılan yazı tipini seçin.",

    SI_ARC_CF_BOOK_FONT             = "Kitaplar & Parşömenler Yazı Tipi",
    SI_ARC_CF_BOOK_FONT_TIP         = "Tamriel'deki kitapları, notları ve parşömenleri okurken kullanılan yazı tipini seçin.",

    SI_ARC_CF_COMBAT_FONT           = "Savaş Sayıları (Combat/SCT) Yazı Tipi",
    SI_ARC_CF_COMBAT_FONT_TIP       = "Hasar, iyileştirme sayıları ve kayan savaş metinlerinde kullanılan yazı tipini seçin.",

    SI_ARC_CF_RELOAD_BTN            = "Uygula & Arayüzü Yenile (Reload UI)",
    SI_ARC_CF_RELOAD_BTN_TIP        = "Yazı tipi değişikliklerini uygulamak için oyun arayüzünü (ReloadUI) yeniden yükler.",

    -- Yazı Tipi Seçenekleri
    SI_ARC_CF_FONT_DEFAULT          = "Varsayılan (Oyun Varsayılanı)",

    -- Destek & Bağış
    SI_ARC_CF_HEADER_DONATE         = "Geliştiriciye Destek (@arcsinan)",
    SI_ARC_CF_DONATE_DESC           = "ARC Custom Fonts tamamen ücretsiz ve açık kaynaklıdır. Tamriel'de bu yazı tiplerini kullanmaktan keyif alıyorsanız, oyun içinden @arcsinan (PC/EU) hesabına altın veya teşekkür mesajı göndererek destek olabilirsiniz!",
    SI_ARC_CF_BTN_DONATE_5K         = "5.000 Altın Gönder",
    SI_ARC_CF_BTN_DONATE_5K_TT      = "@arcsinan hesabına 5.000 Altın eklenmiş posta ekranını açar.",
    SI_ARC_CF_BTN_DONATE_25K        = "25.000 Altın Gönder",
    SI_ARC_CF_BTN_DONATE_25K_TT     = "@arcsinan hesabına 25.000 Altın eklenmiş posta ekranını açar.",
    SI_ARC_CF_BTN_DONATE_100K       = "100.000 Altın Gönder",
    SI_ARC_CF_BTN_DONATE_100K_TT    = "@arcsinan hesabına 100.000 Altın eklenmiş posta ekranını açar. Çok teşekkürler!",
    SI_ARC_CF_BTN_DONATE_CUSTOM     = "Özel Miktar / Geri Bildirim Mesajı",
    SI_ARC_CF_BTN_DONATE_CUSTOM_TT  = "@arcsinan hesabına istediğiniz miktarda altın veya mesaj yazabileceğiniz posta ekranını açar.",
    SI_ARC_CF_MAIL_BODY             = "ARC Custom Fonts eklentisi için teşekkürler!",
    SI_ARC_CF_CHAT_SERVER_WARN      = "|cFFD700[ARC Custom Fonts]|r Not: @arcsinan öncelikli olarak PC/EU sunucusunda oynamaktadır (mevcut sunucu: %s).",
}

ARC_CustomFonts = ARC_CustomFonts or {}
ARC_CustomFonts.trStrings = strings

function ARC_CustomFonts.ApplyTurkishStrings()
    for stringId, stringValue in pairs(strings) do
        local id = _G[stringId] or stringId
        if id and SafeAddString then
            SafeAddString(id, stringValue, 2)
        end
    end
end

-- Sadece istemci dili Türkçe ise otomatik olarak uygula
local clientLang = GetCVar and GetCVar("language.2")
if clientLang and string.lower(clientLang) == "tr" then
    ARC_CustomFonts.ApplyTurkishStrings()
end
