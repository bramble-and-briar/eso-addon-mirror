-- =================================================================================================
-- Dolgubon's Lazy Writ Crafter: українська мова.
-- Аналог файлу Languages/<мова>.lua самого адона: розпізнавання замовлень (parser, languageInfo)
-- і назви налаштувань. Застосовується до ініціалізації Writ Crafter (Prepare), тож меню будується українською.
-- =================================================================================================

local DovahMova = DovahMova

local function ApplyUkrainianLanguage()
	-- =================================================================================================
	-- Розпізнавання замовлень
	-- =================================================================================================

	WritCreater.hirelingMailSubjects = {
		["Матеріали від коваля"] = true, ["Матеріали від кравця"] = true, ["Матеріали від тесляра"] = true, ["Матеріали від зачарувальника"] = true,
		["Інгредієнти від постачальника"] = true, ["Матеріали від ювеліра"] = true,
	}

	function WritCreater.langWritNames()
		return { ["G"] = "замовлення", [CRAFTING_TYPE_ENCHANTING] = "Зачарувальницьке", [CRAFTING_TYPE_BLACKSMITHING] = "Ковальське", [CRAFTING_TYPE_CLOTHIER] = "Кравецьке",
		[CRAFTING_TYPE_PROVISIONING] = "Постачальницьке", [CRAFTING_TYPE_WOODWORKING] = "Теслярське", [CRAFTING_TYPE_ALCHEMY] = "Алхімічне", [CRAFTING_TYPE_JEWELRYCRAFTING] = "Ювелірне", }
	end

	function WritCreater.langCraftKernels()
		return { [CRAFTING_TYPE_ENCHANTING] = "Зачарув", [CRAFTING_TYPE_BLACKSMITHING] = "Коваль", [CRAFTING_TYPE_CLOTHIER] = "Кравец", [CRAFTING_TYPE_PROVISIONING] = "Постачан",
		[CRAFTING_TYPE_WOODWORKING] = "Тесляр", [CRAFTING_TYPE_ALCHEMY] = "Алхім", [CRAFTING_TYPE_JEWELRYCRAFTING] = "Ювелір", }
	end

	function WritCreater.writCompleteStrings()
		return { ["place"] = "<Покладіть товари до скрині.>", ["sign"] = "<Покладіть товари до скрині.>", ["masterPlace"] = "Я закінчив", ["masterSign"] = "<Завершити роботу.>",
		["masterStart"] = "<Прийняти контракт.>", ["Rolis Hlaalu"] = "Роліс Глаалу", ["Deliver"] = "Доставити", ["Acquire"] = "Отримати", }
	end

	function WritCreater.langStationNames()
		return { ["Ковальський верстат"] = 1, ["Кравецький верстат"] = 2, ["Зачарувальний стіл"] = 3, ["Алхімічна лабораторія"] = 4, ["Вогнище"] = 5,
		["Теслярський верстат"] = 6, ["Станція ювелірної справи"] = 7, }
	end

	-- =================================================================================================
	-- РОЗУМНИЙ ПАРСЕР v2 (з розпізнаванням кількості)
	-- Ми повністю перезаписуємо оригінальну функцію розбору квестів
	-- =================================================================================================

	function WritCreater.parser(condition)
		if not condition then return end

		local langInfo = WritCreater.languageInfo()
		local craftType = GetCraftingInteractionType()

		if not langInfo[craftType] then return end -- Перевіряємо, чи є дані для поточної професії

		local pieces = langInfo[craftType]["pieces"]
		local materials = langInfo[craftType]["match"]

		-- Словник для розпізнавання кількості
		local number_map = { ["один"]=1, ["два"]=2, ["три"]=3, ["чотири"]=4, ["п'ять"]=5, ["шість"]=6, ["сім"]=7, ["вісім"]=8, ["дев'ять"]=9 }

		local amount = 1 -- За замовчуванням кількість 1
		
		-- Шукаємо, чи є в тексті слово, що позначає кількість
		for word, number in pairs(number_map) do
			if string.find(condition, word) then
				amount = number
				break
			end
		end
		
		-- Шукаємо ключові слова у тексті квесту
		for piece_key, piece_name in pairs(pieces) do
			if string.find(condition, piece_name) then
				for material_key, material_name in pairs(materials) do
					if string.find(condition, material_name) then
						-- Ми знайшли збіг! Повертаємо дані, які мод очікує
						local result = {}
						result.patternIndex = piece_key
						result.materialIndex = material_key
						result.amount = amount -- Додаємо знайдену кількість
						return result
					end
				end
			end
		end

		return nil -- Якщо нічого не знайдено
	end


	-- =================================================================================================
	-- ITEM DATABASE / БАЗА ПРЕДМЕТІВ (Змінено для нової логіки)
	-- =================================================================================================
	function WritCreater.languageInfo()
		local craftInfo = {
			[CRAFTING_TYPE_CLOTHIER] = {
				["pieces"] = {
					[1] = "шата",
					[2] = "жакет",
					[3] = "черевики",
					[4] = "рукавички",
					[5] = "капелюх",
					[6] = "шатни",
					[7] = "еполети",
					[8] = "пасок",
					[9] = "куртка",
					[10] = "полуботки",
					[11] = "наручі",
					[12] = "каптур",
					[13] = "наголінники",
					[14] = "оплічники",
					[15] = "пояс",
				},
				["match"] = {
					[1] = "Домашн",
					[2] = "Ллян",
					[3] = "Бавовнян",
					[4] = "Павутинн",
					[5] = "Ебенов",
					[6] = "Крешов",
					[7] = "Залізоткан",
					[8] = "Срібноткан",
					[9] = "Тінепряден",
					[10] = "Пращурошовк",
					[11] = "Сиром'ятн",
					[12] = "Шкірян",
					[13] = "Гарбован",
					[14] = "Цільногарбован",
					[15] = "Міцн",
					[16] = "Бригантинов",
					[17] = "Залізношкір",
					[18] = "Пречудов",
					[19] = "Тінешкір",
					[20] = "Рубедогартован",
				},
			},

			[CRAFTING_TYPE_BLACKSMITHING] = {
				["pieces"] = {
					[1] = "сокира",
					[2] = "булава",
					[3] = "меч",
					[4] = "бойова",
					[5] = "молот",
					[6] = "дворучний меч",
					[7] = "кинджал",
					[8] = "кіраса",
					[9] = "сабатони",
					[10] = "рукавиці",
					[11] = "шолом",
					[12] = "поножі",
					[13] = "наплічники",
					[14] = "ремінь",
				},
				["match"] = {
					[1] = "Залізн",
					[2] = "Сталев",
					[3] = "Оріхалков",
					[4] = "Дварвенськ",
					[5] = "Ебонітов",
					[6] = "Кальцинієв",
					[7] = "Галатитов",
					[8] = "Ртутн",
					[9] = "Пустотн",
					[10] = "Рубедітов",
				},
			},

			[CRAFTING_TYPE_WOODWORKING] = {
				["pieces"] = {
					[1] = "лук",
					[2] = "щит",
					[3] = "вогняний",
					[4] = "крижаний",
					[5] = "блискавичний",
					[6] = "посох відновлення",
				},
				["match"] = {
					[1] = "Кленов",
					[2] = "Дубов",
					[3] = "Буков",
					[4] = "Гікорійн",
					[5] = "Тисов",
					[6] = "Березов",
					[7] = "Ясенев",
					[8] = "Червонодеревн",
					[9] = "Нічнодеревн",
					[10] = "Рубіноясенев",
				},
			},

			-- ЗМІНА: Використовуємо називний відмінок для іменників та корінь слова для прикметників, щоб наша нова функція їх знайшла
			[CRAFTING_TYPE_JEWELRYCRAFTING] = {
				["pieces"] = {
					[1] = "перстень",
					[2] = "намисто",
				},
				["match"] = {
					[1] = "Олов'ян",
					[2] = "Мідн",
					[3] = "Срібн",
					[4] = "Електрумов",
					[5] = "Платинов",
				},
			},

			[CRAFTING_TYPE_ENCHANTING] = {
				["pieces"] = {
					{"disease", 45841, 2},
					{"foulness", 45841, 1},
					{"absorb stamina", 45833, 2},
					{"absorb magicka", 45832, 2},
					{"absorb health", 45831, 2},
					{"frost resist", 45839, 2},
					{"frost", 45839, 1},
					{"feat", 45836, 2},
					{"stamina recovery", 45836, 1},
					{"hardening", 45842, 1},
					{"crushing", 45842, 2},
					{"onslaught", 68342, 2},
					{"defense", 68342, 1},
					{"shielding", 45849, 2},
					{"bashing", 45849, 1},
					{"poison resist", 45837, 2},
					{"poison", 45837, 1},
					{"spell harm", 45848, 2},
					{"magical", 45848, 1},
					{"magicka recovery", 45835, 1},
					{"spell cost", 45835, 2},
					{"shock resist", 45840, 2},
					{"shock", 45840, 1},
					{"health recovery", 45834, 1},
					{"decrease health", 45834, 2},
					{"weakening", 45843, 2},
					{"weapon", 45843, 1},
					{"boost", 45846, 1},
					{"speed", 45846, 2},
					{"flame resist", 45838, 2},
					{"flame", 45838, 1},
					{"decrease physical", 45847, 2},
					{"increase physical", 45847, 1},
					{"stamina", 45833, 1},
					{"health", 45831, 1},
					{"magicka", 45832, 1},
				},
				["match"] = {
					[1] = {"Trifling", 45855},
					[2] = {"Inferior", 45856},
					[3] = {"Petty", 45857},
					[4] = {"Slight", 45806},
					[5] = {"Minor", 45807},
					[6] = {"Lesser", 45808},
					[7] = {"Moderate", 45809},
					[8] = {"Average", 45810},
					[9] = {"Strong", 45811},
					[10] = {"Major", 45812},
					[11] = {"Greater", 45813},
					[12] = {"Grand", 45814},
					[13] = {"Splendid", 45815},
					[14] = {"Monumental", 45816},
					[15] = {"Truly", {68341, 68340}},
					[16] = {"Superb", {64509, 64508}},
				},
				["quality"] = {
					{"Normal", 45850},
					{"Fine", 45851},
					{"Superior", 45852},
					{"Epic", 45853},
					{"Legendary", 45854},
					{"", 45850},
				},
			},
		}
		return craftInfo
	end

	-- =================================================================================================
	-- НАЛАШТУВАННЯ ІНТЕРФЕЙСУ / SETTINGS TRANSLATIONS
	-- =================================================================================================
	
	-- Створюємо optionStrings для української локалізації
	WritCreater.optionStrings = WritCreater.optionStrings or {}
	
	-- Основні налаштування
	WritCreater.optionStrings.nowEditing = "Ви змінюєте налаштування %s"
	WritCreater.optionStrings.accountWide = "Для всього акаунту"
	WritCreater.optionStrings.characterSpecific = "Для персонажа"
	WritCreater.optionStrings.useCharacterSettings = "Використовувати налаштування персонажа"
	WritCreater.optionStrings.useCharacterSettingsTooltip = "Використовувати налаштування тільки для цього персонажа"
	
	-- Налаштування стилів
	WritCreater.optionStrings["style tooltip"] = function (styleName, styleStone) 
		return zo_strformat("Дозволити використання стилю <<1>>, який використовує камінь стилю "..styleStone.." для крафту", styleName, styleStone) 
	end
	WritCreater.optionStrings["smart style slot save"] = "Найменша кількість спочатку"
	WritCreater.optionStrings["smart style slot save tooltip"] = "Спроба мінімізувати використовувані слоти, якщо немає ESO+, використовуючи спочатку менші стопки каменів стилю"
	
	-- Налаштування крафту
	WritCreater.optionStrings["show craft window"] = "Показати вікно крафту"
	WritCreater.optionStrings["show craft window tooltip"] = "Показує вікно крафту при відкритті верстату"
	WritCreater.optionStrings["autocraft"] = "Автокрафт"
	WritCreater.optionStrings["autocraft tooltip"] = "При виборі цього мод почне крафтити одразу після входу на верстат. Якщо вікно не показано, це буде увімкнено"
	
	-- Налаштування професій
	WritCreater.optionStrings["blackmithing"] = "Ковальство"
	WritCreater.optionStrings["blacksmithing tooltip"] = "Увімкнути мод для ковальства"
	WritCreater.optionStrings["clothing"] = "Кравецтво"
	WritCreater.optionStrings["clothing tooltip"] = "Увімкнути мод для кравецтва"
	WritCreater.optionStrings["woodworking"] = "Теслярство"
	WritCreater.optionStrings["woodworking tooltip"] = "Увімкнути мод для теслярства"
	WritCreater.optionStrings["jewelry crafting"] = "Ювелірна справа"
	WritCreater.optionStrings["jewelry crafting tooltip"] = "Увімкнути мод для ювелірної справи"
	WritCreater.optionStrings["provisioning"] = "Постачання"
	WritCreater.optionStrings["provisioning tooltip"] = "Увімкнути мод для постачання. Рекомендується заздалегідь крафтити стопки необхідних предметів, але крафт підтримується"
	WritCreater.optionStrings["enchanting"] = "Зачарування"
	WritCreater.optionStrings["enchanting tooltip"] = "Увімкнути мод для зачарування"
	WritCreater.optionStrings["alchemy"] = "Алхімія"
	WritCreater.optionStrings["alchemy tooltip"] = "Увімкнути мод для алхімії. Рекомендується заздалегідь крафтити стопки необхідних предметів, але крафт підтримується"
	WritCreater.optionStrings["alchemyChoices"] = {"Вимкнено","Всі функції","Пропустити автокрафт"}
	
	-- Налаштування квестів
	WritCreater.optionStrings["writ grabbing"] = "Вилучити предмети замовлень"
	WritCreater.optionStrings["writ grabbing tooltip"] = "Забирати предмети, необхідні для замовлень (наприклад, нірнрут, Та тощо) з банку"
	WritCreater.optionStrings["automatic complete"] = "Автоматичний діалог квестів"
	WritCreater.optionStrings["automatic complete tooltip"] = "Автоматично приймає та завершує діалоги квестів на дошках замовлень та здачі"
	WritCreater.optionStrings["exit when done"] = "Вийти з вікна крафту"
	WritCreater.optionStrings["exit when done tooltip"] = "Вийти з вікна крафту після завершення всього крафту"
	WritCreater.optionStrings["master"] = "Майстер-замовлення"
	WritCreater.optionStrings["master tooltip"] = "Якщо це УВІМКНЕНО, мод буде крафтити активні майстер-замовлення"
	
	-- Налаштування лутінгу
	WritCreater.optionStrings["loot container"] = "Лутати контейнер при отриманні"
	WritCreater.optionStrings["loot container tooltip"] = "Лутати контейнери нагород замовлень при їх отриманні"
	WritCreater.optionStrings["new container"] = "Зберегти статус нового"
	WritCreater.optionStrings["new container tooltip"] = "Зберегти статус нового для контейнерів нагород замовлень"
	WritCreater.optionStrings["master writ saver"] = "Зберегти майстер-замовлення"
	WritCreater.optionStrings["master writ saver tooltip"] = "Запобігає прийняттю майстер-замовлень"
	WritCreater.optionStrings["loot output"] = "Сповіщення про цінні нагороди"
	WritCreater.optionStrings["loot output tooltip"] = "Виводити повідомлення при отриманні цінних предметів з замовлення"
	WritCreater.optionStrings["autoloot behaviour"] = "Поведінка автолуту"
	WritCreater.optionStrings["autoloot behaviour tooltip"] = "Виберіть, коли мод буде автоматично лутати контейнери нагород замовлень"
	WritCreater.optionStrings["autoloot behaviour choices"] = {"Копіювати налаштування з розділу Ігрові налаштування", "Автолут", "Ніколи не автолутати"}
	
	-- Налаштування банку
	WritCreater.optionStrings['autoCloseBank'] = "Автоматичний діалог банку"
	WritCreater.optionStrings['autoCloseBankTooltip'] = "Автоматично входити та виходити з діалогу банку, якщо є предмети для вилучення"
	WritCreater.optionStrings['despawnBanker'] = "Прибрати банкіра (вилучення)"
	WritCreater.optionStrings['despawnBankerTooltip'] = "Автоматично вийти та прибрати банкіра після вилучення предметів"
	WritCreater.optionStrings['despawnBankerDeposit'] = "Вийти та прибрати банкіра (депозити)"
	WritCreater.optionStrings['despawnBankerDepositTooltip'] = "Автоматично прибрати банкіра після депозиту предметів"
	
	-- Налаштування попереджень
	WritCreater.optionStrings['dailyResetWarnType'] = "Попередження про щоденний скидання"
	WritCreater.optionStrings['dailyResetWarnTypeTooltip'] = "Який тип попередження показувати, коли щоденне скидання скоро відбудеться"
	WritCreater.optionStrings['dailyResetWarnTypeChoices'] = {"Нічого","Оголошення", "Вгорі справа", "Чат", "Спливаюче вікно", "Все"}
	WritCreater.optionStrings['dailyResetWarnTime'] = "Хвилин до скидання"
	WritCreater.optionStrings['dailyResetWarnTimeTooltip'] = "Скільки хвилин до щоденного скидання показувати попередження"
	
	-- Інші налаштування
	WritCreater.optionStrings['stealingProtection'] = "Захист від крадіжки"
	WritCreater.optionStrings['stealingProtectionTooltip'] = "Запобігає крадіжці, поки у вас є замовлення в журналі"
	WritCreater.optionStrings['noDELETEConfirmJewelry'] = "Легке знищення ювелірних замовлень"
	WritCreater.optionStrings['noDELETEConfirmJewelryTooltip'] = "Автоматично додавати підтвердження DELETE до діалогу видалення ювелірного замовлення"
	WritCreater.optionStrings['suppressQuestAnnouncements'] = "Приховати оголошення квестів замовлень"
	WritCreater.optionStrings['suppressQuestAnnouncementsTooltip'] = "Приховує текст у центрі екрану при початку замовлення або створенні предмета для нього"
	WritCreater.optionStrings["questBuffer"] = "Буфер квестів замовлень"
	WritCreater.optionStrings["questBufferTooltip"] = "Зберігати буфер квестів, щоб завжди було місце для взяття замовлень"
	
	-- Налаштування множника крафту
	WritCreater.optionStrings['craftMultiplier'] = "Множник крафту (обладунки та гліфи)"
	WritCreater.optionStrings['craftMultiplierTooltip'] = "Крафтити кілька копій кожного необхідного предмета, щоб не потрібно було перекрафчувати їх наступного разу. Примітка: Збережіть приблизно 37 слотів інвентаря для кожного збільшення вище 1"
	WritCreater.optionStrings['smartMultiplier'] = "Розумний множник"
	WritCreater.optionStrings['smartMultiplierTooltip'] = "Якщо увімкнено, Writ Crafter буде крафтити предмети для повного циклу 3 днів замовлень. Також перевірить, чи є у вас вже предмети замовлень, і врахує це. Якщо вимкнено, Writ Crafter просто крафтитиме кілька предметів поточного дня замовлень"
	WritCreater.optionStrings['craftMultiplierConsumables'] = "Множник крафту (алхімія та постачання)"
	WritCreater.optionStrings['craftMultiplierConsumablesTooltip'] = "Одиночний крафт виконає одну дію крафту, яка може бути помножена через пасиви. Повна стопка крафтитиме 100 необхідного предмета, якщо у вас є пасиви множника"
	WritCreater.optionStrings["craftMultiplierConsumablesChoices"] = {"Одиночний крафт","Повна стопка"}
	
	-- Налаштування найманців
	WritCreater.optionStrings['hireling behaviour'] = "Дії з листами найманців"
	WritCreater.optionStrings['hireling behaviour tooltip'] = "Що робити з листами найманців"
	WritCreater.optionStrings['hireling behaviour choices'] = {"Нічого","Лутати та видаляти", "Тільки лутати"}
	
	-- Налаштування статус-бару
	WritCreater.optionStrings["status bar submenu"] = "Налаштування статус-бару"
	WritCreater.optionStrings["status bar submenu tooltip"] = "Налаштування статус-бару"
	WritCreater.optionStrings['showStatusBar'] = "Показати статус-бар"
	WritCreater.optionStrings['showStatusBarTooltip'] = "Показати або приховати статус-бар квестів"
	WritCreater.optionStrings['statusBarIcons'] = "Використовувати іконки"
	WritCreater.optionStrings['statusBarIconsTooltip'] = "Показує іконки крафту замість літер для кожного типу замовлення"
	WritCreater.optionStrings['transparentStatusBar'] = "Прозорий статус-бар"
	WritCreater.optionStrings['transparentStatusBarTooltip'] = "Зробити статус-бар прозорим"
	WritCreater.optionStrings['statusBarInventory'] = "Відстеження інвентаря"
	WritCreater.optionStrings['statusBarInventoryTooltip'] = "Додати відстеження інвентаря до статус-бару"
	WritCreater.optionStrings['incompleteColour'] = "Колір незавершених квестів"
	WritCreater.optionStrings['completeColour'] = "Колір завершених квестів"
	
	-- Налаштування ретикулу
	WritCreater.optionStrings['reticleColour'] = "Змінити колір ретикулу"
	WritCreater.optionStrings['reticleColourTooltip'] = "Змінює колір ретикулу, якщо у вас є незавершене або завершене замовлення на верстаті"
	
	-- Налаштування сканування
	WritCreater.optionStrings["scan for unopened"] = "Відкривати контейнери при вході"
	WritCreater.optionStrings["scan for unopened tooltip"] = "При вході сканувати сумку на наявність невідкритих контейнерів замовлень та спробувати їх відкрити"
	
	-- Налаштування нагород
	WritCreater.optionStrings["writRewards submenu"] = "Обробка нагород замовлень"
	WritCreater.optionStrings["writRewards submenu tooltip"] = "Що робити з усіма нагородами з замовлень"
	WritCreater.optionStrings["allReward"] = "Всі професії"
	WritCreater.optionStrings["allRewardTooltip"] = "Дія для всіх професій"
	WritCreater.optionStrings['sameForALlCrafts'] = "Використовувати ту саму опцію для всіх"
	WritCreater.optionStrings['sameForALlCraftsTooltip'] = "Використовувати ту саму опцію для нагород цього типу для всіх професій"
	
	-- Типи нагород
	WritCreater.optionStrings["matsReward"] = "Нагороди матеріалів"
	WritCreater.optionStrings["matsRewardTooltip"] = "Що робити з нагородами матеріалів крафту"
	WritCreater.optionStrings["surveyReward"] = "Нагороди досліджень"
	WritCreater.optionStrings["surveyRewardTooltip"] = "Що робити з нагородами досліджень"
	WritCreater.optionStrings["masterReward"] = "Нагороди майстер-замовлень"
	WritCreater.optionStrings["masterRewardTooltip"] = "Що робити з нагородами майстер-замовлень"
	WritCreater.optionStrings["repairReward"] = "Нагороди ремонтних наборів"
	WritCreater.optionStrings["repairRewardTooltip"] = "Що робити з нагородами ремонтних наборів"
	WritCreater.optionStrings["ornateReward"] = "Нагороди орнаментованого спорядження"
	WritCreater.optionStrings["ornateRewardTooltip"] = "Що робити з нагородами орнаментованого спорядження"
	WritCreater.optionStrings["intricateReward"] = "Нагороди складного спорядження"
	WritCreater.optionStrings["intricateRewardTooltip"] = "Що робити з нагородами складного спорядження"
	WritCreater.optionStrings["soulGemReward"] = "Порожні душі"
	WritCreater.optionStrings["soulGemTooltip"] = "Що робити з порожніми душами"
	WritCreater.optionStrings["glyphReward"] = "Гліфи"
	WritCreater.optionStrings["glyphRewardTooltip"] = "Що робити з гліфами"
	WritCreater.optionStrings["recipeReward"] = "Рецепти"
	WritCreater.optionStrings["recipeRewardTooltip"] = "Що робити з рецептами"
	WritCreater.optionStrings["fragmentReward"] = "Фрагменти Псіїка"
	WritCreater.optionStrings["fragmentRewardTooltip"] = "Що робити з фрагментами Псіїка"
	WritCreater.optionStrings["currencyReward"] = "Золото"
	WritCreater.optionStrings["currencyRewardTooltip"] = "Що робити з золотом нагороди квесту"
	
	-- Вибір дій
	WritCreater.optionStrings["rewardChoices"] = {"Нічого","Депозит","Сміття", "Знищити", "Розібрати"}
	
	-- Налаштування відмови від квестів
	WritCreater.optionStrings["abandon quest for item"] = "Замовлення з 'доставити <<1>>'"
	WritCreater.optionStrings["abandon quest for item tooltip"] = "Якщо ВИМКНЕНО, автоматично відмовиться від замовлень, що вимагають доставити <<1>>. Квести, що вимагають крафтити предмет з <<1>>, не будуть відхилені"
	
	-- Налаштування інтерфейсу
	WritCreater.optionStrings["skin"] = "Скін Writ Crafter"
	WritCreater.optionStrings["skinTooltip"] = "Скін для інтерфейсу Writ Crafter"
	WritCreater.optionStrings["skinOptions"] = {"За замовчуванням", "Сирний", "Козячий"}
	WritCreater.optionStrings["goatSkin"] = "Козячий"
	WritCreater.optionStrings["cheeseSkin"] = "Сирний"
	WritCreater.optionStrings["defaultSkin"] = "За замовчуванням"
	
	-- Інші налаштування
	WritCreater.optionStrings["jubilee"] = "Лутати коробки ювілею/Зенітара"
	WritCreater.optionStrings["jubilee tooltip"] = "Автоматично лутає коробки ювілею та Зенітара"
	WritCreater.optionStrings['craftHousePort'] = "Телепорт до будинку крафту"
	WritCreater.optionStrings['craftHousePortTooltip'] = "Телепорт до публічно доступного будинку крафту"
	
	-- Налаштування для конкретних професій
	WritCreater.optionStrings['1Reward'] = "Ковальство"
	WritCreater.optionStrings['2Reward'] = "Використовувати для всіх"
	WritCreater.optionStrings['3Reward'] = "Використовувати для всіх"
	WritCreater.optionStrings['4Reward'] = "Використовувати для всіх"
	WritCreater.optionStrings['5Reward'] = "Використовувати для всіх"
	WritCreater.optionStrings['6Reward'] = "Використовувати для всіх"
	WritCreater.optionStrings['7Reward'] = "Використовувати для всіх"

	-- =================================================================================================
	-- ФІНАЛЬНІ НАЛАШТУВАННЯ
	-- =================================================================================================
	WritCreater.lang = "ua"
	WritCreater.langIsMasterWritSupported = true
end

-- -------------------------------------------------------------------------------------------------
-- Таблиці «назва предмета -> дані»: WritCreater.boxNames (скриньки-нагороди) і
-- WritCreater.sealedWritNames (печатки майстерних замовлень).
-- Writ Crafter заповнює їх під час завантаження назвами з GetItemLinkName — ще до хуків DovahMova,
-- тобто «сирими» назвами. Потім шукає там назву з GetItemName/GetItemLinkName, яку DovahMova вже
-- обробив (узгоджені прикметники, «(English)»), і падає на nil (LootHandler.lua: countContainers).
-- Тому при промаху шукаємо за нормалізованою назвою: без англійського постфікса і граматичних тегів.
-- -------------------------------------------------------------------------------------------------

local function NormalizeItemName(name)
	if type(name) ~= "string" then
		return name
	end
	local processed = DovahMova.Adjectives.ProcessItemName(DovahMova.Util.StripPostfix(name))
	return DovahMova.Util.ToKey(DovahMova.Util.StripPostfix(processed))
end

local function MakeNameLookupTolerant(namesTable)
	local normalized
	setmetatable(namesTable, {
		__index = function(_, name)
			if not normalized then
				normalized = {}
				for itemName, data in pairs(namesTable) do
					normalized[NormalizeItemName(itemName)] = data
				end
			end
			return normalized[NormalizeItemName(name)]
		end,
	})
end

DovahMova.RegisterIntegration({
	name = "DolgubonsLazyWritCreator",
	IsAvailable = function()
		return WritCreater ~= nil
	end,
	Prepare = ApplyUkrainianLanguage,
	Apply = function()
		for _, namesTable in ipairs({ WritCreater.boxNames, WritCreater.sealedWritNames }) do
			if type(namesTable) == "table" and getmetatable(namesTable) == nil then
				MakeNameLookupTolerant(namesTable)
			end
		end
	end,
})
