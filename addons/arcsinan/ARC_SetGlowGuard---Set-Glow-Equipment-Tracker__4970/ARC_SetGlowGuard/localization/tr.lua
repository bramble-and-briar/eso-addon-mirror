-- localization/tr.lua
-- Turkish Language Strings for ARC_SetGlowGuard
-- Author: @arcsinan

local trStrings = {
    SI_ARC_SGG_PANEL_TITLE          = "ARC_SetGlowGuard - Set Parlama & Ekipman Takipçisi",
    SI_ARC_SGG_HDR_GENERAL          = "Genel Ayarlar",

    SI_ARC_SGG_OPT_LANGUAGE         = "Dil / Language",
    SI_ARC_SGG_OPT_LANGUAGE_TT      = "Eklenti arayüzü ve bildirim dilini seçin (Varsayılan: İngilizce).",

    SI_ARC_SGG_OPT_ENABLE           = "ARC_SetGlowGuard'ı Etkinleştir",
    SI_ARC_SGG_OPT_ENABLE_TT        = "Ekipman ve çanta üzerindeki parlayan set vurgularını açar/kapatır.",

    SI_ARC_SGG_OPT_AUTO_CHAR        = "Envanter ('I') ile Karakter Ekipman Panelini Göster",
    SI_ARC_SGG_OPT_AUTO_CHAR_TT     = "'I' tuşuna bastığınızda Karakter Ekipman panelini ekranın soluna ekler. Böylece giyili set parçaları ile çantanızdaki eşleşen eşyalar aynı anda parlar!",

    SI_ARC_SGG_OPT_HIGHLIGHT_EQUIP  = "Ekipman Slotlarını Parlat",
    SI_ARC_SGG_OPT_HIGHLIGHT_EQUIP_TT = "Karakter panelinde aynı sete ait giyili eşyalar ortak renklerle parlar.",

    SI_ARC_SGG_OPT_HIGHLIGHT_BAG    = "Çantadaki Eşleşen Parçaları Parlat",
    SI_ARC_SGG_OPT_HIGHLIGHT_BAG_TT = "Çantanızda bulunan ve giydiğiniz setlerle eşleşen eşyalar aynı renkte parlar, yanlışlıkla çıkarılan parçalar anında fark edilir.",

    SI_ARC_SGG_OPT_ROW_BAR          = "Envanter Satırlarında Sol Kenar Çizgisi Göster",
    SI_ARC_SGG_OPT_ROW_BAR_TT       = "Giyili setlerle eşleşen envanter satırlarının sol kenarında renkli şerit çizer.",

    SI_ARC_SGG_OPT_INCOMPLETE       = "Eksik Set Uyarısı Göster (örn. 4/5)",
    SI_ARC_SGG_OPT_INCOMPLETE_TT    = "Giyili bir setin parçaları eksik olduğunda slot üzerinde parça sayısı göstergesi (örn. 4/5 veya 1/2) görüntüler.",

    SI_ARC_SGG_OPT_GLOW_INTENSITY   = "Parlama Şiddeti",
    SI_ARC_SGG_OPT_GLOW_INTENSITY_TT = "Parlama vurgularının parlaklığını ve canlılığını ayarlar.",

    SI_ARC_SGG_OPT_GLOW_STYLE       = "Parlama Stili",
    SI_ARC_SGG_OPT_GLOW_STYLE_TT    = "Parlama kenarlıkları için kullanılacak görsel dokuyu seçin.",

    SI_ARC_SGG_HDR_COLORS           = "Özel Set Renkleri",
    SI_ARC_SGG_DESC_COLORS          = "Giyilen her set, mythic eşyalar ve eksik set uyarıları için atanan parlama renklerini özelleştirin:",

    SI_ARC_SGG_COLOR_SET_1          = "Set 1 Rengi (Birincil)",
    SI_ARC_SGG_COLOR_SET_2          = "Set 2 Rengi (İkincil)",
    SI_ARC_SGG_COLOR_SET_3          = "Set 3 Rengi (Üçüncül)",
    SI_ARC_SGG_COLOR_SET_4          = "Set 4 Rengi (Dördüncül)",
    SI_ARC_SGG_COLOR_SET_5          = "Set 5 Rengi (Beşincil)",
    SI_ARC_SGG_COLOR_SET_6          = "Set 6 Rengi (Altıncıl)",
    SI_ARC_SGG_COLOR_MYTHIC         = "Mythic Eşya Parlama Rengi",
    SI_ARC_SGG_COLOR_WARNING        = "Eksik Set Uyarı Rengi",

    SI_ARC_SGG_BTN_RESET_COLORS     = "Renkleri Varsayılana Sıfırla",
    SI_ARC_SGG_BTN_RESET_COLORS_TT  = "Tüm set ve gösterge renklerini varsayılan renk paletine geri döndürür.",

    SI_ARC_SGG_HDR_DONATE           = "Geliştiriciyi Destekle (@arcsinan)",
    SI_ARC_SGG_DESC_DONATE          = "ARC_SetGlowGuard'dan memnun musunuz? Yanlışlıkla set parçası kaybetmeye veya bozulan bonuslara son!\nGeliştirmeyi desteklemek isterseniz doğrudan @arcsinan hesabına oyun içi altın bağışı gönderebilirsiniz (Yalnızca PC/EU Megaserver).",

    SI_ARC_SGG_BTN_DONATE_5K        = "@arcsinan'a 5.000 Altın Gönder",
    SI_ARC_SGG_BTN_DONATE_5K_TT     = "Alıcısı @arcsinan olarak ayarlanmış ve 5.000 altın eklenmiş oyun içi posta penceresini açar.",

    SI_ARC_SGG_BTN_DONATE_25K       = "@arcsinan'a 25.000 Altın Gönder",
    SI_ARC_SGG_BTN_DONATE_25K_TT    = "Alıcısı @arcsinan olarak ayarlanmış ve 25.000 altın eklenmiş oyun içi posta penceresini açar.",

    SI_ARC_SGG_BTN_DONATE_100K      = "@arcsinan'a 100.000 Altın Gönder",
    SI_ARC_SGG_BTN_DONATE_100K_TT   = "Alıcısı @arcsinan olarak ayarlanmış ve 100.000 altın eklenmiş oyun içi posta penceresini açar.",

    SI_ARC_SGG_BTN_DONATE_CUSTOM    = "@arcsinan'a Posta Aç (Özel Tutar)",
    SI_ARC_SGG_BTN_DONATE_CUSTOM_TT = "İstediğiniz miktarda altın gönderebilmeniz için alıcısı @arcsinan olan posta penceresini açar.",

    SI_ARC_SGG_CHAT_REFRESHED       = "[ARC_SetGlowGuard] Yenilendi! Algılanan aktif set sayısı: %d",
    SI_ARC_SGG_CHAT_COMPLETE        = "(Tam: %d/%d)",
    SI_ARC_SGG_CHAT_INCOMPLETE      = "(Eksik: %d/%d)",
    SI_ARC_SGG_CHAT_SERVER_WARN     = "[ARC_SetGlowGuard] Dikkat: @arcsinan yalnızca PC/EU Megaserver üzerindedir! (Bulunduğunuz sunucu: %s). Gönderilecek postalar başka bir oyuncuya gidebilir veya teslim edilmeyebilir.",
    SI_ARC_SGG_MAIL_BODY            = "ARC_SetGlowGuard için teşekkürler @arcsinan! Eklenti geliştirmelerini desteklemek için biraz altın gönderiyorum.",
}

ARC_SetGlowGuard = ARC_SetGlowGuard or {}
local ASGG = ARC_SetGlowGuard

ASGG.trStrings = trStrings

function ASGG.ApplyTurkishStrings()
    for stringId, stringValue in pairs(trStrings) do
        local id = _G[stringId] or stringId
        if id and SafeAddString then
            SafeAddString(id, stringValue, 2)
        end
    end
end
