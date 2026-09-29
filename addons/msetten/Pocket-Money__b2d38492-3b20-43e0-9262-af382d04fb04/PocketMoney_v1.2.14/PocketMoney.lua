PocketMoney = PocketMoney or {}
PocketMoney.version = "1.2.14" -- Version of the Pocket Money addon
PocketMoney.author = "msetten" -- Author of the Pocket Money addon
PocketMoney.defaults = {
    PocketMoneyGoldValue = 10000, -- Default value for pocket money
    PocketMoneyTelVarValue = 0, -- Default value for Tel Var Stones
    PocketMoneyAPValue = 0, -- Default value for Alliance Points
    PocketMoneyWritVoucherValue = 0, -- Default value for Writ Vouchers
    lastTimeUsed = 0, -- Timestamp of the last time pocket money was used
    bankerCooldownMinutes = 5, -- Default cooldown in minutes (account-wide)
    msgcolor = {
        r = 0,
        g = 1,
        b = 0
    } -- Default message color for chat messages
}
POCKETMONEY_MODE_ACCOUNT_WIDE = 1 -- Account-wide mode
POCKETMONEY_MODE_CHARACTER = 2 -- Character-specific mode
POCKETMONEY_MODE_DISABLED = 3 -- Disabled mode
PocketMoney.characterDefaults = {
    PocketMoneyGoldValue = 10000, -- Character-specific value, overrides account-wide if set
    PocketMoneyTelVarValue = 0, -- Use account-wide setting or Tel Var Stones
    PocketMoneyAPValue = 0, -- Use account-wide setting for Alliance Points
    PocketMoneyWritVoucherValue = 0, -- Use account-wide setting for Writ Vouchers
    lastTimeUsed = 5, -- Timestamp of last banker use for this character
    bankerCooldownMinutes = nil -- Character-specific cooldown in minutes
}
PocketMoney.bankerOpen = false -- Flag to indicate if the banker is open
PocketMoney.DEBUG = false -- Enable debug output

-- Localization strings for Pocket Money addon
local strings = {
  SETTINGS_DISPLAY_NAME = {
    en = "Pocket Money Settings",
    de = "Pocket Money Einstellungen",
    fr = "Paramètres Pocket Money",
    ru = "Настройки Pocket Money",
    ja = "Pocket Money 設定",
    zh = "Pocket Money 设置",
    es = "Configuración de Pocket Money",
    it = "Impostazioni Pocket Money",
    pl = "Ustawienia Pocket Money"
  },
  FORCE_ACCOUNT_WIDE_MSG = {
    en = "Account-wide use has been set for all unconfigured characters.",
    de = "Accountweite Nutzung wurde für alle nicht konfigurierten Charaktere gesetzt.",
    fr = "L'utilisation globale a été définie pour tous les personnages non configurés.",
    ru = "Использование аккаунта установлено для всех неконфигурированных персонажей.",
    ja = "未設定のキャラクターにアカウント全体の使用が設定されました。",
    zh = "已为所有未配置的角色设置为账号全局使用。",
    es = "El uso a nivel de cuenta se ha establecido para todos los personajes no configurados.",
    it = "L'uso a livello account è stato impostato per tutti i personaggi non configurati.",
    pl = "Ustawiono użycie dla całego konta dla wszystkich nie skonfigurowanych postaci."
  },
  FORCE_CHARACTER_ON_MSG = {
    en = "Character use has been set for all unconfigured characters.",
    de = "Charakterspezifische Nutzung wurde für alle nicht konfigurierten Charaktere gesetzt.",
    fr = "L'utilisation par personnage a été définie pour tous les personnages non configurés.",
    ru = "Использование персонажа установлено для всех неконфигурированных персонажей.",
    ja = "未設定のキャラクターにキャラクター設定の使用が設定されました。",
    zh = "已为所有未配置的角色设置为角色使用。",
    es = "El uso por personaje se ha establecido para todos los personajes no configurados.",
    it = "L'uso per personaggio è stato impostato per tutti i personaggi non configurati.",
    pl = "Ustawiono użycie dla postaci dla wszystkich nie skonfigurowanych postaci."
  },
  FORCE_CHARACTER_OFF_MSG = {
    en = "Disable has been set for all unconfigured characters.",
    de = "Deaktivierung wurde für alle nicht konfigurierten Charaktere gesetzt.",
    fr = "La désactivation a été définie pour tous les personnages non configurés.",
    ru = "Отключение установлено для всех неконфигурированных персонажей.",
    ja = "未設定のキャラクターに無効化が設定されました。",
    zh = "已为所有未配置的角色设置为禁用。",
    es = "Desactivar se ha establecido para todos los personajes no configurados.",
    it = "La disattivazione è stata impostata per tutti i personaggi non configurati.",
    pl = "Wyłączono dla wszystkich nie skonfigurowanych postaci."
  },
  FORCE_MODE_HEADER = {
    en = "Force Mode",
    de = "Erzwinge Modus",
    fr = "Mode forcé",
    ru = "Принудительный режим",
    ja = "強制モード",
    zh = "强制模式",
    es = "Modo Forzado",
    it = "Modalità Forzata",
    pl = "Tryb wymuszony"
  },
  FORCE_ACCOUNT_WIDE_BTN = {
    en = "Force Account-Wide",
    de = "Accountweite Nutzung erzwingen",
    fr = "Forcer l'utilisation globale",
    ru = "Принудительно аккаунт-широко",
    ja = "アカウント全体を強制",
    zh = "强制账号全局",
    es = "Forzar a nivel de cuenta",
    it = "Forza a livello account",
    pl = "Wymuś dla całego konta"
  },
  FORCE_CHARACTER_ON_BTN = {
    en = "Force Character Specific",
    de = "Charakterspezifische Nutzung erzwingen",
    fr = "Forcer l'utilisation par personnage",
    ru = "Принудительно персонаж-специфично",
    ja = "キャラクター固有を強制",
    zh = "强制角色专用",
    es = "Forzar por personaje",
    it = "Forza per personaggio",
    pl = "Wymuś dla postaci"
  },
  FORCE_CHARACTER_OFF_BTN = {
    en = "Force Disabled",
    de = "Deaktivierung erzwingen",
    fr = "Forcer la désactivation",
    ru = "Принудительно отключить",
    ja = "無効化を強制",
    zh = "强制禁用",
    es = "Forzar desactivado",
    it = "Forza disattivato",
    pl = "Wymuś wyłączenie"
  },
  FORCE_MODE_DESCRIPTION = {
    en = "Force how to use Pocket Money for all characters for which you have not yet configured Pocket Money. This will not change the settings of characters for which you already manually changed the mode or where you have made changes using the various sliders.",
    de = "Erzwinge, wie Pocket Money für alle Charaktere verwendet wird, für die du Pocket Money noch nicht konfiguriert hast. Dies ändert nicht die Einstellungen von Charakteren, bei denen du den Modus bereits manuell geändert hast oder bei denen du Änderungen mit den verschiedenen Schiebereglern vorgenommen hast.",
    fr = "Forcer la façon d'utiliser Pocket Money pour tous les personnages pour lesquels vous n'avez pas encore configuré Pocket Money. Cela ne changera pas les paramètres des personnages pour lesquels vous avez déjà modifié le mode manuellement ou utilisé les différents curseurs.",
    ru = "Принудительно установить способ использования Pocket Money для всех персонажей, для которых вы ещё не настроили Pocket Money. Это не изменит настройки персонажей, для которых вы уже вручную изменили режим или внесли изменения с помощью различных ползунков.",
    ja = "まだPocket Moneyを設定していないすべてのキャラクターにPocket Moneyの使用方法を強制します。すでに手動でモードを変更したキャラクターや、さまざまなスライダーで変更を加えたキャラクターの設定は変更されません。",
    zh = "为所有尚未配置Pocket Money的角色强制零钱的使用方式。这不会更改你已经手动更改了模式或通过各种滑块进行了更改的角色的设置。",
    es = "Forzar cómo usar Pocket Money para todos los personajes para los que aún no has configurado Pocket Money. Esto no cambiará la configuración de los personajes para los que ya has cambiado el modo manualmente o has realizado cambios usando los distintos deslizadores.",
    it = "Forza come usare Pocket Money per tutti i personaggi per cui non hai ancora configurato Pocket Money. Questo non cambierà le impostazioni dei personaggi per cui hai già modificato manualmente la modalità o hai apportato modifiche utilizzando i vari cursori.",
    pl = "Wymuś sposób użycia Pocket Money dla wszystkich postaci, dla których nie skonfigurowano Pocket Money. Nie zmieni to ustawień postaci, dla których ręcznie zmieniłeś tryb lub dokonałeś zmian za pomocą różnych suwaków."
  },
  FORCE_BTN_TOOLTIP = {
    en = "This only applies to characters that have not already been configured individually",
    de = "Dies gilt nur für Charaktere, die noch nicht individuell konfiguriert wurden.",
    fr = "Ceci ne s'applique qu'aux personnages qui n'ont pas déjà été configurés individuellement.",
    ru = "Это применяется только к персонажам, которые ещё не были настроены индивидуально.",
    ja = "これは個別に設定されていないキャラクターにのみ適用されます。",
    zh = "这仅适用于尚未单独配置的角色。",
    es = "Esto solo aplica a personajes que no han sido configurados individualmente.",
    it = "Questo si applica solo ai personaggi che non sono già stati configurati individualmente.",
    pl = "Dotyczy tylko postaci, które nie zostały skonfigurowane indywidualnie."
  },
  DISABLE_FOR_CHARACTER = {
    en = "Disable for this Character",
    de = "Für diesen Charakter deaktivieren",
    fr = "Désactiver pour ce personnage",
    ru = "Отключить для этого персонажа",
    ja = "このキャラクターでは無効化",
    zh = "为此角色禁用",
    es = "Desactivar para este personaje",
    it = "Disattiva per questo personaggio",
    pl = "Wyłącz dla tej postaci"
  },
  DEPOSIT_MSG = {
    en = "Deposited %d %s into the bank to reach your pocket money value of %d.",
    de = "%d %s wurden auf die Bank eingezahlt, um deinen Pocket-Money-Wert von %d zu erreichen.",
    fr = "Déposé %d %s à la banque pour atteindre votre valeur Pocket Money de %d.",
    ru = "Внесено %d %s в банк для достижения значения Pocket Money %d.",
    ja = "%d %s を銀行に預けて、ポケットマネー値 %d に到達しました。",
    zh = "已存入 %d %s 到银行以达到你的零钱目标 %d。",
    es = "Depositados %d %s en el banco para alcanzar tu valor de Pocket Money de %d.",
    it = "Depositati %d %s in banca per raggiungere il valore di Pocket Money di %d.",
    pl = "Wpłacono %d %s do banku, aby osiągnąć wartość Pocket Money %d."
  },
  WITHDRAW_MSG = {
    en = "Withdrew %d %s from the bank to reach your pocket money value of %d.",
    de = "%d %s wurden von der Bank abgehoben, um deinen Pocket-Money-Wert von %d zu erreichen.",
    fr = "Retiré %d %s de la banque pour atteindre votre valeur Pocket Money de %d.",
    ru = "Снято %d %s из банка для достижения значения Pocket Money %d.",
    ja = "%d %s を銀行から引き出して、ポケットマネー値 %d に到達しました。",
    zh = "已从银行取出 %d %s 以达到你的零钱目标 %d。",
    es = "Retirados %d %s del banco para alcanzar tu valor de Pocket Money de %d.",
    it = "Prelevati %d %s dalla banca per raggiungere il valore di Pocket Money di %d.",
    pl = "Wypłacono %d %s z banku, aby osiągnąć wartość Pocket Money %d."
  },
  WITHDRAW_MSG_TOO_LITTLE = {
    en = "Withdrew %d %s from the bank, but there was not enough in the bank to reach your pocket money value of %d.",
    de = "%d %s wurden von der Bank abgehoben, aber es war nicht genug auf der Bank, um deinen Pocket-Money-Wert von %d zu erreichen.",
    fr = "Retiré %d %s de la banque, mais il n'y avait pas assez à la banque pour atteindre votre valeur Pocket Money de %d.",
    ru = "Снято %d %s из банка, но в банке было недостаточно для достижения значения Pocket Money %d.",
    ja = "%d %s を銀行から引き出しましたが、ポケットマネー値 %d に到達するには銀行の残高が足りませんでした。",
    zh = "已从银行取出 %d %s，但银行余额不足以达到你的零钱目标 %d。",
    es = "Retirados %d %s del banco, pero no había suficiente en el banco para alcanzar tu valor de Pocket Money de %d.",
    it = "Prelevati %d %s dalla banca, ma non c'era abbastanza in banca per raggiungere il valore di Pocket Money di %d.",
    pl = "Wypłacono %d %s z banku, ale nie było wystarczająco dużo, aby osiągnąć wartość Pocket Money %d."
  },
  COOLDOWN_MSG = {
    en = "Pocket money transfer is on cooldown for %d more minute(s).",
    de = "Pocket Money Überweisung ist für weitere %d Minute(n) auf Abklingzeit.",
    fr = "Le transfert Pocket Money est en recharge pour encore %d minute(s).",
    ru = "Перевод Pocket Money на перезарядке ещё %d минута(ы).",
    ja = "ポケットマネー転送はあと %d 分間クールダウン中です。",
    zh = "零钱转账还需冷却 %d 分钟。",
    es = "La transferencia de Pocket Money está en enfriamiento por %d minuto(s) más.",
    it = "Il trasferimento di Pocket Money è in raffreddamento per altri %d minuto/i.",
    pl = "Transfer Pocket Money jest w trakcie odnowienia przez kolejne %d minut(y)."
  },
  ACCOUNT_HEADER = {
    en = "Account-Wide Settings",
    de = "Accountweite Einstellungen",
    fr = "Paramètres du compte",
    ru = "Настройки аккаунта",
    ja = "アカウント全体の設定",
    zh = "账号全局设置",
    es = "Configuración a nivel de cuenta",
    it = "Impostazioni a livello account",
    pl = "Ustawienia dla całego konta"
  },
  ENABLE_PM = {
    en = "Enable pocket money",
    de = "Pocket Money aktivieren",
    fr = "Activer Pocket Money",
    ru = "Включить Pocket Money",
    ja = "ポケットマネーを有効化",
    zh = "启用零钱功能",
    es = "Habilitar Pocket Money",
    it = "Abilita Pocket Money",
    pl = "Włącz Pocket Money"
  },
  ENABLE_PM_TOOLTIP = {
    en = "Determines if pocket money is used by all your characters. This can be overridden per character,",
    de = "Legt fest, ob Pocket Money für alle Charaktere verwendet wird. Kann pro Charakter überschrieben werden.",
    fr = "Détermine si Pocket Money est utilisé par tous vos personnages. Peut être remplacé par personnage.",
    ru = "Определяет, используется ли Pocket Money для всех персонажей. Можно переопределить для каждого персонажа.",
    ja = "全キャラクターでポケットマネーを使用するかどうかを決定します。キャラクターごとに上書き可能です。",
    zh = "决定是否所有角色都使用零钱，可单独为角色设置覆盖。",
    es = "Determina si Pocket Money se usa por todos tus personajes. Esto puede ser sobrescrito por personaje.",
    it = "Determina se Pocket Money viene utilizzato da tutti i tuoi personaggi. Può essere sovrascritto per personaggio.",
    pl = "Określa, czy Pocket Money jest używane przez wszystkie postacie. Można nadpisać dla każdej postaci."
  },
  MSG_COLOR = {
    en = "Message Color",
    de = "Nachrichtenfarbe",
    fr = "Couleur du message",
    ru = "Цвет сообщения",
    ja = "メッセージの色",
    zh = "消息颜色",
    es = "Color del mensaje",
    it = "Colore del messaggio",
    pl = "Kolor wiadomości"
  },
  MSG_COLOR_TOOLTIP = {
    en = "Set the color for pocket money messages in chat.",
    de = "Farbe für Pocket-Money-Nachrichten im Chat festlegen.",
    fr = "Définir la couleur des messages Pocket Money dans le chat.",
    ru = "Установить цвет сообщений Pocket Money в чате.",
    ja = "チャットで表示するポケットマネーのメッセージ色を設定します。",
    zh = "设置零钱消息在聊天中的颜色。",
    es = "Establece el color para los mensajes de Pocket Money en el chat.",
    it = "Imposta il colore per i messaggi di Pocket Money nella chat.",
    pl = "Ustaw kolor wiadomości Pocket Money na czacie."
  },
  BANKER_COOLDOWN = {
    en = "Banker Cooldown",
    de = "Banker-Abklingzeit",
    fr = "Temps de recharge du banquier",
    ru = "Время ожидания банкира",
    ja = "バンカーのクールダウン",
    zh = "银行员冷却时间",
    es = "Enfriamiento del banquero",
    it = "Raffreddamento del banchiere",
    pl = "Czas odnowienia bankiera"
  },
  BANKER_COOLDOWN_TOOLTIP = {
    en = "Number of minutes to wait before pocket money transfer will be used again after visiting a banker.",
    de = "Anzahl der Minuten, die nach dem Besuch eines Bankiers gewartet werden muss, bevor Pocket Money erneut verwendet werden kann.",
    fr = "Nombre de minutes à attendre avant de pouvoir utiliser à nouveau Pocket Money après avoir visité un banquier.",
    ru = "Количество минут ожидания перед повторным использованием Pocket Money после посещения банкира.",
    ja = "バンカー訪問後、ポケットマネー転送が再度使用可能になるまでの待機時間（分）",
    zh = "访问银行员后零钱转账再次可用前需等待的分钟数。",
    es = "Número de minutos a esperar antes de que la transferencia de Pocket Money se pueda usar nuevamente después de visitar al banquero.",
    it = "Numero di minuti da attendere prima che il trasferimento di Pocket Money possa essere utilizzato di nuovo dopo aver visitato il banchiere.",
    pl = "Liczba minut oczekiwania przed ponownym użyciem transferu Pocket Money po odwiedzeniu bankiera."
  },
  GOLD_VALUE = {
    en = "Gold Value",
    de = "Goldbetrag",
    fr = "Montant d'or",
    ru = "Сумма золота",
    ja = "ゴールド値",
    zh = "金币数值",
    es = "Valor de oro",
    it = "Valore oro",
    pl = "Wartość złota"
  },
  GOLD_TOOLTIP = {
    en = "Account-wide value for how much gold must be used as pocket money. This can be overridden per character.",
    de = "Accountweiter Wert, wie viel Gold als Pocket Money verwendet werden soll. Kann pro Charakter überschrieben werden.",
    fr = "Valeur globale du compte pour la quantité d'or à utiliser comme Pocket Money. Peut être remplacé par personnage.",
    ru = "Общая сумма золота для Pocket Money. Можно переопределить для каждого персонажа.",
    ja = "アカウント全体でポケットマネーとして使用するゴールドの値。キャラクターごとに上書き可能。",
    zh = "账号范围内零钱金币数值，可单独为角色设置覆盖。",
    es = "Valor a nivel de cuenta de cuánto oro debe usarse como Pocket Money. Esto puede ser sobrescrito por personaje.",
    it = "Valore a livello account di quanto oro deve essere usato come Pocket Money. Può essere sovrascritto per personaggio.",
    pl = "Wartość złota dla całego konta jako Pocket Money. Można nadpisać dla każdej postaci."
  },
  TELVAR_VALUE = {
    en = "Tel Var Value",
    de = "Tel Var Betrag",
    fr = "Montant Tel Var",
    ru = "Сумма Tel Var",
    ja = "テルバー値",
    zh = "泰瓦石数值",
    es = "Valor de Tel Var",
    it = "Valore Tel Var",
    pl = "Wartość Tel Var"
  },
  TELVAR_TOOLTIP = {
    en = "Account-wide value for how much Tel Var must be used as pocket money. This can be overridden per character.",
    de = "Accountweiter Wert, wie viel Tel Var als Pocket Money verwendet werden soll. Kann pro Charakter überschrieben werden.",
    fr = "Valeur globale du compte pour la quantité de Tel Var à utiliser comme Pocket Money. Peut être remplacé par personnage.",
    ru = "Общая сумма Tel Var для Pocket Money. Можно переопределить для каждого персонажа.",
    ja = "アカウント全体でポケットマネーとして使用するテルバーの値。キャラクターごとに上書き可能。",
    zh = "账号范围内零钱泰瓦石数值，可单独为角色设置覆盖。",
    es = "Valor a nivel de cuenta de cuánto Tel Var debe usarse como Pocket Money. Esto puede ser sobrescrito por personaje.",
    it = "Valore a livello account di quanto Tel Var deve essere usato come Pocket Money. Può essere sovrascritto per personaggio.",
    pl = "Wartość Tel Var dla całego konta jako Pocket Money. Można nadpisać dla każdej postaci."
  },
  AP_VALUE = {
    en = "Alliance Points Value",
    de = "Allianzpunktewert",
    fr = "Montant de points d'alliance",
    ru = "Сумма очков альянса",
    ja = "同盟ポイント値",
    zh = "联盟点数值",
    es = "Valor de puntos de alianza",
    it = "Valore punti alleanza",
    pl = "Wartość punktów sojuszu"
  },
  AP_TOOLTIP = {
    en = "Account-wide value how much Alliance Points must be used as pocket money. This can be overridden per character.",
    de = "Accountweiter Wert, wie viele Allianzpunkte als Pocket Money verwendet werden sollen. Kann pro Charakter überschrieben werden.",
    fr = "Valeur globale du compte pour la quantité de points d'alliance à utiliser comme Pocket Money. Peut être remplacé par personnage.",
    ru = "Общая сумма очков альянса для Pocket Money. Можно переопределить для каждого персонажа.",
    ja = "アカウント全体でポケットマネーとして使用する同盟ポイントの値。キャラクターごとに上書き可能。",
    zh = "账号范围内零钱联盟点数值，可单独为角色设置覆盖。",
    es = "Valor a nivel de cuenta de cuántos puntos de alianza deben usarse como Pocket Money. Esto puede ser sobrescrito por personaje.",
    it = "Valore a livello account di quanti punti alleanza devono essere usati come Pocket Money. Può essere sovrascritto per personaggio.",
    pl = "Wartość punktów sojuszu dla całego konta jako Pocket Money. Można nadpisać dla każdej postaci."
  },
  WRIT_VALUE = {
    en = "Writ Vouchers Value",
    de = "Schriftscheinwert",
    fr = "Montant de bons",
    ru = "Сумма ваучеров",
    ja = "公示券値",
    zh = "公示券数值",
    es = "Valor de vales de encargo",
    it = "Valore voucher",
    pl = "Wartość kuponów"
  },
  WRIT_TOOLTIP = {
    en = "Account-wide value for how much Writ Vouchers must be use as pocket money. This can be overridden per character.",
    de = "Accountweiter Wert, wie viele Schriftscheine als Pocket Money verwendet werden sollen. Kann pro Charakter überschrieben werden.",
    fr = "Valeur globale du compte pour la quantité de bons à utiliser comme Pocket Money. Peut être remplacé par personnage.",
    ru = "Общая сумма ваучеров для Pocket Money. Можно переопределить для каждого персонажа.",
    ja = "アカウント全体でポケットマネーとして使用する公示券の値。キャラクターごとに上書き可能。",
    zh = "账号范围内零钱公示券数值，可单独为角色设置覆盖。",
    es = "Valor a nivel de cuenta de cuántos vales de encargo deben usarse como Pocket Money. Esto puede ser sobrescrito por personaje.",
    it = "Valore a livello account di quanti voucher devono essere usati come Pocket Money. Può essere sovrascritto per personaggio.",
    pl = "Wartość kuponów dla całego konta jako Pocket Money. Można nadpisać dla każdej postaci."
  },
  CHAR_HEADER = {
    en = "Character Settings",
    de = "Charaktereinstellungen",
    fr = "Paramètres du personnage",
    ru = "Настройки персонажа",
    ja = "キャラクター設定",
    zh = "角色设置",
    es = "Configuración de personaje",
    it = "Impostazioni personaggio",
    pl = "Ustawienia postaci"
  },
  USE_PM = {
    en = "Use of PocketMoney",
    de = "Verwendung von PocketMoney",
    fr = "Utilisation de PocketMoney",
    ru = "Использование PocketMoney",
    ja = "PocketMoneyの利用",
    zh = "PocketMoney的使用",
    es = "Uso de PocketMoney",
    it = "Utilizzo di PocketMoney",
    pl = "Użycie PocketMoney"
  },
  USE_PM_TOOLTIP = {
    en = "Determines if pocket money is used by this character and whether to use the account-wide settings or character-specific settings.",
    de = "Legt fest, ob Pocket Money für diesen Charakter verwendet wird und ob die accountweiten oder die charakterspezifischen Einstellungen genutzt werden.",
    fr = "Détermine si Pocket Money est utilisé par ce personnage et si les paramètres du compte ou du personnage sont utilisés.",
    ru = "Определяет, используется ли Pocket Money для этого персонажа и используются ли общие или индивидуальные настройки.",
    ja = "このキャラクターでポケットマネーを使用するか、アカウント全体の設定かキャラクター固有の設定かを決定します。",
    zh = "决定此角色是否使用零钱，以及使用账号设置还是角色设置。",
    es = "Determina si Pocket Money se usa por este personaje y si se usan los ajustes a nivel de cuenta o específicos del personaje.",
    it = "Determina se Pocket Money viene utilizzato da questo personaggio e se utilizzare le impostazioni a livello account o specifiche del personaggio.",
    pl = "Określa, czy Pocket Money jest używane przez tę postać i czy używać ustawień dla całego konta czy indywidualnych."
  },
  CHAR_BANKER_COOLDOWN = {
    en = "Banker Cooldown",
    de = "Banker-Abklingzeit",
    fr = "Temps de recharge du banquier",
    ru = "Время ожидания банкира",
    ja = "バンカーのクールダウン",
    zh = "银行员冷却时间",
    es = "Enfriamiento del banquero",
    it = "Raffreddamento del banchiere",
    pl = "Czas odnowienia bankiera"
  },
  CHAR_BANKER_COOLDOWN_TOOLTIP = {
    en = "Number of minutes to wait before pocket money transfer can be used again after visiting a banker.",
    de = "Anzahl der Minuten, die nach dem Besuch eines Bankiers gewartet werden muss, bevor Pocket Money erneut verwendet werden kann.",
    fr = "Nombre de minutes à attendre avant de pouvoir utiliser à nouveau Pocket Money après avoir visité un banquier.",
    ru = "Количество минут ожидания перед повторным использованием Pocket Money после посещения банкира.",
    ja = "バンカー訪問後、ポケットマネー転送が再度使用可能になるまでの待機時間（分）",
    zh = "访问银行员后零钱转账再次可用前需等待的分钟数。",
    es = "Número de minutos a esperar antes de que la transferencia de Pocket Money se pueda usar nuevamente después de visitar al banquero.",
    it = "Numero di minuti da attendere prima che il trasferimento di Pocket Money possa essere utilizzato di nuovo dopo aver visitato il banchiere.",
    pl = "Liczba minut oczekiwania przed ponownym użyciem transferu Pocket Money po odwiedzeniu bankiera."
  },
  CHAR_GOLD_TOOLTIP = {
    en = "Character-specific value for how much gold must be used as pocket money. This overrides the account-wide gold value if pocket money is enabled for this character.",
    de = "Charakterspezifischer Wert, wie viel Gold als Pocket Money verwendet werden soll. Überschreibt den accountweiten Wert, wenn Pocket Money für diesen Charakter aktiviert ist.",
    fr = "Valeur spécifique au personnage pour la quantité d'or à utiliser comme Pocket Money. Remplace la valeur globale si Pocket Money est activé pour ce personnage.",
    ru = "Индивидуальная сумма золота для Pocket Money. Переопределяет общую сумму, если Pocket Money включен для этого персонажа.",
    ja = "このキャラクターでポケットマネーとして使用するゴールドの値。アカウント全体の値を上書きします。",
    zh = "角色范围内零钱金币数值，启用后覆盖账号设置。",
    es = "Valor específico del personaje de cuánto oro debe usarse como Pocket Money. Esto sobrescribe el valor a nivel de cuenta si Pocket Money está habilitado para este personaje.",
    it = "Valore specifico del personaggio di quanto oro deve essere usato come Pocket Money. Sovrascrive il valore a livello account se Pocket Money è abilitato per questo personaggio.",
    pl = "Indywidualna wartość złota dla Pocket Money. Nadpisuje wartość dla całego konta, jeśli Pocket Money jest włączone dla tej postaci."
  },
  CHAR_TELVAR_VALUE = {
    en = "Tel Var Value",
    de = "Tel Var Betrag",
    fr = "Montant Tel Var",
    ru = "Сумма Tel Var",
    ja = "テルバー値",
    zh = "泰瓦石数值",
    es = "Valor de Tel Var",
    it = "Valore Tel Var",
    pl = "Wartość Tel Var"
  },
  CHAR_TELVAR_TOOLTIP = {
    en = "Character-specific value for how much Tel Var Stones must be used as pocket money. This overrides the account-wide Tel Var value if pocket money is enabled for this character.",
    de = "Charakterspezifischer Wert, wie viel Tel Var als Pocket Money verwendet werden soll. Überschreibt den accountweiten Wert, wenn Pocket Money für diesen Charakter aktiviert ist.",
    fr = "Valeur spécifique au personnage pour la quantité de Tel Var à utiliser comme Pocket Money. Remplace la valeur globale si Pocket Money est activé pour ce personnage.",
    ru = "Индивидуальная сумма Tel Var для Pocket Money. Переопределяет общую сумму, если Pocket Money включен для этого персонажа.",
    ja = "このキャラクターでポケットマネーとして使用するテルバーの値。アカウント全体の値を上書きします。",
    zh = "角色范围内零钱泰瓦石数值，启用后覆盖账号设置。",
    es = "Valor específico del personaje de cuántas Tel Var Stones deben usarse como Pocket Money. Esto sobrescribe el valor a nivel de cuenta si Pocket Money está habilitado para este personaje.",
    it = "Valore specifico del personaggio di quante Tel Var Stones devono essere usate come Pocket Money. Sovrascrive il valore a livello account se Pocket Money è abilitato per questo personaggio.",
    pl = "Indywidualna wartość Tel Var dla Pocket Money. Nadpisuje wartość dla całego konta, jeśli Pocket Money jest włączone dla tej postaci."
  },
  CHAR_AP_VALUE = {
    en = "Alliance Points Value",
    de = "Allianzpunktewert",
    fr = "Montant de points d'alliance",
    ru = "Сумма очков альянса",
    ja = "同盟ポイント値",
    zh = "联盟点数值",
    es = "Valor de puntos de alianza",
    it = "Valore punti alleanza",
    pl = "Wartość punktów sojuszu"
  },
  CHAR_AP_TOOLTIP = {
    en = "Character-specific value for how much Alliance Points must be used as pocket money. This overrides the account-wide AP value if pocket money is enabled for this character.",
    de = "Charakterspezifischer Wert, wie viele Allianzpunkte als Pocket Money verwendet werden sollen. Überschreibt den accountweiten Wert, wenn Pocket Money für diesen Charakter aktiviert ist.",
    fr = "Valeur spécifique au personnage pour la quantité de points d'alliance à utiliser comme Pocket Money. Remplace la valeur globale si Pocket Money est activé pour ce personnage.",
    ru = "Индивидуальная сумма очков альянса для Pocket Money. Переопределяет общую сумму, если Pocket Money включен для этого персонажа.",
    ja = "このキャラクターでポケットマネーとして使用する同盟ポイントの値。アカウント全体の値を上書きします。",
    zh = "角色范围内零钱联盟点数值，启用后覆盖账号设置。",
    es = "Valor específico del personaje de cuántos puntos de alianza deben usarse como Pocket Money. Esto sobrescribe el valor a nivel de cuenta si Pocket Money está habilitado para este personaje.",
    it = "Valore specifico del personaggio di quanti punti alleanza devono essere usati come Pocket Money. Sovrascrive il valore a livello account se Pocket Money è abilitato per questo personaggio.",
    pl = "Indywidualna wartość punktów sojuszu dla Pocket Money. Nadpisuje wartość dla całego konta, jeśli Pocket Money jest włączone dla tej postaci."
  },
  CHAR_WRIT_VALUE = {
    en = "Writ Vouchers Value",
    de = "Schriftscheinwert",
    fr = "Montant de bons",
    ru = "Сумма ваучеров",
    ja = "公示券値",
    zh = "公示券数值",
    es = "Valor de vales de encargo",
    it = "Valore voucher",
    pl = "Wartość kuponów"
  },
  CHAR_WRIT_TOOLTIP = {
    en = "Character-specific value for how much Writ Vouchers must be used as pocket money. This overrides the account-wide Writ Vouchers value if pocket money is enabled for this character.",
    de = "Charakterspezifischer Wert, wie viele Schriftscheine als Pocket Money verwendet werden sollen. Überschreibt den accountweiten Wert, wenn Pocket Money für diesen Charakter aktiviert ist.",
    fr = "Valeur spécifique au personnage pour la quantité de bons à utiliser comme Pocket Money. Remplace la valeur globale si Pocket Money est activé pour ce personnage.",
    ru = "Индивидуальная сумма ваучеров для Pocket Money. Переопределяет общую сумму, если Pocket Money включен для этого персонажа.",
    ja = "このキャラクターでポケットマネーとして使用する公示券の値。アカウント全体の値を上書きします。",
    zh = "角色范围内零钱公示券数值，启用后覆盖账号设置。",
    es = "Valor específico del personaje de cuántos vales de encargo deben usarse como Pocket Money. Esto sobrescribe el valor a nivel de cuenta si Pocket Money está habilitado para este personaje.",
    it = "Valore specifico del personaggio di quanti voucher devono essere usati come Pocket Money. Sovrascrive il valore a livello account se Pocket Money è abilitato per questo personaggio.",
    pl = "Indywidualna wartość kuponów dla Pocket Money. Nadpisuje wartość dla całego konta, jeśli Pocket Money jest włączone dla tej postaci."
  },
  GLOBAL_HEADER = {
    en = "Global Settings",
    de = "Globale Einstellungen",
    fr = "Paramètres globaux",
    ru = "Глобальные настройки",
    ja = "グローバル設定",
    zh = "全局设置",
    es = "Configuración global",
    it = "Impostazioni globali",
    pl = "Ustawienia globalne"
  },
  USE_PM_BUTTON = {
    en = "Use Pocket Money",
    de = "Pocket Money verwenden",
    fr = "Utiliser Pocket Money",
    ru = "Использовать Pocket Money",
    ja = "ポケットマネーを使用",
    zh = "使用零钱",
    es = "Usar Pocket Money",
    it = "Usa Pocket Money",
    pl = "Użyj Pocket Money"
  }
}

--- Localizes a string based on the current language setting.
-- This function retrieves the localized string for the given key based on the current language setting.
-- If the string is not available in the current language, it defaults to English.
-- @param key The key for the string to be localized.
-- @return The localized string for the given key.
---@param key string
---@return string localizedString
local function L(key)
    local lang = GetCVar("Language.2")
    return strings[key][lang] or strings[key]["en"]
end

--- Converts RGB values to a hexadecimal color string.
-- This function takes RGB values in the range 0–1 and converts them to a hexadecimal color string.
-- @param r The red component (0–1).
-- @param g The green component (0–1).
-- @param b The blue component (0–1).
-- @return A string representing the color in hexadecimal format (e.g., "FF0000" for red).
---@param r number
---@param g number
---@param b number
---@return string hexColor
function PocketMoney:RGBToHex(r, g, b)
    -- Clamp values to range 0–255
    r = math.max(0, math.min(255, r))
    g = math.max(0, math.min(255, g))
    b = math.max(0, math.min(255, b))

    return
        string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

--- Gets the target value and action for the specified currency type and current amount. 
--- This function determines whether to deposit or withdraw based on the current amount and target value.
--- @param currencyType The type of currency (e.g., CURT_MONEY, CURT_TELVAR_STONES, CURT_ALLIANCE_POINTS, CURT_WRIT_VOUCHERS).
--- @param currentAmount The current amount of the specified currency.
--- @return transferAmount The amount to transfer (deposit or withdraw).
--- @return targetValue The target value for the specified currency type.
--- @return action The action to take ("deposit" or "withdraw").
function PocketMoney:GetTargetValueAndAction(currencyType, currentAmount)
    -- You can extend this to have separate settings for each currency if desired
    if PocketMoney.DEBUG then
        d(string.format("PocketMoney:GetTargetValueAndAction called with currencyType: %d, currentAmount: %d",
            currencyType, currentAmount))
        d(string.format(
            "PocketMoney:GetTargetValueAndAction: charVars.usePocketMoney: %s, savedVars.forceUsePocketMoney: %s",
            tostring(PocketMoney.charVars.usePocketMoney), tostring(PocketMoney.savedVars.forceUsePocketMoney)))
    end
    local targetValue
    if currencyType == CURT_MONEY then
        if PocketMoney.DEBUG then
            d("PocketMoney:GetTargetValueAndAction: Using Gold")
        end
        if (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_ACCOUNT_WIDE") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_ACCOUNT_WIDE then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Gold")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyGoldValue or PocketMoney.defaults.PocketMoneyGoldValue
        elseif (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_CHARACTER_ON") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_CHARACTER then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using character-specific settings for Gold")
            end
            targetValue = PocketMoney.charVars.PocketMoneyGoldValue or
                              PocketMoney.characterDefaults.PocketMoneyGoldValue
        else
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Gold")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyGoldValue or PocketMoney.defaults.PocketMoneyGoldValue
        end
    elseif currencyType == CURT_TELVAR_STONES then
        if PocketMoney.DEBUG then
            d("PocketMoney:GetTargetValueAndAction: Using Tel Var Stones")
        end
        if (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_ACCOUNT_WIDE") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_ACCOUNT_WIDE then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Tel Var Stones")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyTelVarValue or PocketMoney.defaults.PocketMoneyTelVarValue
        elseif (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_CHARACTER_ON") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_CHARACTER then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using character-specific settings for Tel Var Stones")
            end
            targetValue = PocketMoney.charVars.PocketMoneyTelVarValue or
                              PocketMoney.characterDefaults.PocketMoneyTelVarValue
        else
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Tel Var Stones")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyTelVarValue or PocketMoney.defaults.PocketMoneyTelVarValue
        end
    elseif currencyType == CURT_ALLIANCE_POINTS then
        if PocketMoney.DEBUG then
            d("PocketMoney:GetTargetValueAndAction: Using Alliance Points")
        end
        if (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_ACCOUNT_WIDE") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_ACCOUNT_WIDE then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Alliance Points")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyAPValue or PocketMoney.defaults.PocketMoneyAPValue
        elseif (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_CHARACTER_ON") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_CHARACTER then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using character-specific settings for Alliance Points")
            end
            targetValue = PocketMoney.charVars.PocketMoneyAPValue or PocketMoney.characterDefaults.PocketMoneyAPValue
        else
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Alliance Points")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyAPValue or PocketMoney.defaults.PocketMoneyAPValue
        end
    elseif currencyType == CURT_WRIT_VOUCHERS then
        if PocketMoney.DEBUG then
            d("PocketMoney:GetTargetValueAndAction: Using Writ Vouchers")
        end
        if (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_ACCOUNT_WIDE") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_ACCOUNT_WIDE then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Writ Vouchers")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyWritVoucherValue or
                              PocketMoney.defaults.PocketMoneyWritVoucherValue
        elseif (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
            "FORCE_CHARACTER_ON") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_CHARACTER then
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using character-specific settings for Writ Vouchers")
            end
            targetValue = PocketMoney.charVars.PocketMoneyWritVoucherValue or
                              PocketMoney.characterDefaults.PocketMoneyWritVoucherValue
        else
            if PocketMoney.DEBUG then
                d("PocketMoney:GetTargetValueAndAction: Using account-wide settings for Writ Vouchers")
            end
            targetValue = PocketMoney.savedVars.PocketMoneyWritVoucherValue or
                              PocketMoney.defaults.PocketMoneyWritVoucherValue
        end
    else
        -- If the currency type is not recognized, return 0 and "none"
        if PocketMoney.DEBUG then
            d(string.format("PocketMoney:GetRequiredPocketMoneyActionForCurrency: Unrecognized currency type: %d",
                currencyType))
        end
        return 0, 0, "none"
    end
    local difference = currentAmount - targetValue
    if difference > 0 then
        if PocketMoney.DEBUG then
            d(string.format("PocketMoney:GetRequiredPocketMoneyActionForCurrency: Need to deposit %d", difference))
        end
        return difference, targetValue, "deposit"
    elseif difference < 0 then
        if PocketMoney.DEBUG then
            d(string.format("PocketMoney:GetRequiredPocketMoneyActionForCurrency: Need to withdraw %d",
                math.abs(difference)))
        end
        return math.abs(difference), targetValue, "withdraw"
    else
        if PocketMoney.DEBUG then
            d(
                "PocketMoney:GetRequiredPocketMoneyActionForCurrency: No action needed, current amount matches target value")
        end
        return 0, 0, "none"
    end
end

--- Sends a message to the chat window with the specified content.
--- This function uses the LibChatMessage library to format and send the message.
--- It sets the tag prefix mode to short and applies the message color defined in the saved variables.
--- @param msg string The message content to send.
--- @return void
--- @usage PocketMoney:SendMessage("Hello, this is a test message!") -- Sends a message to the chat window.
function PocketMoney:SendMessage(msg)
    local chat = LibChatMessage("Pocket Money", "PocketMoney")
    LibChatMessage:SetTagPrefixMode(TAG_PREFIX_SHORT)
    local msgcolor = PocketMoney:RGBToHex(PocketMoney.savedVars.msgcolor.r, PocketMoney.savedVars.msgcolor.g,
        PocketMoney.savedVars.msgcolor.b)
    chat:SetTagColor(msgcolor):Print("|c" .. msgcolor .. msg .. "|r ")
end

--- Converts a currency type to a string representation.
--- This function is used to convert the currency type constants (e.g., CURT_MONEY, CURT_TELVAR_STONES, etc.)
--- into human-readable strings for display in messages.
--- @param currencyType number The type of currency to convert (e.g., CURT_MONEY, CURT_TELVAR_STONES, etc.).
--- @return string The string representation of the currency type.
--- @usage PocketMoney:CurrencyTypeToString(CURT_MONEY) -- Returns "Gold"
--- @usage PocketMoney:CurrencyTypeToString(CURT_TELVAR_STONES) -- Returns "Tel Var Stones"
--- @usage PocketMoney:CurrencyTypeToString(CURT_ALLIANCE_POINTS) -- Returns "Alliance Points"
--- @usage PocketMoney:CurrencyTypeToString(CURT_WRIT_VOUCHERS) -- Returns "Writ Vouchers"
function PocketMoney:CurrencyTypeToString(currencyType)
    if currencyType == CURT_MONEY then
        return "Gold"
    elseif currencyType == CURT_TELVAR_STONES then
        return "Tel Var Stones"
    elseif currencyType == CURT_ALLIANCE_POINTS then
        return "Alliance Points"
    elseif currencyType == CURT_WRIT_VOUCHERS then
        return "Writ Vouchers"
    else
        return "Unknown"
    end
end

--- Transfers the specified currency type between the character's carry and bank locations.
--- This function checks the current amount of the specified currency in both carry and bank locations,
--- calculates the required transfer amount to reach the target value, and performs the transfer.
--- It also sends a message to the user indicating the action taken.
--- @param currencyType number The type of currency to transfer (e.g., CURT_MONEY, CURT_TELVAR_STONES, etc.).
--- @return void
--- @usage PocketMoney:Transfer(CURT_MONEY) -- Transfers Gold
--- @usage PocketMoney:Transfer(CURT_TELVAR_STONES) -- Transfers Tel Var Stones
--- @usage PocketMoney:Transfer(CURT_ALLIANCE_POINTS) -- Transfers Alliance Points
--- @usage PocketMoney:Transfer(CURT_WRIT_VOUCHERS) -- Transfers Writ Vouchers
function PocketMoney:Transfer(currencyType)
    if PocketMoney.DEBUG then
        d(string.format("PocketMoney:Transfer called with currencyType: %d", currencyType))
    end
    local currentCarryAmount = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER)
    local currentBankedAmount = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_BANK)
    if PocketMoney.DEBUG then
        d(string.format("Current Amount for currencyType %d: %d", currencyType, currentCarryAmount))
    end
    local transferAmount, targetValue, actionGold =
        PocketMoney:GetTargetValueAndAction(currencyType, currentCarryAmount)
    if PocketMoney.DEBUG then
        d(string.format("Current Gold: %d, Required Gold: %d, Action: %s", currentCarryAmount, transferAmount,
            actionGold))
    end
    if transferAmount > 0 then
        if actionGold == "deposit" then
            if PocketMoney.DEBUG then
                d(string.format("Depositing %d %s into the bank", transferAmount,
                    PocketMoney:CurrencyTypeToString(currencyType)))
            end
            TransferCurrency(currencyType, transferAmount, CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK)
            PocketMoney:SendMessage(string.format(L("DEPOSIT_MSG"), transferAmount,
                PocketMoney:CurrencyTypeToString(currencyType), targetValue))
        elseif actionGold == "withdraw" then
            local tooLittleInBank = currentBankedAmount < transferAmount
            if tooLittleInBank then
                transferAmount = currentBankedAmount
            end
            if transferAmount == 0 then
                return
            end
            if PocketMoney.DEBUG then
                d(string.format("Withdrawing %d %s from the bank", transferAmount,
                    PocketMoney:CurrencyTypeToString(currencyType)))
            end
            TransferCurrency(currencyType, transferAmount, CURRENCY_LOCATION_BANK, CURRENCY_LOCATION_CHARACTER)
            if tooLittleInBank then
                PocketMoney:SendMessage(string.format(L("WITHDRAW_MSG_TOO_LITTLE"), transferAmount,
                    PocketMoney:CurrencyTypeToString(currencyType), targetValue))
            else
                PocketMoney:SendMessage(string.format(L("WITHDRAW_MSG"), transferAmount,
                    PocketMoney:CurrencyTypeToString(currencyType), targetValue))
            end

        end
    end
end

--- Processes the banker used event.
--- This function checks if pocket money is enabled for the character and if the cooldown is active or not.
--- If the cooldown is active, it sends a message to the user and does not perform any transfers.
--- If the cooldown is not active, it performs the transfers for Gold, Tel Var Stones, Alliance Points, and Writ Vouchers.
--- It also updates the last used timestamp to check the cooldown next time.
--- @return void
function PocketMoney:ProcessBanker()
    if PocketMoney.DEBUG then
        d("PocketMoney:ProcessBankerUsed called")
    end

    -- Check if pocketmoney is disabled for this character
    if PocketMoney.DEBUG then
        d(string.format("PocketMoney:ProcessBankerUsed: usePocketMoney: %s, forceUsePocketMoney: %s, forced %s",
            tostring(PocketMoney.charVars.usePocketMoney), tostring(PocketMoney.savedVars.forceUsePocketMoney),
            tostring(forced)))
    end
    if (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
        "FORCE_CHARACTER_OFF") or PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_DISABLED then
        PocketMoney:SendMessage("Pocket Money is disabled for this character")
        return
    end

    -- Cooldown logic which ensures that while the cooldown is active, currency will be be automatically transferred
    -- when the banker is used.
    local now = GetTimeStamp()
    local lastUsed = PocketMoney.charVars.lastTimeUsed or 0
    local cooldownMinutes
    if (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney == "FORCE_CHARACTER_ON") or
        PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_CHARACTER then
        if DEBUG then
            d("PocketMoney:OnBankerUsed: Using character-specific cooldown settings")
        end
        cooldownMinutes = PocketMoney.charVars.bankerCooldownMinutes or PocketMoney.defaults.bankerCooldownMinutes
    else
        if PocketMoney.DEBUG then
            d("PocketMoney:OnBankerUsed: Using account-wide cooldown settings")
        end
        cooldownMinutes = PocketMoney.savedVars.bankerCooldownMinutes or PocketMoney.defaults.bankerCooldownMinutes
    end
    local cooldownSeconds = cooldownMinutes * 60

    if now - lastUsed < cooldownSeconds then
        local remaining = math.ceil((cooldownSeconds - (now - lastUsed)) / 60)
        PocketMoney:SendMessage(string.format(L("COOLDOWN_MSG"), remaining))
        if PocketMoney.DEBUG then
            d(string.format("PocketMoney:OnBankerUsed: Cooldown active, %d seconds remaining",
                cooldownSeconds - (now - lastUsed)))
        end
        return
    end

    -- Perform transfers
    PocketMoney:Transfer(CURT_MONEY) -- Transfer Gold
    PocketMoney:Transfer(CURT_TELVAR_STONES) -- Transfer Tel Var Stones
    PocketMoney:Transfer(CURT_ALLIANCE_POINTS) -- Transfer Alliance Points
    PocketMoney:Transfer(CURT_WRIT_VOUCHERS) -- Transfer Writ Vouchers

    -- Update last used timestamp to check cooldown next time
    PocketMoney.charVars.lastTimeUsed = now
end

--- Responder for the event EVENT_OPEN_BANKER
--- This function is called when a banker is used.
--- It checks if the bagId is a house bank bag and if so, it does not process the banker.
--- If the bagId is not a house bank bag, it sets the bankerOpen variable to true
--- and calls the ProcessBanker function to handle the pocket money transfers.
function PocketMoney:OnBankerUsed(_, bagId)
    if PocketMoney.DEBUG then
        d("PocketMoney:OnBankerUsed called")
    end
    if IsHouseBankBag(bagId) then
        return
    end

    PocketMoney.bankerOpen = true
    PocketMoney:ProcessBanker()
end

--- Responder for the event EVENT_CLOSE_BANKER
--- This function is called when the banker is closed.
--- It resets the bagId to nil so the UsePocketMoneyButton cannot be used anymore.
--- This is necessary to prevent the button from being used after the banker is closed.
---@param event any
function PocketMoney:OnBankerClosed(event)
    if PocketMoney.DEBUG then
        d("PocketMoney:OnBankerClosed called")
    end
    -- Reset bagId when the banker is closed
    if PocketMoney.DEBUG then
        d("PocketMoney:OnBankerClosed: Resetting bankerOpen to false")
    end
    PocketMoney.bankerOpen = false
end

--- Creates the Use Pocket Money button and adds it to the keybind strip.
--- This button will only be shown when the banker is used and the characters has Pocket Money enabled
--- The button will be added during initialization of the addon.
PocketMoney.useButton = {
    name = L("USE_PM_BUTTON"),
    keybind = "UI_SHORTCUT_QUATERNARY",
    callback = function(input, input2)
        if PocketMoney.DEBUG then
          d("PocketMoney:UsePocketMoneyButton pressed")
        end
        if PocketMoney.bankerOpen then 
          PocketMoney.charVars.lastTimeUsed = nil
          PocketMoney:ProcessBanker() 
        end
      end,
    visible = function() return PocketMoney.bankerOpen and PocketMoney.charVars.usePocketMoney ~= POCKETMONEY_MODE_DISABLED end,
}

--- Creates the settings panel for PocketMoney.
function PocketMoney:CreateSettingsPanel()
    local panelName = "PocketMoneySettingsPanel"

    if IsConsoleUI() and not LibAddonMenu2 then return end

    local function getDropdownValue()
        if PocketMoney.charVars.usePocketMoney == nil then
            if PocketMoney.savedVars.forceUsePocketMoney == "FORCE_ACCOUNT_WIDE" then
                return POCKETMONEY_MODE_ACCOUNT_WIDE
            elseif PocketMoney.savedVars.forceUsePocketMoney == "FORCE_CHARACTER_ON" then
                return POCKETMONEY_MODE_CHARACTER
            elseif PocketMoney.savedVars.forceUsePocketMoney == "FORCE_CHARACTER_OFF" then
                return POCKETMONEY_MODE_DISABLED
            else
                return POCKETMONEY_MODE_ACCOUNT_WIDE
            end
        else
            return PocketMoney.charVars.usePocketMoney
        end
    end

    local function handleSliderChange()
        PocketMoney.charVars.usePocketMoney = getDropdownValue()
        PocketMoney.charVars.lastTimeUsed = nil
    end

    local optionsTable = {{
        type = "dropdown",
        name = L("USE_PM"),
        tooltip = L("USE_PM_TOOLTIP"),
        choices = {L("ACCOUNT_HEADER"), L("CHAR_HEADER"), L("DISABLE_FOR_CHARACTER")},
        choicesValues = {POCKETMONEY_MODE_ACCOUNT_WIDE, POCKETMONEY_MODE_CHARACTER, POCKETMONEY_MODE_DISABLED},
        reference = "PocketMoneyDropdownControl",
        getFunc = function()
            return getDropdownValue()
        end,
        setFunc = function(value)
            PocketMoney.charVars.usePocketMoney = value
            PocketMoney.charVars.lastTimeUsed = nil
        end,
        default = POCKETMONEY_MODE_ACCOUNT_WIDE
    }, {
        type = "slider",
        name = L("BANKER_COOLDOWN"),
        tooltip = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return L("BANKER_COOLDOWN_TOOLTIP")
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return L("CHAR_BANKER_COOLDOWN_TOOLTIP")
            else
                return L("BANKER_COOLDOWN_TOOLTIP")
            end
        end,
        min = 0,
        max = 60,
        step = 1,
        getFunc = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return PocketMoney.savedVars.bankerCooldownMinutes or PocketMoney.defaults.bankerCooldownMinutes
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return PocketMoney.charVars.bankerCooldownMinutes or PocketMoney.characterDefaults.bankerCooldownMinutes
            else
                return PocketMoney.defaults.bankerCooldownMinutes
            end
        end,
        setFunc = function(value)
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                if PocketMoney.DEBUG then
                    d("PocketMoney:CreateSettingsPanel: Setting bankerCooldownMinutes for account-wide settings")
                end
                PocketMoney.savedVars.bankerCooldownMinutes = value
                PocketMoney.charVars.lastTimeUsed = 0
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                if PocketMoney.DEBUG then
                    d("PocketMoney:CreateSettingsPanel: Setting bankerCooldownMinutes for character-specific settings")
                end
                PocketMoney.charVars.bankerCooldownMinutes = value
                PocketMoney.charVars.lastTimeUsed = 0
            end
            handleSliderChange()
        end,
        disabled = function()
            return (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
                       "FORCE_CHARACTER_OFF") or (PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_DISABLED)
        end,
        default = PocketMoney.defaults.bankerCooldownMinutes
    }, {
        type = "slider",
        name = L("GOLD_VALUE"),
        tooltip = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return L("GOLD_TOOLTIP")
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return L("CHAR_GOLD_TOOLTIP")
            else
                return L("GOLD_TOOLTIP")
            end
        end,
        min = 0,
        max = 1000000,
        step = 1000,
        getFunc = function()
           local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                local thevalue = PocketMoney.savedVars.PocketMoneyGoldValue or PocketMoney.defaults.PocketMoneyGoldValue
                if PocketMoney.DEBUG then
                    d(string.format(
                        "PocketMoney:CreateSettingsPanel: Getting PocketMoneyGoldValue for account-wide settings = %d",
                        thevalue))
                end
                return thevalue
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                local thevalue = PocketMoney.charVars.PocketMoneyGoldValue or
                                     PocketMoney.characterDefaults.PocketMoneyGoldValue
                if PocketMoney.DEBUG then
                    d(string.format(
                        "PocketMoney:CreateSettingsPanel: Getting PocketMoneyGoldValue for character-specific settings = %d",
                        thevalue))
                end
                return thevalue
            else
                if PocketMoney.DEBUG then
                    d("PocketMoney:CreateSettingsPanel: Getting PocketMoneyGoldValue for default settings")
                end
                return PocketMoney.defaults.PocketMoneyGoldValue
            end
        end,
        setFunc = function(value)
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                PocketMoney.savedVars.PocketMoneyGoldValue = value
                PocketMoney.charVars.lastTimeUsed = 0
                if PocketMoney.DEBUG then
                    d(string.format(
                        "PocketMoney:CreateSettingsPanel: Setting PocketMoneyGoldValue to %d for account-wide settings",
                        value))
                end
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                PocketMoney.charVars.PocketMoneyGoldValue = value
                PocketMoney.charVars.lastTimeUsed = 0
                if PocketMoney.DEBUG then
                    d(string.format(
                        "PocketMoney:CreateSettingsPanel: Setting PocketMoneyGoldValue to %d for character-specific settings",
                        value))
                end
            end
            handleSliderChange()
        end,
        disabled = function()
            return (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
                       "FORCE_CHARACTER_OFF") or (PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_DISABLED)
        end,
        default = PocketMoney.defaults.PocketMoneyGoldValue
    }, {
        type = "slider",
        name = L("TELVAR_VALUE"),
        tooltip = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return L("TELVAR_TOOLTIP")
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return L("CHAR_TELVAR_TOOLTIP")
            else
                return L("TELVAR_TOOLTIP")
            end
        end,
        min = 0,
        max = 100000,
        step = 100,
        getFunc = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return PocketMoney.savedVars.PocketMoneyTelVarValue or PocketMoney.defaults.PocketMoneyTelVarValue
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return PocketMoney.charVars.PocketMoneyTelVarValue or
                           PocketMoney.characterDefaults.PocketMoneyTelVarValue
            else
                return PocketMoney.defaults.PocketMoneyTelVarValue
            end
        end,
        setFunc = function(value)
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                PocketMoney.savedVars.PocketMoneyTelVarValue = value
                PocketMoney.charVars.lastTimeUsed = 0
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                PocketMoney.charVars.PocketMoneyTelVarValue = value
                PocketMoney.charVars.lastTimeUsed = 0
            end
            handleSliderChange()
        end,
        disabled = function()
            return (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
                       "FORCE_CHARACTER_OFF") or (PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_DISABLED)
        end,
        default = PocketMoney.defaults.PocketMoneyTelVarValue
    }, {
        type = "slider",
        name = L("AP_VALUE"),
        tooltip = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return L("AP_TOOLTIP")
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return L("CHAR_AP_TOOLTIP")
            else
                return L("AP_TOOLTIP")
            end
        end,
        min = 0,
        step = 1000,
        max = 5000000,
        getFunc = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return PocketMoney.savedVars.PocketMoneyAPValue or PocketMoney.defaults.PocketMoneyAPValue
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return PocketMoney.charVars.PocketMoneyAPValue or PocketMoney.characterDefaults.PocketMoneyAPValue
            else
                return PocketMoney.defaults.PocketMoneyAPValue
            end
        end,
        setFunc = function(value)
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                PocketMoney.savedVars.PocketMoneyAPValue = value
                PocketMoney.charVars.lastTimeUsed = 0
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                PocketMoney.charVars.PocketMoneyAPValue = value
                PocketMoney.charVars.lastTimeUsed = 0
            end
            handleSliderChange()
        end,
        disabled = function()
            return (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
                       "FORCE_CHARACTER_OFF") or (PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_DISABLED)
        end,
        default = PocketMoney.defaults.PocketMoneyAPValue
    }, {
        type = "slider",
        name = L("WRIT_VALUE"),
        tooltip = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return L("WRIT_TOOLTIP")
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return L("CHAR_WRIT_TOOLTIP")
            else
                return L("WRIT_TOOLTIP")
            end
        end,
        min = 0,
        max = 10000,
        step = 50,
        getFunc = function()
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                return PocketMoney.savedVars.PocketMoneyWritVoucherValue or
                           PocketMoney.defaults.PocketMoneyWritVoucherValue
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                return PocketMoney.charVars.PocketMoneyWritVoucherValue or
                           PocketMoney.characterDefaults.PocketMoneyWritVoucherValue
            else
                return PocketMoney.defaults.PocketMoneyWritVoucherValue
            end
        end,
        setFunc = function(value)
            local dropdownValue = getDropdownValue()
            if dropdownValue == POCKETMONEY_MODE_ACCOUNT_WIDE then
                PocketMoney.savedVars.PocketMoneyWritVoucherValue = value
                PocketMoney.charVars.lastTimeUsed = 0
            elseif dropdownValue == POCKETMONEY_MODE_CHARACTER then
                PocketMoney.charVars.PocketMoneyWritVoucherValue = value
                PocketMoney.charVars.lastTimeUsed = 0
            end
            handleSliderChange()
        end,
        disabled = function()
            return (PocketMoney.charVars.usePocketMoney == nil and PocketMoney.savedVars.forceUsePocketMoney ==
                       "FORCE_CHARACTER_OFF") or (PocketMoney.charVars.usePocketMoney == POCKETMONEY_MODE_DISABLED)
        end,
        default = PocketMoney.defaults.PocketMoneyWritVoucherValue
    }, {
        type = "header",
        name = L("GLOBAL_HEADER"),
        width = "full"
    }, {
        type = "colorpicker",
        name = L("MSG_COLOR"),
        tooltip = L("MSG_COLOR_TOOLTIP"),
        getFunc = function()
            return PocketMoney.savedVars.msgcolor.r, PocketMoney.savedVars.msgcolor.g, PocketMoney.savedVars.msgcolor.b
        end,
        setFunc = function(r, g, b, a)
            PocketMoney.savedVars.msgcolor.r = r
            PocketMoney.savedVars.msgcolor.g = g
            PocketMoney.savedVars.msgcolor.b = b
        end,
        default = PocketMoney.defaults.msgcolor,
        width = "half"
    },
    -- Force mode description
  {
        type = "header",
        name = L("FORCE_MODE_HEADER"),
        width = "full"
    },
    {
        type = "description",
        text = L("FORCE_MODE_DESCRIPTION"),
        width = "full"
    },
    -- Force buttons
    {
        type = "button",
        name = L("FORCE_ACCOUNT_WIDE_BTN"),
        tooltip = L("FORCE_BTN_TOOLTIP"),
        func = function()
            PocketMoney.savedVars.forceUsePocketMoney = "FORCE_ACCOUNT_WIDE"
            PocketMoney:SendMessage(L("FORCE_ACCOUNT_WIDE_MSG"))
            PlaySound(SOUNDS.POSITIVE_CLICK)
        end,
        width = "full"
    }, {
        type = "button",
        name = L("FORCE_CHARACTER_ON_BTN"),
        tooltip = L("FORCE_BTN_TOOLTIP"),
        func = function()
            PocketMoney.savedVars.forceUsePocketMoney = "FORCE_CHARACTER_ON"
            PocketMoney:SendMessage(L("FORCE_CHARACTER_ON_MSG"))
            PlaySound(SOUNDS.POSITIVE_CLICK)
        end,
        width = "full"
    }, {
        type = "button",
        name = L("FORCE_CHARACTER_OFF_BTN"),
        tooltip = L("FORCE_BTN_TOOLTIP"),
        func = function()
            PocketMoney.savedVars.forceUsePocketMoney = "FORCE_CHARACTER_OFF"
            PocketMoney:SendMessage(L("FORCE_CHARACTER_OFF_MSG"))
            PlaySound(SOUNDS.POSITIVE_CLICK)
        end,
        width = "full"
    }}

    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Pocket Money",
        displayName = L("SETTINGS_DISPLAY_NAME"),
        author = PocketMoney.author,
        version = PocketMoney.version,
        registerForRefresh = true
    })

    LibAddonMenu2:RegisterOptionControls(panelName, optionsTable)
end

--- BugFixes function to ensure saved variables are within expected ranges between different versions of the addon.
--- This is called during the initialization of the addon to ensure that the saved variables are in a valid state.
---@return void
function PocketMoney:BugFixes()
    -- Check if the msgcolor values are within the expected range (0 to 1) and fixes them if necessary.
    if not PocketMoney.savedVars.colorFix then
        if PocketMoney.savedVars.msgcolor.r > 1 then
            PocketMoney.savedVars.msgcolor.r = 1
        end
        if PocketMoney.savedVars.msgcolor.g > 1 then
            PocketMoney.savedVars.msgcolor.g = 1
        end
        if PocketMoney.savedVars.msgcolor.b > 1 then
            PocketMoney.savedVars.msgcolor.b = 1
        end
        PocketMoney.savedVars.colorFix = true
    end
end

--- Initialize the PocketMoney addon
--- This function sets up the saved variables, registers events, and creates the settings panel.
--- It is called when the addon is loaded.
---@return void
function PocketMoney:Initialize()
    -- Initialize the pocket money settings
    PocketMoney.savedVars = ZO_SavedVars:NewAccountWide("PocketMoneySavedVars", 1, nil, PocketMoney.defaults)
    PocketMoney.charVars = ZO_SavedVars:NewCharacterIdSettings("PocketMoneyCharVars", 1, nil,
        PocketMoney.characterDefaults)

    PocketMoney:BugFixes()
    PocketMoney:CreateSettingsPanel()

    -- Register for banker interaction
    EVENT_MANAGER:RegisterForEvent("PocketMoney_Banker", EVENT_OPEN_BANK, PocketMoney.OnBankerUsed)
    EVENT_MANAGER:RegisterForEvent("PocketMoney_Banker", EVENT_CLOSE_BANKER, PocketMoney.OnBankerClosed)

    -- Add the Use Pocket Money button to the banking keystrip
    table.insert(GAMEPAD_BANKING.mainKeybindStripDescriptor, PocketMoney.useButton)
end

--- Event handler for the add-on loaded event
--- This function initializes the PocketMoney addon when it is loaded.
--- It checks if the add-on name matches "PocketMoney" and then calls the Initialize function.
--- It unregisters the event after initialization to prevent it from being called again.
EVENT_MANAGER:RegisterForEvent("PocketMoney_Loaded", EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == "PocketMoney" then
        PocketMoney:Initialize()
        EVENT_MANAGER:UnregisterForEvent("PocketMoney_Loaded", EVENT_ADD_ON_LOADED)
    end
end)