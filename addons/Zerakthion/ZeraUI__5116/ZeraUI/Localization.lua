-- Menu localization only; identifiers, saved values and combat code stay stable.
local TR={}
local function add(lines)
    for en,tr in lines:gmatch("([^\n\t]+)\t([^\n]+)") do TR[en]=tr end
end
add([=[
Z'en: count method	Z'en: sayma yöntemi
All damage effects counts every player-owned damage-type effect on the selected target, including short or untimed effects. Longer than 1 s requires a duration over one second and an active Z'en mark. Neither method guarantees every counted effect is a true DoT.	Tüm hasar efektleri, kısa veya süresiz olanlar dahil seçili hedefte sana ait hasar türündeki bütün efektleri sayar. 1 sn'den uzun, bir saniyeden uzun süre ve aktif Z'en işareti gerektirir. İki yöntem de sayılan her efektin kesin olarak DoT olduğunu garanti etmez.
All damage effects	Tüm hasar efektleri
Longer than 1 s	1 sn'den uzun
Lower-left timer font size	Sol alt sayaç yazı boyutu
Lower-right timer font size	Sağ alt sayaç yazı boyutu
Corner timer	Köşe sayacı
Lower-left timer X	Sol alt sayaç X
Lower-left timer Y	Sol alt sayaç Y
Lower-right timer X	Sağ alt sayaç X
Lower-right timer Y	Sağ alt sayaç Y
Positive values move right; negative values move left.	Pozitif değerler sayacı sağa, negatif değerler sola kaydırır.
Positive values move down. 0 restores the default vertical position.	Pozitif değerler sayacı aşağı kaydırır. 0, varsayılan dikey konuma döndürür.
Long values automatically shrink to fit their half of the icon.	Uzun değerler ikonun kendi yarısına sığmak için otomatik küçülür.
Potion count font size	İksir miktarı yazı boyutu
Potion count position	İksir miktarı konumu
The count has a bounded size to keep it readable and prevent overlap.	Miktarın okunabilir kalması ve taşmaması için yazı boyutu sınırlandırılır.
Bottom	Alt
Top	Üst
Left	Sol
Top left	Sol üst
Top right	Sağ üst
Inside bottom	İç alt
Overload style	Overload stili
Gapless bright core	Kesintisiz parlak çekirdek
Show the gold flash when a skill is cast.	Yetenek kullanıldığında altın renkli flaş gösterir.
Weapon bar transition animation	Silah çubuğu geçiş animasyonu
Fade icon availability when changing weapon bars.	Silah çubuğu değişirken ikonların görünürlüğünü geçişli değiştirir.
Other animations	Diğer animasyonlar
Disable	Kapalı
Always show	Her zaman göster
Don't show	Gösterme
Long effects	Uzun efektler
Show effects that last longer than one minute.	Bir dakikadan uzun süren efektleri gösterir.
Include effects without a countdown. This can add many icons.	Sayacı olmayan efektleri de gösterir. Çok sayıda ikon ekleyebilir.
Golden loop when a set can proc	Set proclanabilir olunca golden loop
In combat, shows the skill-bar golden loop while a set's internal cooldown is over and it can proc again. Sets without a cooldown, or with one under 3 seconds, never loop.	Combat'ta, setin iç bekleme süresi bitip tekrar proclanabilir olduğunda yetenek çubuğundaki golden loop'u gösterir. Bekleme süresi olmayan ya da 3 saniyenin altında olan setlerde loop yanmaz.
Golden fade-out on set proc	Set proc olunca altın fade-out
Plays the skill-bar golden fade-out when a set procs, when a set without a cooldown starts, or when a resource or ultimate set reaches its threshold.	Set proc olduğunda, bekleme süresi olmayan bir set başladığında ya da resource/ultimate seti eşiğine ulaştığında yetenek çubuğundaki altın fade-out efektini oynatır.
Resource threshold glow	Resource eşiği parlaması
Fills the resource label of Coral Riptide, Bahsei's Mania and Martial Knowledge towards the full bonus. At the threshold it gets a gold edge with a light running around it.	Coral Riptide, Bahsei's Mania ve Martial Knowledge'ın resource etiketini tam bonusa doğru doldurur. Eşiğe gelince etiket altın bir kenar alır ve çevresinde bir ışık döner.
Use Rajdhani set style	Rajdhani set stilini uygula
Use the bundled Rajdhani Bold for set indicators and make secondary text easier to read. Your other HUD fonts stay unchanged.	Set göstergelerinde paketle gelen Rajdhani Bold yazı tipini kullanır ve alt yazıyı okunabilir yapar. Diğer HUD yazı tipleri değişmez.
Used when Synergy disappearance is set to Fade or Flash + fade, not Instant.	Sinerjinin kaybolma şekli Solarak veya Flaş + solma seçiliyken kullanılır; Anında seçeneğinde kullanılmaz.
Synergy use flash	Sinerji kullanım flaşı
Flash after a confirmed synergy use when instant hide is disabled.	Anında gizleme kapalıyken doğrulanan sinerji kullanımından sonra flaş gösterir.
Self buff expiry flash	Kendi buff bitiş flaşı
Self debuff expiry flash	Kendi debuff bitiş flaşı
Target buff expiry flash	Hedef buff bitiş flaşı
Target debuff expiry flash	Hedef debuff bitiş flaşı
Settings view	Ayar görünümü
While enabled, Zera UI turns ESO's Ability Bar Timers on and restores the previous value when disabled. If uninstalled while active, restore that ESO setting manually.	Zera UI etkinken ESO'nun Ability Bar Timers ayarını açar; devre dışı bırakılınca önceki değeri geri yükler. Eklenti etkinken kaldırılırsa ESO ayarını elle geri değiştir.
ESO fonts work without setup. Rajdhani Bold and SemiBold require their respective .slug files; missing fonts fall back to Univers 67.	ESO yazı tipleri kurulum gerektirmez. Rajdhani Bold ve SemiBold kendi .slug dosyalarını gerektirir; eksik yazı tipi yerine Univers 67 kullanılır.
Shows ESO and Rajdhani fonts at equal size. Missing Rajdhani falls back to Univers 67.	ESO ve Rajdhani yazı tiplerini aynı boyutta gösterir. Rajdhani eksikse Univers 67 kullanılır.
Off keeps the font below. An ESO font overrides it for the set widget. All fonts now use one label and native outlines, so this override no longer removes extra contour copies. Independent of buff/debuffs.	Kapalıyken aşağıdaki yazı tipi kullanılır. ESO yazı tipi seçilirse set göstergesinde onun yerine geçer. Artık tüm yazı tipleri tek metin ve doğal kontur kullanır; bu seçim ek kontur kopyalarını azaltmaz. Buff/debuff ayarından bağımsızdır.
Off keeps each grid's own font. An ESO font overrides all four grids and Off Balance. All fonts now use one label and native outlines, so this override no longer removes extra contour copies.	Kapalıyken her grup kendi yazı tipini kullanır. Seçilen ESO yazı tipi dört gruba ve Off Balance'a uygulanır. Artık tüm yazı tipleri tek metin ve doğal kontur kullanır; bu seçim ek kontur kopyalarını azaltmaz.
Text is limited by the bar height and available width, including room for shield values. Bar scale enlarges the whole bar and its text.	Yazı boyutu çubuğun yüksekliği ve kalkan değerine ayrılan alan dahil kullanılabilir genişlikle sınırlıdır. Çubuk ölçeği çubuğu ve yazısını birlikte büyütür.
Moves the resource numbers up (negative) or down (positive) inside the bars. Rajdhani is centered automatically; use this only for fine adjustment.	Kaynak sayılarını çubuğun içinde yukarı (eksi) veya aşağı (artı) kaydırır. Rajdhani otomatik ortalanır; bunu yalnızca ince ayar için kullan.
For skill durations, keep ESO's Ability Bar Timers enabled. The original ability bar can still be hidden.	Yetenek süreleri için ESO'nun Ability Bar Timers ayarını açık tut. Orijinal yetenek çubuğu yine gizlenebilir.
05  |  Set cooldowns & procs	05  |  Set süreleri ve proc'lar
06  |  Buffs, debuffs & Off Balance	06  |  Buff, debuff ve Off Balance
Simple	Basit
Advanced	Gelişmiş
Advanced settings stay active when hidden. Changing this view reloads the UI.	Gelişmiş ayarlar gizliyken de etkin kalır. Görünüm değişince arayüz yeniden yüklenir.
Ultimate & quickslot	Ultimate ve iksir
Set tracking & sounds	Set takibi ve sesler
Effect area settings	Efekt alanı ayarları
Edit effect area	Düzenlenecek efekt alanı
Select a group to edit. Each group retains its own independent settings.	Düzenlenecek grubu seç. Her grubun ayarları birbirinden bağımsızdır.
Highlight selected debuffs	Seçili debuff'ları vurgula
Available for debuff areas. Highlights debuffs with the selected color.	Debuff alanlarında kullanılabilir. Debuff'ları seçilen renkle vurgular.
Only my selected target effects	Yalnız kendi hedef efektlerim
Available for target areas. Excludes effects cast by other players.	Hedef alanlarında kullanılabilir. Diğer oyuncuların uyguladığı efektleri gizler.
Synergy disappearance	Sinerjinin kaybolma şekli
Instant	Anında
Fade	Solarak
Flash + fade	Flaş + solma
Flash requires a confirmed supported synergy use. The master animation switch disables fade and flash.	Flaş için desteklenen bir sinerji kullanımının doğrulanması gerekir. Ana animasyon anahtarı solma ve flaşı kapatır.
Include effects without a countdown. This can add many icons. Timed food, potions and buffs are always eligible.	Süresi olmayan efektleri de gösterir; ikon sayısı belirgin şekilde artabilir. Süreli yemek, iksir ve buff'lar her zaman gösterilebilir.
Show estimated internal cooldowns above the action bar after supported class ultimate-generation passives trigger. Only matching combat events are registered.	Desteklenen sınıf ultimate üretimi pasifleri tetiklendikten sonra tahmini iç bekleme sürelerini yetenek çubuğunun üstünde gösterir. Yalnızca ilgili savaş olayları dinlenir.
Off: the set widget keeps the font family below. Selecting an ESO font uses it for every set icon. ESO fonts draw the outline natively, without extra contour copies. If the effective font is already Univers 67, selecting it again gives no performance gain. Independent of the buff/debuff setting.	Kapalıyken set bileşeni aşağıdaki yazı tipini kullanır. Bir ESO yazı tipi seçilirse tüm set ikonlarında kullanılır ve kontur ek kopyalar olmadan çizilir. Etkin yazı tipi zaten Univers 67 ise tekrar seçmek performans kazandırmaz. Buff/debuff ayarından bağımsızdır.
Off: every grid keeps its own font below. Selecting an ESO font uses it for all four grids and Off Balance. ESO fonts draw the outline natively. If a grid's effective font is already Univers 67, selecting it again gives that grid no performance gain.	Kapalıyken her grup aşağıdaki kendi yazı tipini kullanır. Bir ESO yazı tipi seçilirse dört grubun ve Off Balance'ın tümünde kullanılır. ESO yazı tipleri konturu doğrudan çizer. Bir grubun etkin yazı tipi zaten Univers 67 ise tekrar seçmek o gruba performans kazandırmaz.
01  |  Quick setup	01  |  Hızlı kurulum
02  |  Action bar	02  |  Yetenek çubuğu
03  |  HUD widgets	03  |  HUD bileşenleri
04  |  Raid tracking	04  |  Raid takibi
05  |  Advanced	05  |  Gelişmiş
06  |  Set cooldowns & procs	06  |  Set süreleri ve proc'lar
07  |  Buffs, debuffs & Off Balance	07  |  Buff, debuff ve Off Balance
Layout, typography and skill appearance	Yerleşim, yazı tipi ve yetenek görünümü
Attributes, ultimate, potion, cast bar and synergy	Kaynak çubukları, ultimate, iksir, cast barı ve sinerji
Recipient counts, PA and class mechanics	Etkilenen oyuncu sayısı, PA ve sınıf mekanikleri
Per-skill overrides, fine tuning and diagnostic tools	Yetenek bazlı ayarlar, ince ayar ve tanılama araçları
Set tracking, icon design, filters and sound alerts	Set takibi, ikon tasarımı, filtreler ve sesli uyarılar
Four independent effect grids and Off Balance	Dört bağımsız efekt grubu ve Off Balance
Enable Zera UI	Zera UI'ı etkinleştir
Hide ESO's original action bar	ESO'nun orijinal yetenek çubuğunu gizle
Toggle HUD preview	HUD önizlemesini aç/kapat
Unlock HUD / Edit Mode	HUD kilidini aç / Düzenleme modu
Compare fonts	Yazı tiplerini karşılaştır
HUD scale	HUD ölçeği
HUD positioning & edit mode	HUD konumu ve düzenleme modu
Move HUD together (linked)	HUD'u birlikte taşı (bağlı)
Edit snap grid (pixels)	Düzenleme ızgarası (piksel)
Edit movement direction	Taşıma yönü
Horizontal offset	Yatay konum
Vertical offset	Dikey konum
Skill layout & appearance	Yetenek yerleşimi ve görünümü
Spacing & size	Aralık ve boyut
Skill icon size	Yetenek ikonu boyutu
Horizontal skill spacing	Yetenekler arası yatay boşluk
Vertical bar spacing	Çubuklar arası dikey boşluk
Skill grid X offset	Yetenek grubu X konumu
Skill grid Y offset	Yetenek grubu Y konumu
Icon state & counters	İkon durumu ve sayaçlar
Inactive icon desaturation	Pasif ikonun renk doygunluğu kaybı
Inactive icon opacity	Pasif ikonun opaklığı
Smooth icon style changes	Yumuşak ikon geçişleri
Show active bar arrow	Aktif çubuk okunu göster
Active bar arrow style	Aktif çubuk oku stili
Active bar position	Aktif çubuk konumu
Default (Front top)	Varsayılan (Ön üstte)
Active bar on top	Aktif çubuğu üstte göster
Active bar on bottom	Aktif çubuğu altta göster
Choose whether front/back rows stay fixed, or move the active weapon bar to the top or bottom row whenever you weapon swap.	Ön/arka çubuk satırlarının sabit kalmasını veya silah değiştirdiğinde aktif çubuğun her zaman üst ya da alt satıra taşınmasını seçer.
Hide idle skills on inactive bar	Pasif çubukta aktif olmayan yetenekleri gizle
On the inactive weapon bar, hide skill boxes that have no active timer, stack, toggle, proc, or warning animation.	Pasif silah çubuğunda aktif süresi, stack'i, toggle'ı, proc'u veya uyarı animasyonu olmayan yetenek kutucuklarını gizler.
Classic	Klasik
Large	Büyük
Double	Çift
Class cooldown font size	Sınıf bekleme süresi yazı boyutu
Leave Now warning	"Leave Now" uyarısı
Interact prompt [E]	Etkileşim bildirimi [E]
Tutorial tip	Öğretici ipucu
NPC Dialogue	NPC Diyalog Penceresi
Show keybind labels	Tuş atamalarını göster
Show Q, 1–5 and R labels without changing keybinds.	Tuş atamalarını değiştirmeden Q, 1–5 ve R etiketlerini göster.
Show skill tooltips	Yetenek açıklamalarını göster
Show the native skill tooltip when hovering over either bar or ultimate in cursor mode.	İmleç modunda ön veya arka çubuktaki yeteneklerin ve ultilerin üzerine gelince oyun açıklamasını göster.
Show stack counts	Stack sayısını göster
Show usage charges	Kullanım hakkı sayısını göster
Stack count badge	Stack sayacı rozeti
Show green duration fill	Yeşil süre dolgusunu göster
Duration fill color / opacity	Süre dolgusu rengi / opaklığı
Glow for toggled skills	Açık kalan yetenekleri parlat
Toggle glow intensity	Toggle parlama yoğunluğu
Availability	Kullanılabilirlik
Darken unusable skills	Kullanılamayan yetenekleri karart
Darken low-resource skills	Kaynak yetersizse karart
Darken corpse-required skills	Ceset gerektiren yetenekleri karart
Darken skills without valid target	Geçerli hedef yoksa yeteneği karart
Unusable skill brightness	Kullanılamayan yetenek parlaklığı
Unusable skill opacity	Kullanılamayan yetenek opaklığı
Necromancer: Nothing Wasted	Necromancer: Nothing Wasted
Text, timers & corner counters	Yazılar, süreler ve köşe sayaçları
Skill corner counter sizes	Yetenek köşesi sayaç boyutları
Passive and auxiliary badge font size	Pasif ve yardımcı rozet yazı boyutu
Skill and toggle glow	Yetenek ve toggle parlamaları
Powerful Assault	Powerful Assault
Set appearance, text & colors	Set görünümü, yazı ve renkler
Class passives & procs	Sınıf pasifleri ve proc'lar
Class cooldowns and procs	Sınıf bekleme süreleri ve proc'lar
Vampire	Vampire
Arcanist	Arcanist
Necromancer	Necromancer
Dragonknight	Dragonknight
Show Nothing Wasted on Siphon	Siphon'da Nothing Wasted göster
Nothing Wasted decay warning	Nothing Wasted bitiş uyarısı
Nothing Wasted warning seconds	Nothing Wasted uyarı süresi (sn)
Font family & outline	Yazı tipi ve kontur
Duration font size	Süre yazı boyutu
Font family	Yazı tipi
Duration outline	Süre yazısı konturu
Text sizes, colors & warning thresholds	Yazı boyutları, renkler ve uyarılar
Color timers orange/red near expiration	Süre bitiminde turuncu/kırmızı sayaç
Stack font size	Stack yazı boyutu
Secondary timer font size	İkinci sayaç yazı boyutu
Keybind font size	Tuş etiketi yazı boyutu
Soon warning (seconds)	Yaklaşan bitiş uyarısı (sn)
Last warning (seconds)	Son bitiş uyarısı (sn)
Show decimals below (seconds)	Ondalık gösterim eşiği (sn)
Default timer color	Varsayılan sayaç rengi
Soon warning color	Yaklaşan bitiş rengi
Final warning color	Son uyarı rengi
Stack counter color	Stack sayacı rengi
Usage charge color	Kullanım hakkı rengi
Second effect color	İkinci efekt rengi
Third effect color	Üçüncü efekt rengi
Skill glow animations	Yetenek parlama animasyonları
Gold cast / synergy animations	Altın renkli cast / sinerji animasyonları
Pressed button effect	Basılan tuş efekti
The skill icon briefly sinks into its frame with a pale edge when you press it, so you can see which button you used.	Bir skill'e bastığında ikon kısa süre çerçevesinin içine çöker ve kenarı açık renkte parlar; hangi tuşa bastığını görürsün.
Gold flash when an effect expires	Efekt bitince altın parlama
Continuous gold border	Sürekli altın çerçeve
Gold loop near expiration	Bitişe yakın dönen altın ışık
Gold loop warning (seconds)	Altın ışık uyarısı (sn)
Gold loop at stack threshold	Stack eşiğinde dönen altın ışık
Gold loop stack threshold	Altın ışık stack eşiği
Gold loop revolution (ms)	Altın ışık tur süresi (ms)
Gold loop on inactive bar	Pasif çubukta altın ışık
Cast and expiration flash	Cast ve bitiş parlaması
Press flash duration (ms)	Tuş parlaması süresi (ms)
Expiration flash duration (ms)	Bitiş parlaması süresi (ms)
Glow intensity	Parlama yoğunluğu
Glow tint	Parlama rengi
Interior flash intensity	İç parlama yoğunluğu
Replay sample glow animations	Örnek parlamaları tekrar oynat
Toggle Pulse Effect	Toggle nabız efekti
Repeat pulse while toggled on	Toggle açıkken tekrarlayan parlama
Toggle pulse period (ms)	Toggle parlama periyodu (ms)
Toggle glow color	Toggle parlama rengi
Skill families	Yetenek grupları
Per-skill animations & stack thresholds	Yetenek bazlı animasyon ve stack eşikleri
Animation skill slot	Animasyonu ayarlanacak yetenek
Skill cast flash	Yetenek kullanım parlaması
Skill expiration flash	Yetenek bitiş parlaması
Skill expiration gold loop	Yetenek bitişinde altın ışık
Skill stack gold loop	Stack için altın ışık
Skill loop on inactive bar	Pasif çubukta yetenek ışığı
Skill stack threshold (0 = Global)	Yetenek stack eşiği (0 = Genel)
Skill expiration warning (0 = Global)	Yetenek bitiş uyarısı (0 = Genel)
Save skill animations	Yetenek animasyonlarını kaydet
Restore skill animation defaults	Yetenek animasyonlarını sıfırla
Refresh animation skill	Seçili yeteneği yenile
Group buffs & target counts	Grup buff'ları ve hedef sayısı
Show target count	Hedef sayısını göster
Show count for one target	Tek hedefin sayısını göster
Show one group buff recipient	Tek buff alan oyuncuyu göster
Group members only (friendly recipients)	Yalnız grup üyeleri (dost hedefler)
Multi-target timer expiration	Çoklu hedef zamanlayıcısı
Multi-target blacklist skill	Hedef sayısı hariç tutulacak yetenek
Hide target count for selected skill	Seçili yeteneğin hedef sayısını gizle
Target count font size	Hedef sayısı yazı boyutu
Target count color	Hedef sayısı rengi
Procs & class cooldowns	Proc'lar ve sınıf bekleme süreleri
Class ultimate-generation cooldowns	Sınıf ultimate üretim bekleme süreleri
Strike from the Shadows timer	Strike from the Shadows sayacı
Arcanist mastery timer location	Arcanist mastery sayaç konumu
Enable proc highlight	Proc vurgusunu etkinleştir
Pulse proc highlight	Proc vurgusunu yanıp söndür
Proc glow color	Proc parlama rengi
Set cooldowns & procs	Set bekleme süreleri ve proc'lar
Enable set cooldown tracker	Set takipçisini etkinleştir
Lock set widget position	Set grubu konumunu kilitle
Show outside combat	Savaş dışında göster
Show ready set icons	Hazır set ikonlarını göster
Show off-bar set icons	Diğer çubuktaki setleri göster
Show cooldown during active effects	Aktif efekt sırasında bekleme süresini göster
Icon layout	İkon dizilimi
Set icon size (pixels)	Set ikonu boyutu (piksel)
Set widget scale	Set grubu ölçeği
Set icon spacing	Set ikonları arası boşluk
Set X position (screen center)	Set X konumu (ekran merkezi)
Set Y position (screen center)	Set Y konumu (ekran merkezi)
Toggle sample icons	Örnek ikonları aç/kapat
Reset set widget position	Set grubu konumunu sıfırla
Set appearance & text	Set görünümü ve yazılar
Set font family	Set yazı tipi
Set font outline	Set yazı konturu
Set countdown font size	Set sayaç yazı boyutu
Set countdown X offset	Set sayaç X konumu
Set countdown Y offset	Set sayaç Y konumu
Set decimal countdown threshold	Set ondalık sayaç eşiği
Show set stacks & counts	Set stack ve sayıları göster
Set stack font size	Set stack yazı boyutu
Set secondary timer font size	Set ikinci sayaç yazı boyutu
Show set names	Set isimlerini göster
Set name position	Set ismi konumu
Set name background	Set ismi arka planı
Set name font size	Set ismi yazı boyutu
Set progress fill	Set ilerleme dolgusu
Set glow effects	Set parlama efektleri
Set icon frame	Set ikon çerçevesi
Desaturate cooldown / off-bar icons	Beklemedeki / diğer çubuktaki ikonları soluklaştır
Set colors & transparency	Set renkleri ve saydamlık
Color set countdown by state	Set sayacını duruma göre renklendir
Color set frame by state	Set çerçevesini duruma göre renklendir
Set active color	Aktif set rengi
Set cooldown color	Set bekleme süresi rengi
Set ready color	Hazır set rengi
Set resource value color	Set kaynak değeri rengi
Set off-bar color	Diğer çubuktaki set rengi
Set fixed countdown color	Set sabit sayaç rengi
Set stack color	Set stack rengi
Set secondary timer color	Set ikinci sayaç rengi
Set name color	Set ismi rengi
Set active opacity	Aktif set opaklığı
Set cooldown opacity	Beklemedeki set opaklığı
Set ready opacity	Hazır set opaklığı
Set resource value opacity	Set kaynak değeri opaklığı
Set off-bar opacity	Diğer çubuktaki set opaklığı
Individual set filters & sizes	Set bazında filtre ve boyut
Set filter mode	Set filtre modu
Select set	Set seç
Add selected set to filter list	Seçili seti filtre listesine ekle
Selected set icon size	Seçili set ikonu boyutu
Selected set timer X offset	Seçili set sayaç X konumu
Selected set timer Y offset	Seçili set sayaç Y konumu
Selected set active color	Seçili set aktif rengi
Selected set cooldown color	Seçili set bekleme rengi
Use global colors for selected set	Seçili sette genel renkleri kullan
Selected set proc sound	Seçili set proc sesi
Selected set ready sound	Seçili set hazır sesi
Refresh selectable sets	Seçilebilir setleri yenile
Clear set filter list	Set filtre listesini temizle
Reset selected set overrides	Seçili set ayarlarını sıfırla
Set sounds & special mechanics	Set sesleri ve özel mekanikler
Set proc sound	Set proc sesi
Test set proc sound	Set proc sesini test et
Set ready sound	Set hazır sesi
Test set ready sound	Set hazır sesini test et
Z'en: focus single boss	Z'en: tek boss'a odaklan
Roaring Opportunist: predicted duration	Roaring Opportunist: tahmini süre
Roaring Opportunist: affected recipients	Roaring Opportunist: etkilenen oyuncular
Pearls / Esoteric: resource percentage	Pearls / Esoteric: kaynak yüzdesi
Pearls / Esoteric: proc count	Pearls / Esoteric: proc sayısı
Martial Knowledge: stamina percentage	Martial Knowledge: stamina yüzdesi
]=])
add([=[
Layout	Yerleşim
Reload UI	Arayüzü yeniden yükle
Zera UI 1.0.3  ·  /zera  ·  /zeraset  ·  Settings marked with a warning icon apply after a UI reload.	Zera UI 1.0.3  ·  /zera  ·  /zeraset  ·  Uyarı ikonlu ayarlar arayüz yeniden yüklenince uygulanır.
Applies after the UI is reloaded. / Arayüz yeniden yüklendikten sonra uygulanır.	Applies after the UI is reloaded. / Arayüz yeniden yüklendikten sonra uygulanır.
01  |  General	01  |  Genel
02  |  Skill bar	02  |  Skill barı
03  |  Animations	03  |  Animasyonlar
04  |  HUD widgets	04  |  HUD parçaları
05  |  Tracking	05  |  Takip
06  |  Sets	06  |  Setler
07  |  Buffs & debuffs	07  |  Buff ve debuff'lar
08  |  Tools	08  |  Araçlar
Icons, timers, counters and availability	İkonlar, süreler, sayaçlar ve kullanılabilirlik
Press feedback, gold effects and glows	Basma efekti, altın efektler ve parlamalar
Resource bars, ultimate, potion, cast bar and synergy	Kaynak barları, ultimate, iksir, cast barı ve sinerji
Group buffs and class mechanics	Grup buff'ları ve class mekanikleri
Set cooldowns, appearance, filters and sounds	Set cooldown'ları, görünüm, filtreler ve sesler
Four effect areas and the Off Balance tracker	Dört efekt alanı ve Off Balance takibi
Per-skill overrides, custom tracking and diagnostics	Skill bazında ayarlar, özel takip ve tanılama araçları
Timers & text	Süreler ve yazılar
Counters & badges	Sayaçlar ve rozetler
Fill & availability	Dolgu ve kullanılabilirlik
Skill animations	Skill animasyonları
Gold border	Altın çerçeve
Toggle & proc glow	Toggle ve proc parlaması
Resource bars	Kaynak barları
Ultimate & potion	Ultimate ve iksir
Class mechanics	Class mekanikleri
All classes	Tüm class'lar
Set tracking	Set takibi
Set appearance & colors	Set görünümü ve renkleri
Set filters & sounds	Set filtreleri ve sesleri
Special mechanics	Özel mekanikler
Colors	Renkler
Sounds	Sesler
Individual sets	Tek tek setler
Buff & debuff general	Buff ve debuff genel
Effect areas	Efekt alanları
Move attributes individually	Kaynak çubuklarını ayrı taşı
Bar scale	Çubuk ölçeği
Bar width	Çubuk genişliği
Gap between bars	Çubuklar arası boşluk
Text size	Yazı boyutu
Text vertical offset	Yazı dikey konumu
Attribute font	Kaynak yazı tipi
Attribute text outline	Kaynak yazı konturu
Value format	Değer biçimi
Show percentage next to value	Değerin yanında yüzdeyi göster
Show damage shield value	Hasar kalkanı değerini göster
Red text at 25% or lower	%25 veya altında kırmızı yazı
Use reference pyramid	Referans piramit düzenini kullan
Group X offset	Grup X konumu
Group Y offset	Grup Y konumu
Edit attribute positions	Kaynak çubuklarının konumunu düzenle
Reset attribute positions	Kaynak konumlarını sıfırla
Ultimate meters	Ultimate göstergeleri
Pulse when ultimate is ready	Ultimate hazırken yanıp sön
Metallic ring bloom	Metalik halka parlaması
Show ultimate active duration	Ultimate aktif süresini göster
Show inactive ultimate	Pasif çubuğun ultimate'ini göster
Show ultimate costs	Ultimate maliyetlerini göster
Ultimate size	Ultimate boyutu
Ultimate X offset	Ultimate X konumu
Ultimate Y offset	Ultimate Y konumu
Ultimate points font	Ultimate puanı yazı boyutu
Ultimate cost font	Ultimate maliyeti yazı boyutu
Ultimate duration font	Ultimate süre yazı boyutu
Ultimate duration Y offset	Ultimate süre Y konumu
Ultimate ring color	Ultimate halka rengi
Active ultimate ring color	Aktif ultimate halka rengi
Affordable ultimate cost color	Yeterli ultimate puanı rengi
Unaffordable ultimate cost color	Yetersiz ultimate puanı rengi
Potion / quickslot	İksir / hızlı yuva
Show potion / quickslot meter	İksir / hızlı yuva göstergesini göster
Quickslot size	Hızlı yuva boyutu
Quickslot X offset	Hızlı yuva X konumu
Quickslot Y offset	Hızlı yuva Y konumu
Quickslot timer font	Hızlı yuva sayaç yazı boyutu
Quickslot ring color	Hızlı yuva halka rengi
Cast / channel / global cooldown bar	Cast / channel / genel bekleme çubuğu
Show global cooldown bar	Genel bekleme çubuğunu göster
Show instant skill global cooldown	Anlık yeteneklerde genel beklemeyi göster
Show channeled abilities	Channel yeteneklerini göster
Show cast-time abilities	Cast süreli yetenekleri göster
GCD size	GCD boyutu
GCD X offset	GCD X konumu
GCD Y offset	GCD Y konumu
GCD font size	GCD yazı boyutu
GCD countdown font size	GCD sayaç yazı boyutu
GCD fill tint	GCD dolgu rengi
Channel fill tint	Channel dolgu rengi
Synergy appearance & animations	Sinerji görünümü ve animasyonları
Show synergy alert	Sinerji uyarısını göster
Enable synergy fade animation	Sinerji geçiş animasyonunu etkinleştir
Instant hide on synergy use / expiry	Sinerji kullanıldığında / bittiğinde anında gizle
Skill-style flash on synergy use	Sinerji kullanımında yetenek tarzı parlama
Show synergy name	Sinerji ismini göster
Show synergy key	Sinerji tuşunu göster
Synergy key label	Sinerji tuş etiketi
Synergy size	Sinerji boyutu
Synergy X offset	Sinerji X konumu
Synergy Y offset	Sinerji Y konumu
Synergy name font	Sinerji ismi yazı boyutu
Synergy key font	Sinerji tuşu yazı boyutu
Synergy opacity	Sinerji opaklığı
Fade in (ms)	Belirme süresi (ms)
Fade out (ms)	Kaybolma süresi (ms)
Preview synergy appearance	Sinerji görünümünü önizle
Quick swaps	Hızlı konum değişimi
Skill timer	Yetenek sayacı
Advanced tracking engine	Gelişmiş takip sistemi
Landslide / Inexorable Descent on Whip	Whip üzerinde Landslide / Inexorable Descent
External heal application count	Dışarıdan gelen iyileştirme sayısı
Advanced tracking skill	Gelişmiş takip yeteneği
Timer policy effect entry	Sayaç kuralı efekt yuvası
Skill timer selection	Yetenek sayacı seçimi
Allow external buff timer for selected skill	Seçili yetenek için dış buff sayacına izin ver
Restore selected skill tracking policy	Seçili yetenek takip kuralını sıfırla
Custom skill & proc tracking	Özel yetenek ve proc takibi
Skill slot	Yetenek yuvası
Effect entry	Efekt yuvası
Effect ID	Efekt ID'si
Fallback duration (seconds)	Yedek süre (saniye)
Tracking mode	Takip modu
Save tracking rule	Takip kuralını kaydet
Remove selected effect	Seçili efekti kaldır
Restore default tracking	Varsayılan takibi geri yükle
Proc tracking for selected skill	Seçili yetenek için proc takibi
Proc effect ID	Proc efekt ID'si
Save proc rule	Proc kuralını kaydet
Disable proc for selected skill	Seçili yetenek için proc takibini kapat
Restore default proc mapping	Varsayılan proc eşlemesini geri yükle
Refresh selected skill	Seçili yeteneği yenile
Effect ID Finder	Efekt ID bulucu
Start recording (30 seconds)	Kaydı başlat (30 saniye)
Stop recording	Kaydı durdur
Refresh recording results	Kayıt sonuçlarını yenile
Recorded result number	Kayıt sonuç numarası
Copy result to selected effect entry	Sonucu seçili efekt yuvasına kopyala
Reset appearance	Görünümü sıfırla
Reset appearance to defaults	Varsayılan görünüme dön
Buff and debuff appearance	Buff ve debuff görünümü
Show effects outside combat	Savaş dışında efektleri göster
Hide matching native buff containers	İlgili orijinal efekt gruplarını gizle
Pause hidden native buff containers	Gizlenen orijinal buff gruplarını duraklat
Performance. A hidden original buff bar still updates every icon each frame. This also stops that work while a custom grid replaces it. No ESO setting is changed, and the original bar resumes as soon as it is shown again. Turn off if another addon relies on the original buff bar.	Performans. Gizlenen orijinal buff çubuğu her karede tüm ikonlarını güncellemeye devam eder. Bu seçenek, özel grup onun yerini alırken o işi de durdurur. Hiçbir ESO ayarı değişmez; orijinal çubuk yeniden gösterildiği anda çalışmaya devam eder. Başka bir eklenti orijinal buff çubuğunu kullanıyorsa kapat.
Game font for all buff/debuff grids (performance)	Tüm buff/debuff grupları için oyun yazı tipi (performans)
Off: every grid keeps its own font below. Selecting an ESO font uses it for all four grids and Off Balance. ESO fonts draw the outline natively, so each icon needs 7 controls instead of 19 and each number is written once instead of nine times. Recommended if you prefer performance over the custom font.	Kapalı: her grup aşağıdaki kendi yazı tipini kullanır. Bir ESO yazı tipi seçersen dört grubun tamamında ve Off Balance'ta o kullanılır. ESO yazı tipleri konturu kendisi çizer; böylece her ikon 19 yerine 7 kontrol kullanır ve her sayı dokuz yerine bir kez yazılır. Özel yazı tipi yerine performansı tercih ediyorsan önerilir.
Game font for set cooldowns (performance)	Set süreleri için oyun yazı tipi (performans)
Off: the set widget keeps the font family below. Selecting an ESO font uses it for every set icon. ESO fonts draw the outline natively, without extra contour copies. Independent of the buff/debuff setting.	Kapalı: set bileşeni aşağıdaki yazı tipini kullanır. Bir ESO yazı tipi seçersen tüm set ikonlarında o kullanılır. ESO yazı tipleri konturu ek kopya olmadan kendisi çizer. Buff/debuff ayarından bağımsızdır.
Turn off ESO's own action bar timers while hidden	Gizliyken ESO'nun kendi yetenek çubuğu sayaçlarını kapat
Performance option, off by default. ESO keeps running its own skill timers under the hidden original bar. This switches the ESO setting 'Action bar timers' off while Zera UI replaces the bar, and restores your previous value when you turn this option, the replacement or Zera UI off. If you uninstall Zera UI while this is on, re-enable the timers in ESO's Combat settings.	Performans seçeneği, varsayılan olarak kapalı. ESO, gizlenen orijinal çubuğun altında kendi yetenek sayaçlarını çalıştırmaya devam eder. Bu seçenek, Zera UI çubuğun yerini alırken ESO'nun 'Yetenek çubuğu sayaçları' ayarını kapatır; bu seçeneği, çubuk değiştirmeyi veya Zera UI'ı kapattığında önceki değerini geri yükler. Bu açıkken Zera UI'ı kaldırırsan sayaçları ESO'nun Savaş ayarlarından yeniden aç.
Preview enabled effect grids	Aktif efekt gruplarını önizle
Self Buffs	Kendi buff'ların
Self Debuffs	Kendi debuff'ların
Target Buffs	Hedef buff'ları
Target Debuffs	Hedef debuff'ları
Set Cooldowns	Set süreleri
Player Interaction	Oyuncu etkileşimi
Off Balance tracker	Off Balance takipçisi
Enable Off Balance icon	Off Balance ikonunu etkinleştir
Lock Off Balance position	Off Balance konumunu kilitle
Exclude Off Balance from target grid	Off Balance'ı hedef efekt grubundan çıkar
Show when Off Balance is ready	Off Balance hazırken göster
Estimate missing Off Balance immunity	Eksik Off Balance bağışıklığını tahmin et
Off Balance icon size (pixels)	Off Balance ikon boyutu (piksel)
Off Balance horizontal position	Off Balance yatay konum
Off Balance vertical position	Off Balance dikey konum
Off Balance timer font scale	Off Balance sayaç yazı ölçeği
Off Balance font family	Off Balance yazı tipi
Off Balance font outline	Off Balance yazı konturu
Off Balance countdown fill	Off Balance sayaç dolgusu
Off Balance active color	Off Balance aktif rengi
Off Balance immunity color	Off Balance bağışıklık rengi
Off Balance ready color	Off Balance hazır rengi
Off Balance expiry flash	Off Balance bitiş parlaması
Off Balance flash threshold (seconds)	Off Balance parlama eşiği (sn)
Free	Serbest
Horizontal	Yatay
Vertical	Dikey
Pyramid	Piramit
Curved	Dikey kavis
Curved layout	Dikey kavis düzeni
Arc size	Yay boyutu
Space between arcs	Yaylar arası mesafe
Arc percentage size	Yay yüzde boyutu
Arc value size	Yay değer boyutu
Shield opacity	Kalkan opaklığı
Opacity of the shield over the health arc. Lower it to see your health under a shield.	Can yayının üstündeki kalkanın opaklığı. Kalkan varken canını görmek için düşür.
Resource arcs	Kaynak yayları
Size of the arcs and their text. Text is resized, not stretched.	Yayların ve yazılarının boyutu. Yazılar gerilmez, yeniden boyutlanır.
Distance between the two arcs. Both move apart equally; also in Edit Mode.	İki yay arasındaki mesafe. İkisi eşit uzaklaşır; Edit Mode'dan da ayarlanır.
Percentages next to the arcs. Arc size scales it too.	Yayların yanındaki yüzdeler. Yay boyutu bunu da ölçekler.
Values next to the arcs, e.g. 38.5k. Arc size scales it too.	Yayların yanındaki değerler, örn. 38.5k. Yay boyutu bunu da ölçekler.
Stacked	Üst üste
Native	Orijinal
HUD font	HUD yazı tipi
HUD outline	HUD konturu
thick-outline	Kalın kontur
outline	Kontur
thin-outline	İnce kontur
normal	Normal
shadow	Gölge
soft-shadow-thin	İnce yumuşak gölge
soft-shadow-thick	Kalın yumuşak gölge
Global	Genel
On	Açık
Off	Kapalı
Both	İkisi
None	Yok
First to expire	İlk biten
Last to expire	Son biten
Global default	Genel varsayılan
Current target	Mevcut hedef
All effects	Tüm efektler
1 - Main	1 - Ana
2 - Cyan	2 - Camgöbeği
3 - Gold	3 - Altın
Right	Sağ
Above	Üst
Below	Alt
Right to left	Sağdan sola
Left to right	Soldan sağa
Shortest first	En kısa süre önce
Game order	Oyun sırası
All equipped	Kuşanılan tüm setler
Hide selected	Seçilileri gizle
Only selected	Yalnız seçililer
Short	Kısa
Full	Tam
Full / Max	Tam / Maksimum
auto	Otomatik
effect	Gerçek efekt
cast	Kullanım
ABILITY_SYNERGY_READY	Sinerji hazır
ABILITY_ULTIMATE_READY	Ultimate hazır
ABILITY_SLOTTED	Yetenek kuşanıldı
ACHIEVEMENT_AWARDED	Başarım kazanıldı
CHAMPION_POINT_GAINED	Şampiyon puanı kazanıldı
DUEL_START	Düello başlangıcı
DISPLAY_ANNOUNCEMENT	Duyuru
]=])

-- The four independent grids generate their option names from these suffixes.
local gridLabels={ ["Effect area"]="Efekt alanı",["Self buffs"]="Kendi buff'ların",["Self debuffs"]="Kendi debuff'ların",
    ["Target buffs"]="Hedef buff'ları",["Target debuffs"]="Hedef debuff'ları" }
local suffixes={
    [" permanent effects"]=" — kalıcı efektler",[" icons per row"]=" — satır başına ikon",
    [" horizontal growth"]=" — büyüme yönü",[" single row"]=" — tek satır",[" sort order"]=" — sıralama",
    [" highlight and fill color"]=" — vurgu ve dolgu rengi",[" fill color"]=" — dolgu rengi",
    [" icon size (pixels)"]=" — ikon boyutu (piksel)",[" icon gap"]=" — ikon aralığı",
    [" horizontal position"]=" — yatay konum",[" vertical position"]=" — dikey konum",
    [" font family"]=" — yazı tipi",[" font outline"]=" — yazı konturu",
    [" timer font scale"]=" — sayaç yazı ölçeği",[" stack font scale"]=" — stack yazı ölçeği",
    [" show stacks"]=" — stack sayısını göster",[" countdown fill"]=" — sayaç dolgusu",
    [" expiry flash"]=" — bitiş parlaması",[" flash threshold (seconds)"]=" — parlama eşiği (sn)",
}
for label,tr in pairs(gridLabels) do
    TR["Enable "..label]=tr.." — etkinleştir"
    TR["Lock "..label.." position"]=tr.." — konumu kilitle"
    TR["Highlight "..label]=tr.." — vurgula"
    TR["Only my "..label:lower()]=tr.." — yalnız kendi uyguladıklarım"
    for suffix,translated in pairs(suffixes) do TR[label..suffix]=tr..translated end
end
for i=1,5 do TR["Front "..i]="Ön "..i; TR["Back "..i]="Arka "..i end
TR["Front Ult"]="Ön Ultimate"; TR["Back Ult"]="Arka Ultimate"

add([=[
Combat HUD  /  Appearance  /  Tracking	Savaş HUD'u  /  Görünüm  /  Takip
Native keybinds and casting remain available.	Orijinal tuş atamaları ve yetenek kullanımı çalışmaya devam eder.
Inspect the HUD with sample values outside combat.	Savaş dışında örnek değerlerle HUD'u incele.
Move the HUD or individual widgets visually.	HUD'u veya bileşenleri görsel olarak taşı.
Open the interactive Powerful Assault preview.	Etkileşimli Powerful Assault önizlemesini aç.
Compare native and installed fonts at the same size.	Orijinal ve kurulu yazı tiplerini aynı boyutta karşılaştır.
On: drag any HUD element to move the entire addon. Off: drag each element independently.	Açık: herhangi bir HUD öğesini sürükleyerek tümünü taşı. Kapalı: her öğeyi bağımsız taşı.
Weapon swaps always apply both rows' colors instantly to prevent ghosting.	Silah değişiminde görüntü izlerini önlemek için iki sıranın renkleri anında uygulanır.
Separate counters for charges, placed traps, devices and multi-phase skills. They do not activate the stack threshold glow.	Yük, tuzak, cihaz ve çok aşamalı yetenekler için ayrı sayaçlar. Stack eşiği parlamasını tetiklemezler.
Adds a beveled cyan badge; turns gold at the configured stack threshold.	Camgöbeği rozet ekler; ayarlanan stack eşiğinde altın rengine döner.
Shows an active edge instead of the green fill. Also applies to Overload's ultimate ring.	Yeşil dolgu yerine aktif kenar gösterir. Overload ultimate halkasına da uygulanır.
Master switch for weapon compatibility, resource, corpse and valid-target checks.	Silah uyumluluğu, kaynak, ceset ve geçerli hedef kontrollerinin ana ayarı.
Only confirmed magicka, stamina or health cost failures.	Yalnız doğrulanan magicka, stamina veya can yetersizliğinde.
Retain the last confirmed state of corpse skills on their own bar.	Ceset gerektiren yeteneklerin son doğrulanan durumunu kendi çubuğunda korur.
Only strict unit-target abilities; self and ground skills ignore misleading target flags.	Yalnız doğrudan hedef gerektiren yetenekler; kendi üzerinde ve alan yeteneklerinde yanıltıcı hedef işaretleri yok sayılır.
Separate passive stack and 12-second decay timer; supports both morphs and base skill.	Ayrı pasif stack ve 12 saniyelik azalma sayacı; temel yeteneği ve iki morph'u destekler.
Gold loop before the passive decays, even on the inactive bar.	Pasif azalmadan önce altın döngü; diğer çubukta da çalışır.
ESO fonts work without setup. Rajdhani Bold requires a converted .slug; run fonts/Install-Rajdhani.bat if desired.	ESO yazı tipleri kurulum gerektirmez. Rajdhani Bold dönüştürülmüş .slug gerektirir; istersen fonts/Install-Rajdhani.bat dosyasını çalıştır.
Default font: Univers 67 (built into ESO).	Varsayılan yazı tipi: Univers 67 (ESO'ya dahildir).
Thick-outline becomes a thinner outline on the small GCD title and countdown; all other styles apply unchanged.	Kalın kontur küçük GCD başlığında ve sayacında incelir; diğer stiller değişmez.
Orange at 3 seconds or less, red at 1 second or less by default.	Varsayılan olarak 3 saniye veya altında turuncu, 1 saniye veya altında kırmızı.
Flash once when a tracked skill timer reaches zero or is removed.	Takip edilen yetenek süresi sıfırlandığında veya kaldırıldığında bir kez parlar.
A bright gold light travels clockwise around the skill border while its main timer is about to expire.	Ana sayaç bitmek üzereyken yetenek kenarında saat yönünde parlak altın ışık döner.
Keep the same gold border animation while the skill has at least the selected number of stacks.	Yetenek seçilen stack sayısına ulaştığında altın kenar animasyonu sürer.
A persistent glow with a gentle repeating pulse; does not replay the cast burst.	Hafifçe tekrarlanan sürekli parlama; kullanım animasyonunu yeniden başlatmaz.
Select a skill currently slotted on either bar. Overrides follow its ability ID and exact Scribing combination, not its slot. Global inherits the current defaults. The master animation switch still disables all gold effects. Banner uses toggle glow only; its transient aura stack count is not displayed.	İki çubuktan birindeki yeteneği seç. Özel ayarlar slota değil yetenek ID'sine ve Scribing kombinasyonuna bağlıdır. Genel seçeneği varsayılanları kullanır. Ana animasyon ayarı tüm altın efektleri kapatır. Banner yalnız toggle parlaması kullanır; geçici aura stack'i gösterilmez.
The badge becomes gold and the stack loop triggers at this count. Set 0 to follow the global threshold.	Bu sayıda rozet altın olur ve stack döngüsü başlar. Genel eşiği kullanmak için 0 seç.
Seconds remaining before the gold border starts. Set 0 to follow the global duration warning.	Altın kenar başlamadan önce kalan saniye. Genel süre uyarısı için 0 seç.
|cEBC773Recipient count|r  ·  Allies your skill has affected, excluding yourself. Frost Cloak, Molten Weapons, group heals and other supported buffs use confirmed applications.	|cEBC773Etkilenen oyuncu sayısı|r  ·  Kendin hariç yeteneğinden etkilenen müttefikler. Frost Cloak, Molten Weapons, grup iyileştirmeleri ve desteklenen buff'lar doğrulanmış uygulamaları kullanır.
Counts distinct enemies or recipients of your supported heals, shields and group buffs.	Farklı düşmanları veya desteklenen heal, kalkan ve grup buff'larından etkilenen oyuncuları sayar.
Show 1 as well as larger counts.	Yüksek sayılarla birlikte 1'i de göster.
Show 1 for supported group buffs even when the ordinary single-target counter is hidden. Yourself is not counted.	Tek hedef sayacı gizliyken bile desteklenen grup buff'ları için 1 gösterilir. Kendin sayılmazsın.
Exclude friendly recipients outside your group where the API identifies them. Enemy counts are unchanged.	API tanıyabildiğinde grup dışındaki dost oyuncuları hariç tut. Düşman sayısı değişmez.
Pick the first or last active recipient's expiration. Does not change the number of recipients or true stacks.	İlk veya son etkilenen oyuncunun efekt bitişini seç. Oyuncu sayısını veya gerçek stack'i değiştirmez.
Saved by ability (including Scribing scripts), not by slot. Timers, stacks and charges are unaffected.	Slota değil yeteneğe (Scribing script'leri dahil) kaydedilir. Sayaçlar, stack ve yükler etkilenmez.
Show confirmed internal cooldowns below the action bar for active class skill lines. Only matching combat events are registered.	Aktif sınıf yetenek ağaçlarının doğrulanmış iç cooldown'larını çubuk altında göster. Yalnız eşleşen savaş olayları izlenir.
Show the observed passive buff on Blood Frenzy and both morphs. The timer appears only while the buff is active.	Blood Frenzy ve iki morph'unda gözlenen pasif buff'ı göster. Sayaç yalnız buff aktifken görünür.
Show observed Abyssal Emergence (A) and Fate Realigned (F) buff durations on the selected skill family. No timer is guessed when the buff is not observed.	Seçilen yetenekte gözlenen Abyssal Emergence (A) ve Fate Realigned (F) buff sürelerini göster. Buff gözlenmediğinde süre tahmin edilmez.
Changes Vampire and Arcanist passive timers, Landslide and external-count text. Stacks, targets and secondary timers have separate size controls above. Larger badges can overlap nearby UI.	Vampire ve Arcanist pasif sayaçları, Landslide ve dış kaynak sayısı yazısını değiştirir. Stack, hedef ve ikinci sayaç boyutları yukarıda ayrıdır. Büyük rozetler yakındaki arayüzle çakışabilir.
Persistent glow while the selected player proc effect is active.	Seçilen oyuncu proc'u aktifken sürekli parlar.
Automatically tracks complete gear sets on either weapon bar. Preview the widget while this menu is open.	İki silah çubuğundan birinde tamamlanan setleri otomatik takip eder. Menü açıkken önizleme yapılabilir.
Unlock to drag the group with the chat cursor. Edit Mode always allows dragging.	Sohbet imleciyle grubu taşımak için kilidi aç. Düzenleme modunda her zaman taşınabilir.
In gameplay: /zera sets preview for sample icons, /zera sets for supported equipped sets, /zera sets gear to diagnose piece counts and missing IDs. /zera sets probe learns Merciless Charge and Corpseburster IDs from real combat events during a 30-second test.	Oyunda: /zera sets preview ile örnek ikonlar, /zera sets ile desteklenen kuşanılmış setler, /zera sets gear ile parça sayıları ve eksik ID'ler. /zera sets probe, 30 saniyelik gerçek savaş testinde Merciless Charge ve Corpseburster ID'lerini öğrenir.
0 = whole seconds; show tenths below this many seconds.	0 = tam saniyeler; belirlenen sürenin altında ondalık göster.
Filters change which equipped set icons are displayed. Normal and perfected variants share preferences.	Filtreler kuşanılan set ikonlarının hangilerinin gösterileceğini değiştirir. Normal ve perfected varyantlar aynı tercihleri paylaşır.
0 = use global icon size. Values below 24 use 24 pixels.	0 = genel ikon boyutu. 24'ün altındaki değerler 24 piksel olarak kullanılır.
Added to the global timer offset.	Genel sayaç konumuna eklenir.
Uses the original ESO health, magicka and stamina bars. Native shields and resource effects remain intact. Zera UI releases the controls when ESO's HUD editor opens.	Orijinal ESO can, magicka ve stamina çubuklarını kullanır. Kalkan ve kaynak efektleri korunur. ESO HUD düzenleyicisi açıldığında Zera UI kontrolü bırakır.
Off: the resource bars form one group. On: drag each bar separately in Zera UI Edit Mode.	Kapalı: kaynak çubukları tek grup. Açık: Zera UI düzenleme modunda her çubuk ayrı taşınabilir.
Removes white and stat-change glow even when switching layouts or skins. Shields are unchanged.	Düzen veya görünüm değişiminde de beyaz ve kaynak değişim parlamasını kaldırır. Kalkanlar değişmez.
Centers the value and percentage together, e.g. 19.7k 100%.	Değer ve yüzdeyi birlikte ortalar; ör. 19.7k 100%.
Shows the remaining shield in blue beside health, e.g. 19.7k (8.4k) 100%.	Kalan kalkanı canın yanında mavi gösterir; ör. 19.7k (8.4k) 100%.
Applies to health, magicka and stamina separately.	Can, magicka ve stamina için ayrı ayrı uygulanır.
With clean resource visuals enabled, only health turns red. Otherwise applies to all three resources.	Temiz kaynak görselleri açıkken yalnız can kırmızı olur. Aksi halde üç kaynak için de uygulanır.
Equal 237-unit bars, centered health, 2-unit seams, centered short numbers and percentages. Restores the reference pyramid position and retains the selected font.	Eşit 237 birim çubuklar, ortalanmış can, 2 birim aralık, ortalanmış kısa değerler ve yüzdeler. Referans piramit konumunu geri yükler ve seçili yazı tipini korur.
Continuous metallic gold pulse when you have enough ultimate. Active Overload takes priority with its own rotating lightning ring.	Yeterli ultimate olduğunda sürekli metalik altın parlama. Aktif Overload kendi dönen elektrik halkasıyla önceliklidir.
Extra soft glow when the ultimate or potion is ready, or while an ultimate effect is active. Charge and active effect remain independent.	Ultimate veya iksir hazırken ya da ultimate efekti aktifken ek yumuşak parlama. Yük ve aktif efekt bağımsız kalır.
Shows actual active effect time, separate from your current ultimate points.	Mevcut ultimate puanından ayrı olarak gerçek aktif efekt süresini gösterir.
Master switch for the cast, channel and GCD widget.	Cast, channel ve GCD bileşeninin ana ayarı.
Uses the current ability's channel time instead of the 1s global cooldown. Meditate shows elapsed time.	1 saniyelik global cooldown yerine mevcut yeteneğin channel süresini kullanır. Meditate geçen süreyi gösterir.
Immediately hides a used or unavailable synergy, even if its old animation was running. Disable to use the legacy flash and fade-out.	Kullanılan veya kullanılamayan sinerjiyi eski animasyonu sürse bile anında gizler. Eski parlama ve kaybolma animasyonu için kapat.
Only applies when instant hide is disabled.	Yalnız anında gizleme kapalıyken uygulanır.
Show 9/12 rather than 9.	9 yerine 9/12 göster.
L: shows the actual player buff stack independently of Seething Fury and Whip charges. Hidden when inactive.	L: Seething Fury ve Whip yükünden bağımsız gerçek oyuncu buff stack'ini gösterir. Aktif değilken gizlenir.
E: counts distinct active effect slots from other players on yourself for supported Vigor and Regeneration morphs. It is not your recipient count or a guaranteed unique-caster count.	E: desteklenen Vigor ve Regeneration morph'ları için diğer oyunculardan aldığın farklı aktif efekt slotlarını sayar. Etkilediğin oyuncu sayısı veya kesin farklı uygulayıcı sayısı değildir.
Individual effect policies override the skill-wide selection, and follow the exact effect ID, not its position.	Efekt bazlı kurallar yetenek genelindeki seçimi geçersiz kılar; konumu değil efekt ID'sini takip eder.
Current target displays only observed effects on the reticle for non-shared, non-cast rules. Use on enemy debuffs, not self buffs or ground placements. Shared buff timers retain attributed expiry tracking.	Mevcut hedef, paylaşımlı olmayan ve cast temelli olmayan kurallarda yalnız nişangâhtaki gözlenen efektleri gösterir. Kendi buff'ların veya alan yetenekleri yerine düşman debuff'larında kullan. Paylaşılan buff sürelerinin kaynak takibi korunur.
Opt in for exact mapped player buffs from other sources if no own effect is active. Shared stat buff/Knife rules are excluded; avoid custom IDs that refer to generic buffs.	Kendi efektin aktif değilse başka kaynaklardan gelen eşleştirilmiş oyuncu buff'larına izin ver. Ortak stat buff'ları ve Knife kuralları hariçtir; genel buff ID'lerinden kaçın.
Track up to three effects per slotted skill. Main = center, 2 = cyan lower left, 3 = gold lower right. Traveling Knife (Warrior's Opportunity / Assassin's Misery) defaults to its Signature debuff, never its Affix buff. Other Scribing combinations can have independent custom rules. ~ = estimated timer.	Her slottaki yetenek için üç efekte kadar takip et. Ana = merkez, 2 = sol alt camgöbeği, 3 = sağ alt altın. Traveling Knife (Warrior's Opportunity / Assassin's Misery) varsayılan olarak Signature debuff'ını takip eder, Affix buff'ını değil. Diğer Scribing kombinasyonları bağımsız kurallar kullanabilir. ~ = tahmini süre.
Choose which of the three independent effect timers to edit: Main (center), Cyan (lower left), Gold (lower right). Each uses its own effect ID and duration.	Düzenlenecek üç bağımsız sayaçtan birini seç: Ana (merkez), camgöbeği (sol alt), altın (sağ alt). Her biri kendi efekt ID ve süresini kullanır.
The debuff/buff ID to observe. This can differ from the cast ability ID.	İzlenecek debuff/buff ID'si. Kullanılan yeteneğin ID'sinden farklı olabilir.
Used in Auto and Cast modes.	Otomatik ve Kullanım modlarında kullanılır.
Auto = real effect or estimate. Effect = real only. Cast = estimate after successful skill use.	Otomatik = gerçek efekt veya tahmin. Gerçek efekt = yalnız gerçek. Kullanım = başarılı yetenek kullanımından sonra tahmin.
Remove custom rules and restore the automatic skill or Knife mapping where available, native otherwise.	Özel kuralları kaldır; varsa otomatik yetenek veya Knife eşleştirmesini, yoksa orijinal takibi geri yükle.
Crystal Fragments has a built-in proc mapping. For other skills enter an observed player buff ID. The glow only stays active while that real effect is present.	Crystal Fragments yerleşik proc eşleştirmesine sahiptir. Diğer yeteneklerde gözlenen oyuncu buff ID'sini gir. Parlama yalnız gerçek efekt mevcutken sürer.
Start a 30-second recording, close the settings, and cast a skill on a dummy. Reopen this panel to inspect the effects. Only your own gained/updated buff or debuff events are recorded. Other procs may appear, so results are candidates, not proof of skill origin.	30 saniyelik kayıt başlat, ayarları kapat ve dummy üzerinde bir yetenek kullan. Efektleri incelemek için paneli yeniden aç. Yalnız kendi kazanılan/güncellenen buff ve debuff olayların kaydedilir. Başka proc'lar görünebilir; sonuçlar adaydır, yetenek kaynağının kesin kanıtı değildir.
Restores HUD colors, sizes, positioning and animations. Custom skill tracking rules remain intact.	HUD renklerini, boyutlarını, konumlarını ve animasyonlarını sıfırlar. Özel yetenek takip kuralları korunur.
Tracking rules are preserved.	Takip kuralları korunur.
Four independent buff/debuff groups. One effect snapshot per unit; each group has its own position, font, size, color and filter. Disabling a group hides it while leaving the other group available.	Dört bağımsız buff/debuff grubu. Birim başına tek efekt taraması; her grubun ayrı konumu, yazı tipi, boyutu, rengi ve filtresi vardır. Bir grubu kapatmak diğerini etkilemez.
Only the corresponding enabled custom grid replaces its matching native container when available. If the native HUD still duplicates it, disable the native display in ESO Combat settings.	Yalnız etkin özel grup eşleşen orijinal grubu gizler. Orijinal HUD hâlâ tekrarlanıyorsa ESO savaş ayarlarında orijinal gösterimi kapat.
Unlock to drag with the chat cursor. Edit Mode always permits moving this widget.	Sohbet imleciyle taşımak için kilidi aç. Düzenleme modunda her zaman taşınabilir.
Include effects without a countdown; timed food, potions and buffs are always eligible.	Sayaçsız efektleri dahil et; süreli yemek, iksir ve buff'lar her zaman uygundur.
1 = vertical, 6 = six per row, 8 = eight per row. With Single Row enabled, icons never wrap.	1 = dikey, 6 = satırda altı, 8 = satırda sekiz. Tek Satır açıkken ikonlar alt satıra geçmez.
Never create a second row. All visible effects grow horizontally beyond the column setting if necessary.	İkinci satır oluşturma. Gerektiğinde sütun sayısını aşarak tüm görünen efektleri yatay diz.
Relative to top-right of screen.	Ekranın sağ üst köşesine göre.
Uses action-bar font and outline, scaled to the icon size.	Yetenek çubuğu yazı tipi ve konturunu ikon boyutuna göre ölçekler.
Colored frame, timer and stronger countdown fill.	Renkli çerçeve, sayaç ve güçlü süre dolgusu.
Exclude effects cast by other players. Off Balance still tracks all sources.	Başka oyuncuların uyguladığı efektleri hariç tut. Off Balance tüm kaynakları izlemeye devam eder.
Separate icon for the current hostile target: bright green = active, red = immunity, gold = ready. Actual immunity effects take priority. Optional estimated immunity is marked with ~. Does not require OffBalanceTracker or the set module.	Mevcut düşman hedef için ayrı ikon: parlak yeşil = aktif, kırmızı = bağışıklık, altın = hazır. Gerçek bağışıklık efektleri önceliklidir. Tahmini bağışıklık ~ ile işaretlenir. OffBalanceTracker veya set modülü gerekmez.
Unlock to drag with chat cursor. Edit Mode always permits moving it.	Sohbet imleciyle taşımak için kilidi aç. Düzenleme modunda her zaman taşınabilir.
After an observed natural expiry on the same target, show a marked 15s fallback until the real immunity is available. Never transfers across targets.	Aynı hedefte doğal bitiş gözlendiğinde gerçek bağışıklık gelene kadar işaretli 15 saniyelik tahmin göster. Hedefler arasında aktarılmaz.
No skill in this slot.	Bu slotta yetenek yok.
No skill in slot.	Slotta yetenek yok.
No custom effects configured.	Özel efekt ayarlanmamış.
No effects recorded.	Efekt kaydedilmedi.
No recording yet.	Henüz kayıt yok.
No effect in this result slot.	Bu sonuçta efekt yok.
Skill changed or empty; refresh selected skill first.	Yetenek değişti veya boş; önce seçilen yeteneği yenile.
Global defaults restored.	Genel varsayılanlar geri yüklendi.
Skill animation settings saved.	Yetenek animasyon ayarları kaydedildi.
Skill changed. Refresh the selected skill first.	Yetenek değişti. Önce seçilen yeteneği yenile.
Skill changed. Refresh first.	Yetenek değişti. Önce yenile.
Skill changed: refresh before saving.	Yetenek değişti: kaydetmeden önce yenile.
Proc disabled for this skill.	Bu yetenek için proc kapatıldı.
Default proc mapping restored.	Varsayılan proc eşleştirmesi geri yüklendi.
Select a recorded result first.	Önce kaydedilen bir sonuç seç.
Result copied. Click Save tracking rule to apply.	Sonuç kopyalandı. Uygulamak için takip kuralını kaydet.
Mapped effect tracking	Eşleştirilmiş efekt takibi
Native timer; add a custom effect to use target/external tracking	Orijinal sayaç; hedef/harici takip için özel efekt ekle
No skill in that slot.	Bu slotta yetenek yok.
Effect entry removed (remaining effects shift up).	Efekt kaldırıldı (kalan efektler yukarı kaydırıldı).
Add effect entries in order (1-3).	Efekt girişlerini sırayla ekle (1-3).
This effect ID is already tracked on the skill.	Bu efekt ID'si yetenekte zaten takip ediliyor.
Proc effect ID must be a positive integer.	Proc efekt ID'si pozitif bir tam sayı olmalı.
Effect recording is unavailable on this API.	Bu API'de efekt kaydı kullanılamıyor.
Recording for 30 seconds. Close settings and use the skill on a dummy.	30 saniyelik kayıt başladı. Ayarları kapat ve dummy'de yeteneği kullan.
Center	Merkezden iki yana
ZERA UI — EDIT MODE	ZERA UI — DÜZENLEME MODU
Move together	Birlikte taşı
Move together: ON	Birlikte taşı: AÇIK
Move together: OFF	Birlikte taşı: KAPALI
Reset positions	Konumu sıfırla
Cancel	İptal
Save	Kaydet
Entire HUD	Tüm HUD
Action bar	Yetenek çubuğu
Potion	İksir
Cast bar	Cast barı
Synergy	Sinerji
Attributes	Kaynak çubukları
Health	Can
]=])

add([=[
ZERA UI  ·  SKILL TRACKING	ZERA UI  ·  SKILL TAKİBİ
Close	Kapat
Choose a skill	Bir skill seç
Front	Ön
Back	Arka
Werewolf	Kurt adam
Ult	Ult
Tracked now by	Şu an takip eden
Timers on this skill	Bu skilldeki süreler
Position	Konum
Seconds	Saniye
How the timer runs	Süre nasıl işlesin
Middle	Orta
Lower left	Sol alt
Lower right	Sağ alt
Real effect only	Sadece gerçek efekt
Real effect, else estimate	Gerçek efekt, yoksa tahmin
Timer from cast	Basınca başlayan süre
Clear	Temizle
Real effect only: counts the buff/debuff the game reports.  Real effect, else estimate: uses Seconds if the effect is not seen (~).  Timer from cast: always Seconds after you cast.	Sadece gerçek efekt: oyunun bildirdiği buff/debuff'ı sayar.  Gerçek efekt, yoksa tahmin: efekt görülmezse Saniye değerini kullanır (~).  Basınca başlayan süre: skilli bastığın an Saniye kadar sayar.
Save timers	Süreleri kaydet
Restore default	Varsayılana dön
Proc glow	Proc parlaması
Save proc	Proc'u kaydet
Automatic	Otomatik
Several targets	Birden fazla hedef
Used when the skill's effect is on more than one enemy. Current target only shows the timer on the enemy you look at.	Skillin efekti birden fazla düşmandayken kullanılır. "Sadece baktığım hedef" seçilirse yalnızca baktığın düşmandaki süre gösterilir.
Same buff from others	Başkalarından gelen aynı buff
If you have no own copy of the tracked buff, show the timer of the same buff given by another player. Off by default.	Takip edilen buff sende kendi kaynağından yoksa, başka bir oyuncunun verdiği aynı buff'ın süresini gösterir. Varsayılan olarak kapalı.
Effect ID finder	Efekt ID bulucu
Record 60s	60 sn kayıt al
Stop	Durdur
Effects on me	Üstümdekiler
On target	Hedeftekiler
Clear list	Listeyi temizle
Only after this skill: %s	Sadece bu skillden sonra: %s
ON	AÇIK
OFF	KAPALI
Proc	Proc
Your own timers: %d	Kendi süre kuralların: %d
Built-in phases after the rune triggers: %s (center, then lower left)	Rün tetiklenince yerleşik fazlar: %s (önce orta, sonra sol alt)
Built-in phases: %s (center, then lower left)	Yerleşik fazlar: %s (önce orta, sonra sol alt)
Built-in effect tracking (effect %d)	Yerleşik efekt takibi (efekt %d)
The game's own skill timer	Oyunun kendi skill süresi
Empty slot	Boş slot
%s %s  ·  Ability ID %d	%s %s  ·  Yetenek ID %d
Saved as your own rule	Kendi kuralın olarak kayıtlı
Showing the built-in rule; Save turns it into your own	Yerleşik kural gösteriliyor; Kaydet'e basarsan senin kuralın olur
Proc glow: off for this skill	Proc parlaması: bu skillde kapalı
Proc glow: your effect ID	Proc parlaması: senin efekt ID'n
Proc glow: automatic	Proc parlaması: otomatik
Several targets: %s	Birden fazla hedef: %s
Default	Varsayılan
Soonest to expire	İlk bitecek olan
Latest to expire	En son bitecek olan
Current target only	Sadece baktığım hedef
Count the same buff from others: %s	Başkalarının aynı buff'ını say: %s
no timer	süresiz
On you	Üstünde
Group	Grup
Enemy	Düşman
Other	Diğer
after %d/%d casts	%d/%d basışta
snapshot	anlık
Recording: %ds left. Cast the selected skill 2-3 times on a target dummy.	Kayıt: %d sn kaldı. Seçili skilli kukla üzerinde 2-3 kez bas.
%d effects found. Effects that came right after the selected skill are listed first.	%d efekt bulundu. Seçili skillden hemen sonra gelenler en üstte.
Press Record, then cast the skill a few times. Window can stay open or be closed.	Kayıt al'a bas, sonra skilli birkaç kez kullan. Pencere açık kalabilir ya da kapatabilirsin.
Selected skill cast %d times.	Seçili skill %d kez basıldı.
Effect %d copied to the proc field. Press Save proc.	Efekt %d proc alanına kopyalandı. Proc'u kaydet'e bas.
Effect %d copied to %s. Press Save timers.	Efekt %d → %s. Süreleri kaydet'e bas.
The skill in this slot changed. Check it and save again.	Bu slottaki skill değişti. Kontrol edip tekrar kaydet.
Saved %d timer(s).	%d süre kaydedildi.
All your timers removed; built-in tracking is back.	Kendi sürelerin silindi; yerleşik takip geri geldi.
Built-in tracking restored for this skill.	Bu skill için yerleşik takip geri yüklendi.
Proc effect saved.	Proc efekti kaydedildi.
Look at a target first.	Önce bir hedefe bak.
finish HUD editing first.	önce HUD düzenlemeyi bitir.
Effect ID must be a positive integer.	Efekt ID pozitif bir tam sayı olmalı.
Mode: auto, effect, or cast.	Mod: auto, effect veya cast.
Enter a fallback duration greater than 0 and at most 3600 seconds.	0'dan büyük, en fazla 3600 saniyelik bir süre gir.
Right-click: hide or whitelist	Sağ tık: gizle veya beyaz listeye ekle
Show this effect again	Bu efekti tekrar göster
Hide this effect (blacklist)	Bu efekti gizle (kara liste)
Remove from whitelist	Beyaz listeden çıkar
Add to target whitelist	Hedef beyaz listesine ekle
Add to my whitelist	Kendi beyaz listeme ekle
Selected: %s	Seçili: %s
whole HUD moves	tüm HUD birlikte kayar
Click a box or widget to select it	Seçmek için bir kutuya veya widget'a tıkla
Click a box or widget to select it  •  Snap %d px	Seçmek için bir kutuya veya widget'a tıkla  •  Izgara %d px
Apply	Uygula
Reset selected	Seçileni sıfırla
Reset all	Tümünü sıfırla
Click again to confirm	Onay için tekrar tıkla
Ultimate	Ultimate
Skill tracking & effect IDs	Skill takibi ve efekt ID'leri
Most skills need nothing here: Zera UI already reads the game's own timer, built-in effect IDs and phase timers (such as Ulfsild's Contingency and Resolving Vigor). Use the tracking window when a skill shows the wrong timer or none at all.	Çoğu skill için burada bir şey yapman gerekmez: Zera UI oyunun kendi süresini, yerleşik efekt ID'lerini ve faz sürelerini (Ulfsild's Contingency, Resolving Vigor gibi) zaten okur. Bir skill yanlış süre gösterirse ya da hiç göstermezse takip penceresini kullan.
How it works:  1) Open the window and click the skill on your bar.  2) Press Record and cast the skill 2-3 times on a target dummy.  3) The effects that came right after that skill are listed first; click Middle, Left or Right to use one.  4) Press Save timers.	Nasıl kullanılır:  1) Pencereyi aç ve barındaki skille tıkla.  2) Kayıt al'a bas ve skilli kukla üzerinde 2-3 kez kullan.  3) O skillden hemen sonra gelen efektler en üstte listelenir; kullanmak için Orta, Sol veya Sağ'a tıkla.  4) Süreleri kaydet'e bas.
Open skill tracking window	Skill takip penceresini aç
Remove all my tracking rules	Tüm takip kurallarımı sil
Built-in tracking returns for every skill. This cannot be undone.	Tüm skillerde yerleşik takip geri gelir. Geri alınamaz.
Hide & whitelist	Gizle ve beyaz liste
Show the mouse cursor (default key: .) and hover over any buff or debuff icon to read its tooltip. Right-click the icon to hide it (blacklist) or add it to a whitelist. Grids set to whitelist only show nothing else.	Fare imlecini aç (varsayılan tuş: .) ve bir buff/debuff ikonunun üstüne gelerek açıklamasını gör. İkona sağ tıklayıp gizleyebilir (kara liste) veya beyaz listeye ekleyebilirsin. "Sadece beyaz liste" açık olan gruplar başka hiçbir şey göstermez.
Mouse tooltips & right-click menu	Fare ipuçları ve sağ tık menüsü
Icons react to the mouse only while the cursor is shown and the grid is locked. Turn off if you never use the cursor over the HUD.	İkonlar yalnızca imleç açıkken ve grup kilitliyken fareye tepki verir. HUD üzerinde imleç hiç kullanmıyorsan kapatabilirsin.
Self buffs: only whitelisted	Kendi buff'ların: sadece beyaz liste
Self debuffs: only whitelisted	Kendi debuff'ların: sadece beyaz liste
Target buffs: only whitelisted	Hedef buff'ları: sadece beyaz liste
Target debuffs: only whitelisted	Hedef debuff'ları: sadece beyaz liste
Uses My whitelist.	Kendi beyaz listeni kullanır.
Uses Target whitelist.	Hedef beyaz listesini kullanır.
List to edit	Düzenlenecek liste
Hidden effects (blacklist)	Gizlenen efektler (kara liste)
My whitelist	Kendi beyaz listem
Target whitelist	Hedef beyaz listesi
Add by ID or name	ID veya isimle ekle
An ability ID (e.g. 61665) or an exact effect name (e.g. Major Brutality). A name matches every effect with that name.	Bir yetenek ID'si (ör. 61665) veya tam efekt adı (ör. Major Brutality). İsim yazarsan o isimdeki tüm efektler eşleşir.
Add to list	Listeye ekle
Entries	Kayıtlar
Choose an entry, then press Remove selected.	Bir kayıt seç, sonra Seçileni sil'e bas.
Remove selected	Seçileni sil
Clear this list	Bu listeyi temizle
Removes every entry from the selected list.	Seçili listedeki tüm kayıtları siler.
]=])
add([=[
SKILL TRACKING	SKİLL TAKİBİ
Pick a skill, check what its timer shows, change it only if it is wrong.	Bir skill seç, süresinin ne gösterdiğine bak; sadece yanlışsa değiştir.
1   CHOOSE A SKILL	1   SKİLL SEÇ
2   WHAT THE TIMER SHOWS NOW	2   SÜRE ŞU AN NE GÖSTERİYOR
3   YOUR OWN TIMERS  (optional)	3   KENDİ SÜRELERİN  (isteğe bağlı)
4   FIND THE EFFECT ID	4   EFEKT ID'SİNİ BUL
saved	kayıtlı
built-in values shown	yerleşik değerler gösteriliyor
Where	Nerede
What it counts	Neyi sayar
Fixed from cast	Basınca sabit süre
Follow the effect	Efekti takip et
Follow the effect: shows how long the buff or debuff really lasts (needs an effect ID).	Efekti takip et: buff veya debuff'ın gerçekte ne kadar sürdüğünü gösterir (efekt ID'si gerekir).
Fixed from cast: always counts the Seconds from the moment you press the skill (effect ID optional).	Basınca sabit süre: skille bastığın andan itibaren her zaman Saniye kadar sayar (efekt ID'si gerekmez).
Empty rows are ignored. Lower left / right are small corner timers.	Boş satırlar yok sayılır. Sol alt / sağ alt, köşedeki küçük sürelerdir.
Use built-in	Yerleşiği kullan
Proc glow ID	Proc parlaması ID
off	kapalı
your ID	senin ID'n
automatic	otomatik
Follow my target	Baktığım hedefi takip et
Same buff from others: %s	Başkalarından gelen aynı buff: %s
When this skill's debuff is on more than one enemy: follow the enemy you look at, or show the soonest / latest one.	Bu skillin debuff'ı birden fazla düşmandayken: baktığın düşmanı takip eder ya da ilk / son bitecek olanı gösterir.
If you have no own copy of the tracked buff, show the same buff given by another player.	Takip edilen buff sende kendi kaynağından yoksa, başka bir oyuncunun verdiği aynı buff'ı gösterir.
Record, cast the selected skill 2-3 times, then click Middle / Left / Right on the green row that belongs to it.	Kayıt al, seçili skilli 2-3 kez kullan, sonra ona ait yeşil satırda Orta / Sol / Sağ düğmesine bas.
Effect	Efekt
Use as	Şurada kullan
Results appear here.	Sonuçlar burada görünür.
Record 60 s	60 sn kayıt al
Recording, %d s left. Cast %s 2-3 times on a target dummy.	Kayıt sürüyor, %d sn kaldı. %s skillini kuklada 2-3 kez kullan.
%d effects. Green rows came right after %s; 3/3 means seen after 3 of 3 casts.	%d efekt. Yeşil satırlar %s skillinden hemen sonra geldi; 3/3 = 3 basışın 3'ünde görüldü.
%d effects. Cast the selected skill while recording to see which belong to it.	%d efekt. Hangilerinin ona ait olduğunu görmek için kayıt sırasında seçili skilli kullan.
No results yet. Press Record, then use the skill.	Henüz sonuç yok. Kayıt al'a bas, sonra skilli kullan.
%s copied to Proc glow. Press Save.	%s proc parlamasına kopyalandı. Kaydet'e bas.
%s: %s. Press Save to apply.	%s: %s. Uygulamak için Kaydet'e bas.
, then 	, sonra 
Others' buff	Başkasının buff'ı
ON: also from other players	AÇIK: başka oyuncularınki de
OFF: only your own	KAPALI: sadece kendi buff'ın
Keep the last target's timer when looking away	Başka yere bakınca son hedefin süresini koru
With no enemy under the crosshair (or with the cursor shown), keep counting down the last target's debuff timer.	Nişangahın altında düşman yokken (veya imleç açıkken) son hedefteki debuff süresini saymaya devam eder.
%s: enter the seconds for a fixed timer.	%s: sabit süre için saniye gir.
Your timers removed; built-in tracking is back.	Kendi sürelerin silindi; yerleşik takip geri geldi.
Your own timers	Kendi sürelerin
fixed	sabit
Built-in: starts when the rune triggers	Yerleşik: rün tetiklenince başlar
Built-in phase timers	Yerleşik faz süreleri
Middle shows %s, the next one waits lower left and moves to the middle.	Ortada %s; sıradaki sol altta bekler, sonra ortaya geçer.
Built-in effect tracking	Yerleşik efekt takibi
Middle follows %s (%d).	Orta, %s (%d) efektini takip ediyor.
Nothing to set up unless the timer is wrong.	Süre yanlış değilse ayar gerekmez.
MORE OPTIONS  (proc glow, several targets)	DİĞER AYARLAR  (proc parlaması, birden fazla hedef)
Several enemies	Birden fazla düşman
Debuff timers follow your target	Debuff süreleri baktığın hedefi takip etsin
Your DoT/debuff timer shows the time left on the enemy you look at: another enemy shows its own time, an enemy without it shows nothing, and looking away keeps the last target's time. Per skill, the tracking window can switch to Soonest / Latest instead.	DoT/debuff süren baktığın düşmandaki kalan süreyi gösterir: başka düşmana bakınca onunkini, debuff olmayan düşmanda boş, başka yere bakınca son hedefin süresini gösterir. Skill bazında takip penceresinden İlk / Son bitecek olana çevrilebilir.
]=])
add([=[
Fake effect (from cast)	Sahte efekt (basınca)
Middle: %s	Orta: %s
Lower left: %s	Sol alt: %s
then %s	sonra %s
When the middle one ends, the next one moves to the middle. No effect ID needed: the scripts on the skill decide.	Ortadaki bitince sıradaki ortaya geçer. Efekt ID'si gerekmez: skilldeki scriptler belirler.
Heal over time	Zamanla iyileşme
Built-in	Yerleşik
Nothing Wasted is shown on this Siphon (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.	Bu Siphon'da Nothing Wasted gösteriliyor (04 Takip ve sınıf mekanikleri > Class mekanikleri); süreleri burada değiştirilemez.
The Arcanist mastery timer is shown on this skill (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.	Bu skillde Arcanist mastery süresi gösteriliyor (04 Takip ve sınıf mekanikleri > Class mekanikleri); süreleri burada değiştirilemez.
The Strike from the Shadows timer is shown on this skill (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.	Bu skillde Strike from the Shadows süresi gösteriliyor (04 Takip ve sınıf mekanikleri > Class mekanikleri); süreleri burada değiştirilemez.
Landslide is shown on this Whip (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.	Bu Whip'te Landslide gösteriliyor (04 Takip ve sınıf mekanikleri > Class mekanikleri); süreleri burada değiştirilemez.
Turn that option off to use your own timers. Saved timers are preserved while the feature takes priority.	Kendi sürelerini kullanmak için o seçeneği kapat. Özellik öncelikliyken kayıtlı sürelerin korunur.
LOCKED FOR THIS SKILL	BU SKİLL KİLİTLİ
This skill is locked by another feature.	Bu skill başka bir özellik tarafından kilitli.
Refresh	Yenile
Bars refreshed.	Barlar yenilendi.
Reads your bars again, e.g. after you changed a skill while this window was open.	Barlarını yeniden okur; ör. bu pencere açıkken skill değiştirdiysen.
The number of the buff or debuff this timer follows. Find it with section 4: record, cast the skill, click Middle / Left / Right on its green row.	Bu sürenin takip ettiği buff/debuff'ın numarası. 4. bölümden bulursun: kayıt al, skilli kullan, yeşil satırında Orta / Sol / Sağ'a tıkla.
Follow the effect: the real time left on that buff/debuff, as the game reports it.	Efekti takip et: o buff/debuff'ın oyunun bildirdiği gerçek kalan süresi.
Fake effect (from cast): no real effect is read; a timer simply counts the Seconds you enter from the moment you press the skill. For effects the game doesn't report.	Sahte efekt (basınca): gerçek efekt okunmaz; skille bastığın andan itibaren yazdığın Saniye kadar sayan bir süre başlar. Oyunun bildirmediği efektler için.
Only for a fake effect: how long the timer counts after you press the skill.	Sadece sahte efekt için: skille bastıktan sonra sürenin kaç saniye sayacağı.
Move to the middle	Ortaya geç
When the middle timer ends, this corner timer moves to the middle. Only one corner can do this.	Ortadaki süre bitince bu köşedeki süre ortaya geçer. Sadece bir köşe seçilebilir.
Clear row	Satırı temizle
Empties this row. Press Save to apply.	Bu satırı boşaltır. Uygulamak için Kaydet'e bas.
Back to default	Varsayılana dön
To middle	Ortaya geç
Empty rows are ignored. A ticked corner timer moves to the middle when the middle one ends.	Boş satırlar yok sayılır. İşaretli köşedeki süre, ortadaki bitince ortaya geçer.
When the middle one ends, the next one moves to the middle. No effect ID needed: both start when you cast.	Ortadaki bitince sıradaki ortaya geçer. Efekt ID'si gerekmez: ikisi de basınca başlar.
Vigor, Echoing Vigor and Resolving Vigor. Skills with PA on can't get their own timers in the tracking window.	Vigor, Echoing Vigor ve Resolving Vigor. PA açık olan skillere takip penceresinden kendi süre verilemez.
Caltrops, Razor Caltrops and Anti-Cavalry Caltrops.	Caltrops, Razor Caltrops ve Anti-Cavalry Caltrops.
Magicka, Inevitable and Proximity Detonation.	Magicka, Inevitable ve Proximity Detonation.
The Trample scribing skill.	Trample scribing skilli.
]=])
add([=[
no effect ID needed	efekt ID'si gerekmez
unknown ID	bilinmeyen ID
Fake effect	Sahte efekt
The middle timer can't be used for this skill: it always shows Off Balance / its immunity and the Power Lash charges.	Orta süre bu skillde kullanılamaz: orada her zaman Off Balance / bağışıklığı ve Power Lash şarjları gösterilir.
The middle timer can't be used for this skill: it shows the channel while you cast it.	Orta süre bu skillde kullanılamaz: skilli kullanırken orada kanal süresi gösterilir.
Ultimates keep their built-in tracking.	Ultimate'ler yerleşik takipte kalır.
Test	Test
Plays the rows as typed on your bar for a few seconds, without saving. Follow-the-effect rows use a sample time.	Yazdığın satırları kaydetmeden birkaç saniye barında oynatır. "Efekti takip et" satırları örnek bir süre kullanır.
Fill in at least one row to test it.	Test etmek için en az bir satırı doldur.
Test running on your bar: watch the skill's middle and corners.	Test barında oynuyor: skillin ortasına ve köşelerine bak.
My saved rules (%d)	Kayıtlı kurallarım (%d)
%d timer(s)	%d süre
proc off	proc kapalı
own proc	kendi proc'u
target option	hedef ayarı
on your bar	barında
not on your bars	barlarında değil
Rule removed; built-in tracking is back for that skill.	Kural silindi; o skillde yerleşik takip geri geldi.
Every skill you changed, also skills no longer on your bars. Remove sets it back to built-in tracking.	Değiştirdiğin tüm skiller, artık barında olmayanlar dahil. Sil, o skilli yerleşik takibe geri döndürür.
You have no saved rules.	Kayıtlı kuralın yok.
%s: the effect ID must be a whole number.	%s: efekt ID'si tam sayı olmalı.
Nothing changed.	Hiçbir şey değişmedi.
The middle timer can't be used for this skill.	Orta süre bu skillde kullanılamaz.
Remove	Sil
]=])
add([=[
Skill tracking	Skill takibi
What the timer shows	Süre ne gösteriyor
Find the effect ID	Efekt ID'sini bul
Click a skill: step 2 opens.	Bir skille tıkla: 2. adım açılır.
More options	Diğer ayarlar
Click the button to switch.	Değiştirmek için düğmeye tıkla.
Find effects	Bul
optional step	isteğe bağlı
Recording · %d s	Kayıt · %d sn
%d effects found	%d efekt bulundu
Record, then cast	Kayıt al, skilli kullan
Attribute bars	Kaynak çubukları
Default Attribute Bar	Varsayılan kaynak çubuğu
Custom Attribute Bar	Özel kaynak çubuğu
Default Attribute Bar: ESO's own bars, arranged by Zera UI. Custom Attribute Bar: Zera UI's own bars; ESO's bars are hidden and paused. ESO's HUD editor always gets ESO's bars back.	Varsayılan kaynak çubuğu: ESO'nun kendi çubukları, Zera UI yerleştirir. Özel kaynak çubuğu: Zera UI'ın kendi çubukları; ESO'nun çubukları gizlenir ve durdurulur. ESO'nun HUD düzenleyicisi açılınca ESO'nun çubukları her zaman geri gelir.
Off: ESO handles its bars, Zera UI does not touch them.	Kapalı: çubukları ESO yönetir, Zera UI dokunmaz.
Default: Pyramid or Native. Custom: Curved, Native, Stacked or Pyramid. Switching layouts resets their position.	Varsayılan: Piramit veya Orijinal. Özel: Dikey kavis, Orijinal, Üst üste veya Piramit. Düzen değişince konumlar sıfırlanır.
Size & position	Boyut ve konum
Text	Yazı
Shield & warnings	Kalkan ve uyarılar
Show trauma	Trauma'yı göster
Custom bars: damage that must be healed before health rises again, as a purple mark on the health bar.	Özel çubuklar: can tekrar yükselmeden önce iyileştirilmesi gereken hasar; can çubuğunda mor bir işaret.
Show no healing	İyileşme engelini göster
Custom bars: a dark red tint on the health bar while you cannot be healed.	Özel çubuklar: iyileştirilemediğin sürece can çubuğunda koyu kırmızı bir renk.
Update rate	Güncelleme hızı
Every change	Her değişimde
Max 20 per second	Saniyede en fazla 20
Max 10 per second	Saniyede en fazla 10
Custom bars: how often a changing value is redrawn. Every change is the most precise; a limit saves work in big fights. The final value is always shown.	Özel çubuklar: değişen bir değerin ne sıklıkla yeniden çizileceği. Her değişimde en hassasıdır; sınır büyük savaşlarda işi azaltır. Son değer her zaman gösterilir.
Health text turns red at 25% or lower. On the Curved arcs all three resources do.	Can yazısı %25 veya altında kırmızı olur. Dikey kavislerde üç kaynak da kırmızı olur.
]=])
add([=[
02  |  Action bar & animations	02  |  Yetenek çubuğu ve animasyonlar
03  |  HUD widgets & performance	03  |  HUD bileşenleri ve performans
04  |  Tracking & class mechanics	04  |  Takip ve sınıf mekanikleri
05  |  Sets	05  |  Setler
06  |  Buffs, debuffs & tools	06  |  Buff, debuff ve araçlar
Availability rules, warning thresholds and animation behavior	Kullanılabilirlik kuralları, uyarı eşikleri ve animasyon davranışı
Resource bar engine, update rate and widget activations	Kaynak çubuğu motoru, güncelleme hızı ve bileşen anahtarları
Group buffs, target counts and class passives	Grup buff'ları, hedef sayıları ve sınıf pasifleri
Set tracking, special mechanics, filters and sounds	Set takibi, özel mekanikler, filtreler ve sesler
Effect filters, Off Balance, per-skill rules and Tracking Studio	Efekt filtreleri, Off Balance, yetenek kuralları ve Takip Stüdyosu
Edit HUD (Interactive Editor)	HUD Düzenle (Etkileşimli Düzenleyici)
Availability & timers	Kullanılabilirlik ve süreler
Timer thresholds	Süre eşikleri
Animations & glows	Animasyonlar ve parlamalar
Shield, warnings & performance	Kalkan, uyarılar ve performans
Ultimate, potion, cast & synergy	Ultimate, iksir, cast ve sinerji
Cast / channel / GCD bar	Cast / kanal / GCD çubuğu
Set tracking & special mechanics	Set takibi ve özel mekanikler
Set filters, overrides & sounds	Set filtreleri, özel ayarlar ve sesler
Buff & debuff tracking	Buff ve debuff takibi
Per-area filters	Alan bazlı filtreler
Enable selected effect area	Seçili efekt alanını aç
Effect area permanent effects	Efekt alanı kalıcı efektler
Effect area sort order	Efekt alanı sıralama düzeni
Show Nothing Wasted timer	Nothing Wasted süresini göster
Click a widget to edit  •  Right-click for options  •  Snap %d px	Düzenlemek için bir widget'a tıkla  •  Seçenekler için sağ tıkla  •  Izgara %d px
Click any widget to customize its appearance. Right-click a widget for quick alignment and reset actions.	Görünümünü özelleştirmek için herhangi bir widget'a tıkla. Hızlı hizalama ve sıfırlama için widget'a sağ tıkla.
HUD Overview	HUD Genel Bakış
HUD Elements	HUD Elemanları
Overview	Genel
Elements	Elemanlar
Right-click: options	Sağ tık: seçenekler
Select an element  •  Snap %d px	Bir eleman seç  •  Izgara %d px
Global HUD	Genel HUD
Editor grid	Düzenleyici ızgarası
Show alignment grid	Hizalama ızgarasını göster
Snap	Izgara
Grid: ON	Izgara: AÇIK
Grid: OFF	Izgara: KAPALI
Inspector	Denetçi
Style	Stil
Customize	Özelleştir
Center horizontally (X = 0)	Yatay ortala (X = 0)
Center vertically (Y = 0)	Dikey ortala (Y = 0)
Snap to grid	Izgaraya hizala
Switch layout	Düzeni değiştir
Group attribute bars	Kaynak çubuklarını grupla
Enable single row	Tek satırı aç
Disable single row	Tek satırı kapat
Reset	Sıfırla
Reset position	Konumu sıfırla
Reset position & appearance	Konum ve görünümü sıfırla
Layout & style	Düzen ve stil
Layout & typography	Düzen ve yazı tipi
Typography	Yazı tipi
Typography & shield	Yazı tipi ve kalkan
Visuals	Görsel
Visuals & colors	Görsel ve renkler
Fill & glows	Dolgu ve parlamalar
Corner timers	Köşe sayaçları
Lock position	Konumu kilitle
Icons per row	Satır başına ikon
Horizontal growth	Yatay büyüme
Single row	Tek satır
Icon size (pixels)	İkon boyutu (piksel)
Icon gap	İkon boşluğu
Font outline	Yazı konturu
Timer font scale	Sayaç yazı boyutu
Stack font scale	Stack yazı boyutu
Show stacks	Stack'leri göster
Countdown fill	Geri sayım dolgusu
Expiry flash	Bitiş parlaması
Flash threshold (seconds)	Parlama eşiği (saniye)
Highlight debuffs	Debuff'ları vurgula
Fill color	Dolgu rengi
Highlight & fill color	Vurgu ve dolgu rengi
Native ESO prompt: drag, nudge, or use Reset Position. Appearance stays managed by ESO.	Orijinal ESO bildirimi: sürükle, kaydır veya Konumu Sıfırla'yı kullan. Görünümü ESO yönetir.
Native ESO tip: drag, nudge, or use Reset Position. Appearance stays managed by ESO.	Orijinal ESO ipucu: sürükle, kaydır veya Konumu Sıfırla'yı kullan. Görünümü ESO yönetir.
Native ESO dialogue window: drag, nudge, or use Reset Position. Appearance stays managed by ESO.	Orijinal ESO diyalog penceresi: sürükle, kaydır veya Konumu Sıfırla'yı kullan. Görünümü ESO yönetir.
Native ESO warning: drag, nudge, or use Reset Position. Appearance stays managed by ESO.	Orijinal ESO uyarısı: sürükle, kaydır veya Konumu Sıfırla'yı kullan. Görünümü ESO yönetir.
Default Attribute Bar: ESO's own bars, arranged by Zera UI. Custom Attribute Bar: Zera UI's own bars; ESO's bars are hidden and paused. Sizes, fonts and spacing are edited live in Interactive HUD Edit Mode.	Varsayılan kaynak çubuğu: ESO'nun kendi çubukları, Zera UI yerleştirir. Özel kaynak çubuğu: Zera UI'ın kendi çubukları; ESO'nun çubukları gizlenir ve durdurulur. Boyutlar, yazı tipleri ve boşluklar Etkileşimli HUD Düzenleyici'de canlı düzenlenir.
Automatically tracks complete gear sets on either weapon bar. Customize icon layout, fonts and colors directly in Interactive HUD Edit Mode.	Her iki silah çubuğundaki tam zırh/silah setlerini otomatik takip eder. İkon düzeni, yazı tipleri ve renkler doğrudan Etkileşimli HUD Düzenleyici'de özelleştirilir.
Four independent buff/debuff groups sharing one unit scan. Click any grid in Interactive HUD Edit Mode to style its icons, columns, growth, font and colors.	Tek birim taramasını paylaşan dört bağımsız buff/debuff grubu. İkon, sütun, büyüme, yazı tipi ve renklerini ayarlamak için Etkileşimli HUD Düzenleyici'de ilgili gruba tıkla.
Select a group to edit its activation and filtering rules.	Aktivasyon ve filtreleme kurallarını düzenlemek için bir grup seç.
Separate icon for the current hostile target: bright green = active, red = immunity, gold = ready. Actual immunity effects take priority. Size, font and colors are customized in Interactive HUD Edit Mode.	Mevcut düşman hedef için ayrı ikon: parlak yeşil = aktif, kırmızı = bağışıklık, altın = hazır. Gerçek bağışıklık efektleri önceliklidir. Boyut, yazı tipi ve renkler Etkileşimli HUD Düzenleyici'de özelleştirilir.
Override glow animations or the gold stack warning for a specific skill. Saved by ability (including Scribing scripts), not by slot. Refreshes automatically when opened.	Belirli bir yetenek için parlama animasyonlarını veya altın stack uyarısını özelleştir. Slota değil yeteneğe (Scribing dahil) kaydedilir. Açıldığında otomatik yenilenir.
Switches the Zera UI settings menu and Edit Mode between English and Turkish. Requires a UI reload.	Zera UI ayarlar menüsünü ve Düzenleme Modunu İngilizce ve Türkçe arasında değiştirir. Arayüz yenilemesi gerektirir.
Open Interactive Edit Mode to drag, snap, resize and customize every widget's fonts, sizes and colors live with full Save/Cancel.	Her bileşenin konumunu, boyutunu, yazı tipini ve renklerini Kaydet/İptal güvencesiyle canlı düzenlemek için Etkileşimli Düzenleme Modunu açar.
Show sample timers, stacks, buffs, sets and meters while configuring Zera UI.	Zera UI yapılandırılırken örnek süre, stack, buff, set ve göstergeleri gösterir.
Global default HUD font. Widgets set to 'HUD font' inherit this choice.	Genel varsayılan HUD yazı tipi. 'HUD yazı tipi' seçili bileşenler bunu kullanır.
Global default text outline. Widgets set to 'HUD outline' inherit this choice.	Genel varsayılan yazı konturu. 'HUD konturu' seçili bileşenler bunu kullanır.
Restore HUD colors, sizes, positioning and animations. Custom skill tracking rules remain intact.	HUD renklerini, boyutlarını, konumlarını ve animasyonlarını varsayılana döndürür. Özel yetenek takip kuralları korunur.
Zera UI 1.1.6  ·  /zera  ·  /zeraset  ·  Visual sizing, fonts & colors live in Edit HUD.	Zera UI 1.1.6  ·  /zera  ·  /zeraset  ·  Görsel boyut, yazı tipi ve renkler HUD Düzenleyici'dedir.
Darken skills whose Magicka or Stamina cost exceeds your current resource.	Magicka veya Stamina maliyeti mevcut kaynağını aşan yetenekleri karartır.
Darken Blastbones/corpse consumers when ESO reports a corpse is required and none is available.	ESO ceset gerektiğini bildirdiğinde ve uygun ceset olmadığında Blastbones ve ceset tüketen yetenekleri karartır.
Darken enemy-targeted skills when you have no valid attackable target or are out of range.	Saldırılabilir geçerli bir hedefin olmadığında veya menzil dışındayken düşman hedefli yetenekleri karartır.
Shows the observed or inferred Nothing Wasted countdown on Necromancer tether and corpse skills.	Necromancer bağ ve ceset yeteneklerinde gözlenen veya hesaplanan Nothing Wasted geri sayımını gösterir.
NPC Dialogue / Quest Accept	NPC Diyaloğu / Görev Kabul
NPC / Object   [E]	NPC / Nesne   [E]
Tutorial / Info Tip	Öğretici / Bilgi İpucu
Player Name   [F]	Oyuncu Adı   [F]
Removing from area...   [Leave Now]	Bölgeden çıkarılıyorsun...   [Leave Now]
Turn off HUD preview to test on your bar.	Çubuğunda test etmek için önce HUD önizlemesini kapat.
]=])
local fragments={
    {"Combat HUD  /  Appearance  /  Tracking",TR["Combat HUD  /  Appearance  /  Tracking"]},
    {" | Ability ID: "," | Yetenek ID: "},
    {"Skill changed: refresh before saving.",TR["Skill changed: refresh before saving."]},
    {"Mapped effect tracking",TR["Mapped effect tracking"]},
    {"Native timer; add a custom effect to use target/external tracking",TR["Native timer; add a custom effect to use target/external tracking"]},
    {" selected set(s) in filter list."," set filtre listesinde."},
    {"Active font: ","Aktif yazı tipi: "},
    {"Selected: ","Seçili: "},
    {" | Using Univers 67 (font unavailable). Install the .slug and reselect the font."," | Univers 67 kullanılıyor (yazı tipi yok). .slug dosyasını kurup yeniden seç."},
    {" | Optional .slug: verify in Preview; ESO may silently substitute a missing face."," | İsteğe bağlı .slug: Önizlemede doğrula; ESO eksik yazı tipini değiştirebilir."},
    {"Destination: ","Hedef: "},
    {"Saved: ","Kaydedildi: "},{"Error: ","Hata: "},
    {"Self:","Kendi:"},{"Group:","Grup:"},
    {"Default tracking restored: ","Varsayılan takip geri yüklendi: "},
    {"Proc effect saved: ","Proc efekti kaydedildi: "},
    {"Recording stopped: ","Kayıt durduruldu: "},{"Recording finished: ","Kayıt tamamlandı: "},
    {"Previous recording stopped: ","Önceki kayıt durduruldu: "},
    {" distinct effects."," farklı efekt."},{" Result limit reached."," Sonuç sınırına ulaşıldı."},
    {"Recording: ","Kayıt: "},{" result(s), "," sonuç, "},{"s left."," sn kaldı."},
    {"Drag boxes or widget icons • Snap ","Kutuları veya ikonları sürükle • Izgara "},
}
function ZeraUITranslate(value)
    if type(value)~="string" or value=="" then return value end
    if TR[value] then return TR[value] end
    local color,inner,finish=value:match("^(|c%x%x%x%x%x%x)(.-)(|r)$")
    if color and TR[inner] then return color..TR[inner]..finish end
    for _,pair in ipairs(fragments) do
        local from,to=pair[1],pair[2]
        local i,j=value:find(from,1,true)
        if i then value=value:sub(1,i-1)..to..value:sub(j+1) end
    end
    return value
end
