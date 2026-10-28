-----------------------------------------------------------------------------------
-- Addon Name: Dolgubon's Lazy Writ Crafter
-- Creator: Dolgubon (Joseph Heinzle)
-- Addon Ideal: Simplifies Crafting Writs as much as possible
-- Addon Creation Date: March 14, 2016
--
-- File Name: Languages/default.lua
-- File Description: Russian Localization
-- File translator: @Torvard

-----------------------------------------------------------------------------------

local function myLower(str)
	return zo_strformat("<<z:1>>",str)
end

function WritCreater.getWritAndSurveyType(link)
	if not WritCreater.langCraftKernels then return end
	local itemName = GetItemLinkName(link)
	local kernels = WritCreater.langCraftKernels()
	local craftType
	for craft, kernel in pairs(kernels) do
		if string.find(myLower(itemName), myLower(kernel)) then
			craftType = craft
		end
	end
	return craftType
end

local function proper(str)
	if type(str)== "string" then
		return zo_strformat("<<C:1>>",str)
	else
		return str
	end
end

WritCreater.hirelingMailSubjects = WritCreater.hirelingMailSubjects or {}
WritCreater.hirelingMailSubjects["Сырье для зачарователя"] = true -- Raw Enchanter Materials
WritCreater.hirelingMailSubjects["Сырье для портного"] = true -- Raw Clothier Materials
WritCreater.hirelingMailSubjects["Сырье для кузнеца"] = true -- Raw Blacksmith Materials
WritCreater.hirelingMailSubjects["Сырье для столяра"] = true -- Raw Woodworker Materials
WritCreater.hirelingMailSubjects["Сырье для снабженца"] = true -- Raw Provisioner Materials

local function runeMissingFunction (ta,essence,potency)
	local missing = {}
	if not ta["bag"] then
		missing[#missing + 1] = "|rTa|cf60000"
	end
	if not essence["bag"] then
		missing[#missing + 1] =  "|cffcc66"..essence["slot"].."|cf60000"
	end
	if not potency["bag"] then
		missing[#missing + 1] = "|c0066ff"..potency["slot"].."|r"
	end
	local text = ""
	for i = 1, #missing do
		if i ==1 then
			text = "|cff3333Глиф не может быть создан. У вас нет ни одной руны "..(missing[i])
		else
			text = text.." или "..(missing[i])
		end
	end
	return text
end

-- Note for translators: I recommend translating this first dailyResetFunction only and skipping+removing the second dailyResetFunction.
local function dailyResetFunction(till) 
	d(zo_strformat("<<1>> ч. и <<2>> мин. до сброса ежедневных заданий.",till["hour"],till["minute"])) 
end

local function dailyResetFunction(till, stamp)
	if till["hour"]==0 then
		if till["minute"]==1 then
			return "1 мин. до сброса ежедневных заданий!"
		elseif till["minute"]==0 then
			if stamp==1 then
				return "Ежедневные заданий сбросятся через "..stamp.." сек.!"
			else
				return "Серьёзно?! Хватит спрашивать! Ты настолько нетерпелив??? Они сбросятся через пару секунд, проклятье! Тупые, так называемые ММО-шники! *Бур-Бур-Бур*"
			end
		else
			return till["minute"].." мин. до сброса ежедневных заданий!"
		end
	elseif till["hour"]==1 then
		if till["minute"]==1 then
			return till["hour"].." ч. и "..till["minute"].." мин. до сброса ежедневных заданий"
		else
			return till["hour"].." ч. и "..till["minute"].." мин. до сброса ежедневных заданий"
		end
	else
		if till["minute"]==1 then
			return till["hour"].." ч. и "..till["minute"].." мин. до сброса ежедневных заданий"
		else
			return till["hour"].." ч. и "..till["minute"].." мин. до сброса ежедневных заданий"
		end
	end 
end

local function masterWritSmithCraft (link, trait, style, quality, writName, usedMimicStone)
	if usedMimicStone then
		return zo_strformat("<<t:5>>: Создать предмет уровня ОГ150, комплекта <<t:1>>, с особенностью <<t:2>>, в стиле <<t:3>> и качеством <<t:4>> с использованием камня-хамелеона ", link, trait, style, quality, writName)
	else
		return zo_strformat("<<t:5>>: Создать предмет уровня ОГ150, комплекта <<t:1>>, с особенностью <<t:2>>, в стиле <<t:3>> и качеством <<t:4>>", link, trait, style, quality, writName)
	end
end

WritCreater.missingTranslations = {}
WritCreater.missingTranslationsOrder = {}
local stringIndexTable = {}
local findMissingTranslationsMetatable = 
{
["__newindex"] = function(t,k,v) if not stringIndexTable[tostring(t)] then stringIndexTable[tostring(t)] = {} end stringIndexTable[tostring(t)][k] = v WritCreater.missingTranslations[k] = {k, v}
WritCreater.missingTranslationsOrder[#WritCreater.missingTranslationsOrder+1] = {k, v}
 end,
["__index"] = function(t, k) return stringIndexTable[tostring(t)][k] end,
}

WritCreater.strings = WritCreater.strings or {}
setmetatable(WritCreater.strings, findMissingTranslationsMetatable)

WritCreater.strings["runeReq"] 					= function (essence, potency,taStack,essenceStack,potencyStack) 
	return zo_strformat("|c2dff00Для создания потребуются руны 1/<<3>> |rTa|c2dff00, 1/<<4>> |cffcc66<<1>>|c2dff00 и 1/<<5>> |c0066ff<<2>>|r", 
		essence, potency, taStack, essenceStack, potencyStack) 
end
WritCreater.strings["runeMissing"]                              = runeMissingFunction
WritCreater.strings["notEnoughSkill"]				= "У вас недостаточно высокий уровень навыка, чтобы создать требуемую экипировку"
WritCreater.strings["smithingMissing"] 			        = "\n|cf60000У вас недостаточно материалов|r"
WritCreater.strings["craftAnyway"] 				= "Создать сколько получится"
WritCreater.strings["smithingEnough"] 				= "\n|c2dff00У вас достаточно материалов|r"
WritCreater.strings["craft"] 					= "|c00ff00Создать|r"
WritCreater.strings["crafting"] 			        = "|c00ff00Создание...|r"
WritCreater.strings["craftIncomplete"] 			        = "|cf60000Создание не может быть завершено.\nВам нужно больше материалов|r"
WritCreater.strings["moreStyle"] 				= "|cf60000У вас нет ни одного доступного стилевого материала.\nПроверьте свой инвентарь, достижения и настройки|r"
WritCreater.strings["moreStyleSettings"]			= "|cf60000У вас нет ни одного доступного стилевого материала.\nВозможно, вам нужно разрешить использовать больше стилей в меню настроек|r"
WritCreater.strings["moreStyleKnowledge"]			= "|cf60000У вас нет ни одного доступного стилевого материала.\nВозможно, вам нужно изучить больше ремесленных стилей|r"
WritCreater.strings["dailyreset"] 				= dailyResetFunction
WritCreater.strings["complete"] 				= "|c00FF00Заказ выполнен|r"
WritCreater.strings["craftingstopped"]				= "Создание прекращено. Пожалуйста, проверьте, что аддон создал правильные предметы"
WritCreater.strings["smithingReqM"] 				= function (amount, type, more) return zo_strformat( "Для создания потребуется <<1>> <<2>> (|cf60000нужно ещё <<3>>|r)" ,amount, type, more) end
WritCreater.strings["smithingReq"] 				= function (amount,type, current) return zo_strformat( "Для создания потребуется <<1>> <<2>> (|c2dff00<<3>> доступно|r)"  ,amount, type, 
													zo_strformat(SI_NUMBER_FORMAT, ZO_AbbreviateNumber(current, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_LOWERCASE_NUMBER_SUFFIXES))) end
WritCreater.strings["lootReceived"]				= "Получено: <<3>> <<1>> (у вас есть: <<2>>)"
WritCreater.strings["lootReceivedM"]				= "Получено: <<1>>"
WritCreater.strings["countSurveys"]				= "У вас есть всего исследований: <<1>>"
WritCreater.strings["countVouchers"]				= "У вас есть неполученные ремесленные расписки: <<1>>"
WritCreater.strings["includesStorage"] 			        = function(type) local a= {"Исследования", "Мастерские заказы"} a = a[type] return zo_strformat("Подсчёт включает <<1>> в домашнем хранилище", a) end
WritCreater.strings["surveys"]					= "Исследования"
WritCreater.strings["sealedWrits"]				= "Запечатанные заказы"
WritCreater.strings["newMasterWritSmithToCraft"]	        = masterWritSmithCraft
WritCreater.strings["withdrawItem"]			        = function(amount, link, remaining) return "Writ Crafter забрал из банка \""..link.."\" в количестве: "..amount.." (в банке осталось: "..remaining..")" end
WritCreater.strings["fullBag"]				        = "У вас нет свободного места в инвентаре. Пожалуйста, освободите свою сумку"
WritCreater.strings["masterWritSave"]			        = "Writ Crafter уберёг вас от случайного принятия Мастерского заказа! Идите в настройки, чтобы отключить эту функцию"
WritCreater.strings["missingLibraries"]			        = "Writ Crafter требуются следующие отдельно установленные библиотеки. Пожалуйста, скачайте, установите или включите следующие библиотеки:"
WritCreater.strings["resetWarningMessageText"]		        = "Сброс ремесленных заданий произойдет через <<1>> ч. и <<2>> мин.\nВы можете настроить или выключить это предупреждение в настройках"
WritCreater.strings["resetWarningExampleText"]		        = "Предупреждение будет выглядеть так"
WritCreater.strings["lowInventory"]			        = "\nМеста в инвентаре всего <<1>> и этого может не хватить"
WritCreater.strings['masterWritQueueCleared']		= "Очередь на создание Мастерских заказов очищена"
WritCreater.strings['multiplierCraftPrediction']	= "Создание <<2>> предметов для <<1[/$d циклов/$d циклов]>> заказов"

WritCreater.strings['alchemyNoCombo']				= "Не удалось найти достаточно дешёвую комбинацию известных реагентов. Попробуйте приобрести другие виды алхимических предметов"
WritCreater.strings['alchemyMissing']				= 
function(missingTable)
	local missingOut = "Вам не хватает "
	for missingItemId, v in pairs(missing) do
		missingOut = missingOut..getItemLinkFromItemId(missingItemId).." "
	end
	missingOut = missingOut..", чтобы создать самую дешевую комбинацию"
	return missingOut
end
WritCreater.strings['alchemyLowPassive']			= "Вы выбрали создание полной стопки предметов, но у вас не активны пассивные ремесленные навыки умножения"
WritCreater.strings['alchemyCraftReqs']				= "Для создания потребуется <<t:4>> <<t:1>>, <<t:4>> <<t:2>> и <<t:4>> <<t:3>>"
WritCreater.strings['alchemyMasterReqs']			= "<<t:1>>: Создать <<t:2>> с использованием <<t:3>>, <<t:4>> и <<t:5>>"
WritCreater.strings['depositGold']					= "Writ Crafter положил в банк <<1>> золота"
WritCreater.strings['depositItemMissing']			= "Writ Crafter не смог найти <<t:1>>, чтобы положить в банк. Возможно, предмет был уничтожен или перемещен"
WritCreater.strings['depositItem']					= "Writ Crafter положил в банк <<t:1>>"
WritCreater.strings['welcomeMessage']				= "Спасибо, что установили Dolgubon's Lazy Writ Crafter! Пожалуйста, ознакомьтесь с настройками, чтобы настроить поведение аддона"
WritCreater.strings['keybindStripBlurb']			= "Создать предметы для заказа"
WritCreater.strings['pressToCraft']					= "\nНажмите |t32:32:<<1>>|t для создания"
WritCreater.strings['goldenPursuitCraft']			= "Изготовить набор предметов для незаконченных этапов Золотого стремления?\n(Возможно, не получится ничего изготовить, только топор/лук/кольцо/мантию, используя железо)"
WritCreater.strings['fullInventory']				= "Ваш инвентарь полон"
WritCreater.strings['provisioningUnknownRecipe']	= "Вы не знаете рецепта для <<1>>"
WritCreater.strings['provisioningCraft']			= "Аддон создаст <<1>>"
WritCreater.strings['transmuteLooted']				= "Получено камней трансмутации: <<1>> (у вас есть: <<2>>)"
WritCreater.strings['transmuteLimitApproach']		= "Вы приближаетесь к пределу количества камней трансмутации. Если в коробке будет превышен лимит количества камней трансмутации, то аддон не будет их забирать"
WritCreater.strings['transmuteLimitHit']			= "Получение этих камней трансмутации превысило бы ваш максимум, поэтому <<1>> камней трансмутации не были получены"
WritCreater.strings['lootingMarkJunk']				= "Writ Crafter пометил <<1>> как хлам"
WritCreater.strings['lootingDestroyItem']			= "Writ Crafter уничтожил <<1>>, потому что вы указали это в меню настроек"
WritCreater.strings['lootingDeconItem']				= "Writ Crafter поставил <<1>> в очередь на разбор"
WritCreater.strings['lootingDeposit']				= "Writ Crafter поставил в очередь на внесение в банк <<1>>"
WritCreater.strings['mailComplete']					= "Writ Crafter: Получение почты наемников завершено!"
WritCreater.strings['mailNumLoot']					= "Writ Crafter: Найдено писем наемников: <<1>>"
WritCreater.strings['masterRecipeUnknown']			= "<<t:1>>: Не удалось поставить в очередь, так как вы не знаете рецепта для <<t:2>>"
WritCreater.strings['masterEnchantCraft']			= "<<t:1>>: Создать <<t:2>>"
WritCreater.strings['masterRecipeCraft']			= "<<t:1>>: Создать <<t:3>>x <<t:2>>"
WritCreater.strings['masterRecipeError']			= "<<1>>: Не удалось получить заказ. Возможно, вы не знаете нужный рецепт"
WritCreater.strings['masterQueueNotFound']			= "Не удалось определить, сколько предметов нужно изготовить. Попробуйте принять заказ"
WritCreater.strings['masterQueueBlurb']				= "Создать заказ"
WritCreater.strings['masterQueueSummary']			= "Writ Crafter поставил в очередь запечатанных заказов: <<1>>"
WritCreater.strings['abandonQuestBanItem']			= "Writ Crafter отказался от <<1>>, потому что для этого требуется <<2>>, использование которого было запрещено в настройках"
WritCreater.strings['writBufferNotification']		= "Буфер заданий от Lazy Writ Crafter™ не позволяет вам принять это задание"
WritCreater.strings['masterStopAcceptNoCraftSkill'] = "Lazy Writ Crafter™ не позволил вам принять этот заказ, потому что вы не можете его создать"
WritCreater.strings['stealingProtection'] 			= "Lazy Writ Crafter™ уберёг вас от воровства во время выполнения заказов!"
WritCreater.strings['statsWitsDone']				= "Заказов выполнено: <<1>> за последние <<2>> дней"
WritCreater.strings['deconstructSuccess']			= "Writ Crafter разобрал <<1>>"
WritCreater.strings['potion']					= "зелье"
WritCreater.strings['poison']					= "яд"
WritCreater.strings['junkSold']					= "Writ Crafter продал все вещи, отмеченные как хлам"
WritCreater.strings['boxLootRemaining']				= "коробок осталось <<1>>/<<2>>"

WritCreater.optionStrings = WritCreater.optionStrings or {}


WritCreater.optionStrings["nowEditing"]				    = "Вы изменяете настройку %s"
WritCreater.optionStrings["accountWide"]			    = "На аккаунт"
WritCreater.optionStrings["characterSpecific"]			    = "Для персонажа"
WritCreater.optionStrings["useCharacterSettings"]		    = "Использовать настройки для персонажа"
WritCreater.optionStrings["useCharacterSettingsTooltip"]	    = "Будут использоваться уникальные настройки для конкретного персонажа вместо единых настроек на весь аккаунт"
WritCreater.optionStrings["style tooltip"]			    = function (styleName) return zo_strformat("Разрешить использовать <<1>> для создания предметов",styleName) end 
WritCreater.optionStrings["show craft window"]			    = "Показать окно аддона"
WritCreater.optionStrings["show craft window tooltip"]  	    = "Показывает окно аддона при использовании ремесленных станков"
WritCreater.optionStrings["autocraft"]                 	     	    = "Автосоздание"
WritCreater.optionStrings["autocraft tooltip"]         	     	    = "При включении этой настройки аддон будет автоматически создавать необходимые для выполнения заказа предметы при использовании ремесленного станка. Если окно аддона выключено, эта настройка будет включена"
WritCreater.optionStrings["blackmithing"]               	    = "Кузнечное дело"
WritCreater.optionStrings["blacksmithing tooltip"]      	    = "Включает аддон для Кузнечного дела"
WritCreater.optionStrings["clothing"]                   	    = "Портняжное дело"
WritCreater.optionStrings["clothing tooltip"]           	    = "Включает аддон для Портняжного дела"
WritCreater.optionStrings["enchanting"]                 	    = "Зачарование"
WritCreater.optionStrings["enchanting tooltip"]         	    = "Включает аддон для Зачарования"
WritCreater.optionStrings["alchemy"]                    	    = "Алхимия"
WritCreater.optionStrings["alchemy tooltip"]   	        	    = "Включает аддон для Алхимии"
WritCreater.optionStrings["alchemyChoices"]			    = {"ВЫКЛ","Все функции","Пропускать авто-крафт"}
WritCreater.optionStrings["provisioning"]               	    = "Снабжение"
WritCreater.optionStrings["provisioning tooltip"]        	    = "Включает аддон для Снабжения"
WritCreater.optionStrings["woodworking"]                	    = "Столярное дело"
WritCreater.optionStrings["woodworking tooltip"]         	    = "Включает аддон для Столярного дела"
WritCreater.optionStrings["jewelry crafting"]			    = "Ювелирное дело"
WritCreater.optionStrings["jewelry crafting tooltip"]		    = "Включает аддон для Ювелирного дела"
WritCreater.optionStrings["writ grabbing"]               	    = "Забирать предметы для заказов"
WritCreater.optionStrings["writ grabbing tooltip"]          	    = "Забирает предметы, необходимые для выполнения заказов (напр., Корень Нирна, Та и т.д. и т.п.), из банка"
WritCreater.optionStrings["style stone menu"]               	    = "Стилевой материал"
WritCreater.optionStrings["style stone menu tooltip"]		    = "Выберите, какой стилевой материал использовать"
WritCreater.optionStrings["send data"]                    	    = "Отправить данные о награде"
WritCreater.optionStrings["send data tooltip"]            	    = "Отправляет данные о награде, полученной из контейнеров за выполнение заказа. Никакая другая информация не будет отправлена"
WritCreater.optionStrings["exit when done"]			    = "Выход из окна крафта"
WritCreater.optionStrings["exit when done tooltip"]		    = "Закрывает окно крафта, когда будут сделаны все необходимые предметы"
WritCreater.optionStrings["automatic complete"]			    = "Авто-квестинг"
WritCreater.optionStrings["automatic complete tooltip"]		    = "Автоматически принимает и завершает задания, когда имеется всё необходимое"
WritCreater.optionStrings["new container"]			    = "Сохранить статус нового"
WritCreater.optionStrings["new container tooltip"]		    = "Сохраняет статус нового для контейнеров в награду за ремесленные заказы"
WritCreater.optionStrings["master"]				    = "Мастерские заказы"
WritCreater.optionStrings["master tooltip"]			    = "Включает модификацию для Мастерских заказов"
WritCreater.optionStrings["right click to craft"]		    = "ПКМ, чтобы создать"
WritCreater.optionStrings["right click to craft tooltip"]	    = "Если настройка ВКЛЮЧЕНА аддон будет создавать Мастерский заказ, который вы ему укажите правым щелчком мыши на запечатанном заказе"
WritCreater.optionStrings["crafting submenu"]			    = "Ежедневные ремесленные заказы"
WritCreater.optionStrings["crafting submenu tooltip"]		    = "Включает аддон для отдельных видов ремесла"
WritCreater.optionStrings["timesavers submenu"]			    = "Экономия времени"
WritCreater.optionStrings["timesavers submenu tooltip"]		    = "Различные возможности небольшой экономии времени"
WritCreater.optionStrings["loot container"]			    = "Открыть контейнер при получении"
WritCreater.optionStrings["loot container tooltip"]		    = "Автоматически открывает контейнеры в награду за ремесленные заказы при получении"
WritCreater.optionStrings["master writ saver"]		            = "Сохранять Мастерские заказы"
WritCreater.optionStrings["master writ saver tooltip"]		    = "Предотвращает принятие Мастерских заказов"
WritCreater.optionStrings["loot output"]			    = "Предупреждение о ценной награде"
WritCreater.optionStrings["loot output tooltip"]		    = "Предупреждает о получении ценного предмета за заказ"
WritCreater.optionStrings["autoloot behaviour"]			    = "Автоматически забирать награду из контейнеров"
WritCreater.optionStrings["autoloot behaviour tooltip"]		    = "Выберите, должен ли аддон автоматически забирать награду из контейнеров"
WritCreater.optionStrings["autoloot behaviour choices"]		    = {"Копировать настройку из настроек игры", "Включен", "Выключен"}
WritCreater.optionStrings["hide when done"]			    = "Скрыть по завершению"
WritCreater.optionStrings["hide when done tooltip"]		    = "Скрывает окно аддона, когда все предметы будут изготовлены"
WritCreater.optionStrings["reticleColour"] 			    = "Цвет прицела"
WritCreater.optionStrings["reticleColourTooltip"] 		    = "Меняет цвет прицела при наведении на станцию, если для данного ремесла имеется невыполненный или выполненный ремесленный заказ"
WritCreater.optionStrings["autoCloseBank"]			    = "Авто-банкинг"
WritCreater.optionStrings["autoCloseBankTooltip"]		    = "Автоматически входит в диалог банка и выходит из него, если из банка требуется забрать предметы"
WritCreater.optionStrings["despawnBanker"]			    = "Отзывать банкира (вывод предметов)"
WritCreater.optionStrings["despawnBankerTooltip"]		    = "Автоматически отзывает банкира после вывода из банка необходимых предметов"
WritCreater.optionStrings["despawnBankerDeposit"]		    = "Отзывать банкира (внесение предметов)"
WritCreater.optionStrings["despawnBankerDepositTooltip"]	    = "Автоматически отзывает банкира после внесения предметов"
WritCreater.optionStrings["dailyResetWarnTime"]			    = "Минут до сброса"
WritCreater.optionStrings["dailyResetWarnTimeTooltip"]		    = "За сколько минут до сброса ежедневных ремесленных заданий должно выводиться предупреждение"
WritCreater.optionStrings["dailyResetWarnType"]			    = "Вид предупреждения"
WritCreater.optionStrings["dailyResetWarnTypeTooltip"]		    = "Какой вид предупреждения должен быть показан перед сбросом"
WritCreater.optionStrings["dailyResetWarnTypeChoices"]		    = {"Нет", "Объявление", "Вверху справа", "Чат", "Всплывающее окно", "Все"}
WritCreater.optionStrings["stealingProtection"]			    = "Защита от воровства"
WritCreater.optionStrings["stealingProtectionTooltip"]		    = "Предотвращает случайное воровство, когда вы находитесь рядом с местом выполнения и сдачи заказа"
WritCreater.optionStrings["noDELETEConfirmJewelry"]		    = "Простое уничтожение ювелирных заказов"
WritCreater.optionStrings["noDELETEConfirmJewelryTooltip"]	    = "Автоматически добавляет текст \"УНИЧТОЖИТЬ\" в окно подтверждения при удалении Ювелирных заказов"
WritCreater.optionStrings["suppressQuestAnnouncements"]		    = "Скрыть квестовое оповещение заказов"
WritCreater.optionStrings["suppressQuestAnnouncementsTooltip"]	    = "Скрывает текст по центру экрана, когда вы принимаете заказ или создаёте предмет для его выполнения"
WritCreater.optionStrings["questBuffer"]			    = "Резервировать место под ремесленные заказы"
WritCreater.optionStrings["questBufferTooltip"]			    = "Резервирует место под ремесленные заказы, чтобы вы всегда могли их принять"
WritCreater.optionStrings["craftMultiplier"]			    = "Множитель создания (снаряжение и глифы)"
WritCreater.optionStrings["craftMultiplierTooltip"]		    = "Создает несколько копий каждого необходимого предмета, чтобы вам не пришлось создавать их при следующем заказе. Примечание: сохраняйте примерно 37 ячеек инвентаря при каждом увеличении на 1 единицу"
WritCreater.optionStrings["craftMultiplierConsumables"]		    = "Множитель создания (алхимия и снабжение)"
WritCreater.optionStrings["craftMultiplierConsumablesTooltip"]	    = "При выборе *Создать один предмет* будет создан один предмет (количество может быть увеличено за счет пассивных ремесленных навыков). При выборе *Создать стопку предметов* будет создано 100 требуемых предметов, если у вас есть пассивные ремесленные навыки"
WritCreater.optionStrings["craftMultiplierConsumablesChoices"]	    = {"Создать один предмет","Создать стопку предметов"}
WritCreater.optionStrings["hireling behaviour"]			    = "Действия с почтой наёмников"
WritCreater.optionStrings["hireling behaviour tooltip"]		    = "Что следует делать с почтой наёмников"
WritCreater.optionStrings["hireling behaviour choices"]		    = { "Ничего","Забрать и удалить", "Только забрать"}


WritCreater.optionStrings["allReward"]				    = "Все виды ремесла"
WritCreater.optionStrings["allRewardTooltip"]			    = "Действия, которые необходимо предпринять для всех видов ремесла"

WritCreater.optionStrings["sameForALlCrafts"]			    = "Использовать один параметр для всех"
WritCreater.optionStrings["sameForALlCraftsTooltip"]		    = "Использует один и тот же параметр для всех наград"
WritCreater.optionStrings["1Reward"]									= "Кузнечное дело"
WritCreater.optionStrings["2Reward"]									= "Использовать для всех"
WritCreater.optionStrings["3Reward"]									= "Использовать для всех"
WritCreater.optionStrings["4Reward"]									= "Использовать для всех"
WritCreater.optionStrings["5Reward"]									= "Использовать для всех"
WritCreater.optionStrings["6Reward"]									= "Использовать для всех"
WritCreater.optionStrings["7Reward"]									= "Использовать для всех"

WritCreater.optionStrings["matsReward"]									= "Материалы"
WritCreater.optionStrings["matsRewardTooltip"]							= "Что делать с материалами"
WritCreater.optionStrings["surveyReward"]								= "Исследования"
WritCreater.optionStrings["surveyRewardTooltip"]						= "Что делать с исследованиями"
WritCreater.optionStrings["masterReward"]								= "Мастерские заказы"
WritCreater.optionStrings["masterRewardTooltip"]						= "Что делать с Мастерскими заказами"
WritCreater.optionStrings["repairReward"]								= "Ремонтные наборы"
WritCreater.optionStrings["repairRewardTooltip"]						= "Что делать с ремонтными наборами"
WritCreater.optionStrings["ornateReward"]								= "Ценное снаряжение"
WritCreater.optionStrings["ornateRewardTooltip"]						= "Что делать с ценным снаряжением"
WritCreater.optionStrings["intricateReward"]							        = "Сложное снаряжение"
WritCreater.optionStrings["intricateRewardTooltip"]						= "Что делать со сложным снаряжением"
WritCreater.optionStrings["soulGemReward"]								= "Пустые камни Душ"
WritCreater.optionStrings["soulGemTooltip"]							= "Что делать с пустыми камнями Душ"
WritCreater.optionStrings["glyphReward"]								= "Глифы"
WritCreater.optionStrings["glyphRewardTooltip"]							= "Что делать с глифами"
WritCreater.optionStrings["recipeReward"]								= "Рецепты"
WritCreater.optionStrings["recipeRewardTooltip"]						= "Что делать с рецептами"
WritCreater.optionStrings["fragmentReward"]								= "Фрагменты Псиджиков"
WritCreater.optionStrings["fragmentRewardTooltip"]						= "Что делать с фрагментами Псиджиков"
WritCreater.optionStrings["currencyReward"]								= "Золото"
WritCreater.optionStrings["currencyRewardTooltip"]						= "Что делать с золотом"
WritCreater.optionStrings["goldMatReward"]								= "Золотые материалы (когда нет ESO+)"
WritCreater.optionStrings["goldMatRewardTooltip"]						= "Что делать с золотыми материалами (подписчикам ESO+ это не нужно)"

WritCreater.optionStrings["writRewards submenu"]						= "Обработка наград за ремесленные заказы"
WritCreater.optionStrings["writRewards submenu tooltip"]				                = "Что делать со всеми наградами за ремесленные заказы"

WritCreater.optionStrings["jubilee"]									= "Открывать праздничные коробки"
WritCreater.optionStrings["jubilee tooltip"]							        = "Автоматически открывает праздничные коробки"
WritCreater.optionStrings["skin"]									= "Скин Writ Crafter"
WritCreater.optionStrings["skinTooltip"]								= "Скин для пользовательского интерфейса Writ Crafter"
WritCreater.optionStrings["skinOptions"]								= {"Стандартный", "Сырный", "Козлиный", "Фантастичный"}
WritCreater.optionStrings["goatSkin"]									= "Козлиный"
WritCreater.optionStrings["cheeseSkin"]									= "Сырный"
WritCreater.optionStrings["fabulousSkin"]								= "Фантастичный"
WritCreater.optionStrings["defaultSkin"]								= "Стандартный"
WritCreater.optionStrings["rewardChoices"]								= {"Ничего","Положить в банк","Отметить как хлам", "Уничтожить", "Разобрать"}
WritCreater.optionStrings["scan for unopened"]							= "Открывать контейнеры при входе в систему"
WritCreater.optionStrings["scan for unopened tooltip"]					= "При входе в систему будет просканирована сумка на предмет неоткрытых контейнеров и попытка их открыть"

WritCreater.optionStrings["smart style slot save"]						= "Экономия слотов камней стиля"
WritCreater.optionStrings["smart style slot save tooltip"]				= "Попытается свести к минимуму количество используемых слотов, если нет ESO+, сначала используя меньшие стопки камней стиля"
WritCreater.optionStrings["abandon quest for item"]						= "Заказы с 'доставить <<1>>'"
WritCreater.optionStrings["abandon quest for item tooltip"]				= "Если ВЫКЛ, автоматически отменит заказы, требующие от вас доставить <<1>>. Задания, требующие от вас создания предмета, требующего <<1>>, не будут отменены"
WritCreater.optionStrings["status bar submenu"]							= "Параметры строки состояния"
WritCreater.optionStrings["status bar submenu tooltip"]					= "Параметры строки состояния"
WritCreater.optionStrings["showStatusBar"]							= "Показать строку состояния"
WritCreater.optionStrings["showStatusBarTooltip"]					= "Показывать или скрывать строку состояния задания"
WritCreater.optionStrings["statusBarIcons"]							= "Использовать значки"
WritCreater.optionStrings["statusBarIconsTooltip"]					= "Отображает ремесленные значки вместо букв для каждого типа задания"
WritCreater.optionStrings["transparentStatusBar"]						= "Прозрачная строка состояния"
WritCreater.optionStrings["transparentStatusBarTooltip"]				= "Делает строку состояния прозрачной"
WritCreater.optionStrings["statusBarInventory"]							= "Трекер инвентаря"
WritCreater.optionStrings["statusBarInventoryTooltip"]					= "Добавляет трекер инвентаря в строку состояния для отслеживания свободного места"
WritCreater.optionStrings["incompleteColour"]							= "Цвет незавершенного задания"
WritCreater.optionStrings["completeColour"]							= "Цвет завершенного задания"
WritCreater.optionStrings['smartMultiplier']							= "Умный множитель"
WritCreater.optionStrings['smartMultiplierTooltip']						= "Если этот параметр включен, Writ Crafter будет создавать предметы для полного цикла трёхдневных заказов. Он также проверит, есть ли у вас какие-либо предметы, связанные с заказами"..
", и учтет их. Если выключен, Writ Crafter просто создаст несколько предметов по заказам текущего дня"
WritCreater.optionStrings['craftHousePort']						= "Посетить дом"
WritCreater.optionStrings['craftHousePortTooltip'] 						= "Перенестись в общедоступный дом c ремесленными станциями"
WritCreater.optionStrings['craftHousePortButton']						= "Переместиться"
WritCreater.optionStrings['reportBug']									= "Сообщить об ошибке"
WritCreater.optionStrings['reportBugTooltip']							= "Создайте тему, чтобы сообщить об ошибках, связанных с консольной версией Writ Crafter. Убедитесь, что о проблеме ещё не сообщалось"
WritCreater.optionStrings['openUrlButtonText']							= "Открыть URL"
WritCreater.optionStrings['donate']										= "Пожертвовать"
WritCreater.optionStrings['donateTooltip']								= "Сделайте пожертвование Dolgubon через Paypal"
WritCreater.optionStrings['writStats']									= "Статистика заказов"
WritCreater.optionStrings['writStatsTooltip']							= "Просмотр истории статистики наград за заказы, выполненные с установленным дополнением"
WritCreater.optionStrings['writStatsButton']							= "Открыть окно"
WritCreater.optionStrings['queueWrits']									= "Очередь заказов"
WritCreater.optionStrings['queueWritsTooltip']							= "Поставит в очередь все запечатанные заказы в вашем инвентаре"
WritCreater.optionStrings['queueWritsButton']							= "Очередь"
WritCreater.optionStrings['mainSettings']								= "Основные настройки"
WritCreater.optionStrings['statusBarHorizontal']						= "Горизонтальное положение"
WritCreater.optionStrings['statusBarHorizontalTooltip']					= "Горизонтальное положение строки состояния"
WritCreater.optionStrings['statusBarVertical']							= "Вертикальное положение"
WritCreater.optionStrings['statusBarVerticalTooltip']					= "Вертикальное положение строки состояния"
WritCreater.optionStrings['keepItemWritFormat']							= "Сохранить <<1>>"
WritCreater.optionStrings["npcStyleStoneReminder"]						= "Напоминание: Вы можете купить базовые камни расового стиля у любого NPC-торговца по цене 15 золотых за каждый"
WritCreater.optionStrings['voucherCount']								= "Количество # неиспользованных ремесленных расписок"
WritCreater.optionStrings['voucherCountTooltip']						= "Выводит общее количество ремесленных расписок за все запечатанные Мастерские заказы, находящиеся в инвентаре и банке игрока"
WritCreater.optionStrings['surveyCount']								= "Количество # исследований"
WritCreater.optionStrings['surveyCountTooltip']							= "Выводит разбивку по количеству исследований в инвентаре и банке игрока"
WritCreater.optionStrings["mimicStoneUse"]								= "Камень-хамелеон для Мастерских заказов"
WritCreater.optionStrings["mimicStoneUseTooltip"]						= "Определяет использование камней-хамелеонов для выполнения Мастерских заказов. Очищает текущую очередь Мастерских заказов.\nКамни-хамелеоны никогда не будут использоваться для ежедневных ремесленных заказов"
WritCreater.optionStrings['mimicStoneUseChoices']						= {"Не использовать" , "Всегда использовать", "Использовать, если нет камней стиля", "Использовать, если цена > 1 тыс.", "Использовать, если цена > 3 тыс."}
WritCreater.optionStrings['masterWritQueueCleared']						= "Очередь на создание Мастерских заказов очищена"
WritCreater.optionStrings["onomatopoeia"]							= "Звукоподражание (ономатопея) крафта"
WritCreater.optionStrings["onomatopoeiaTooltip"]						= "Активирует шуточный режим звукоподражания крафта из первоапрельского обновления аддона 2026 года"
WritCreater.optionStrings['showBoxCountdown']							= "Показать обратный отсчет коробок"
WritCreater.optionStrings['showBoxCountdownTooltip']					= "Показывает строку с обратным отсчетом открытых коробок"

findMissingTranslationsMetatable["__newindex"] = function(t,k,v)WritCreater.missingTranslations[k] = nil rawset(t,k,v)  end
WritCreater.missingTranslationMetatable = findMissingTranslationsMetatable
ZO_CreateStringId("SI_BINDING_NAME_WRIT_CRAFTER_CRAFT_ITEMS", "Создать предметы")
ZO_CreateStringId("SI_BINDING_NAME_WRIT_CRAFTER_OPEN", "Показать окно статистики")
-- text for crafting a sealed writ in the keybind area. Only for Gamepad
ZO_CreateStringId("SI_CRAFT_SEALED_WRIT", "Создать заказ")
																		-- CSA, ZO_Alert, chat message, window

function WritCreater.sortMissingTranslations()
	for i = 1, #WritCreater.missingTranslationsOrder do
		local v = WritCreater.missingTranslationsOrder[i]
		if WritCreater.missingTranslations[v[1]] then
			if type(v[2])=="table" then
				local s= ""
				for j = 1, #v[2] do
					s = s..v[2][j].." , "
				end
				d(v[1].." : "..s)
			else
				d(v[1].." : "..tostring(v[2]))
			end
		end
	end
	local sorted = {}
	for k, v in pairs(WritCreater.missingTranslations) do
		table.insert(sorted, v)
	end
	table.sort(sorted, function(a, b) return a[1] < b[1] end)
end
-- alchemyMissing : You are missing  <<list of items missing>>  to craft the cheapest combo
-- newMasterWritSmithToCraft : <<t:5>>: Crafting a CP150 <<t:1>> with the <<t:2>> trait and <<t:3>> style at <<t:4>> quality
-- /script local sorted = {} for k, v in pairs(WritCreater.missingTranslations) do table.insert(sorted, v) end table.sort(sorted, function(a, b) return a[1] > b[1] end) for i = 1, #sorted do d(sorted[i][1].." : "..tostring(sorted[i][2])) end


WritCreater.cheeseyLocalizations
=
{
	-- Note for translation: Anything on the same line after two -- should not be translated
	['menuName'] = "|cFFBF00Погоня за Пиритом|r",
	['initialDescription'] = "Почему бы сначала просто не прочитать /read брошюру?",
	['readDescription'] = "Узнав, что его главный ремесленник использовал вспомогательное дополнение для создания низкокачественных предметов, Владыка Творцов ищет нового ведущего ремесленника. Попробуй свои силы, чтобы получить эту работу!",
	['endeavorName'] = "Охота за Пиритом",-- Note for translation: Pyrite, aka Fool's Gold. Play on Fool = Crazy =  Sheogorath, Fool in April Fools, and Golden Pursuits, bc that's where this lives
	['completionShout'] = "<<1>>/<<2>> |cFFBF00Погоня за Пиритом|r Завершено!", -- e.g. 1/6 pyrite pursuit completed!
	['tasks']={
		-------------------------
		-- Note for translations:
		-- The list contains some wordplay on various daedric artefacts or other jokes. If they don't translate well (good chance) feel free to just do literal translations.
		-- Robber's Jack: Sounds like Wabbajack. Satisfied by creating a Jack from one of: the Redistributor set, the Daedric trickery set, or the Daring corsair set
		-- Amulet of Blings: Rhymes with Amulet of Kings. Satisfied by creating an electrum necklace
		-- Totally real ebony blade: Refers to the ebony blade (Mephala artefact, from crypt of hearts). Satisfied by, you guessed it, an ebony blade
		-- Staff of Magnus Gift: Gift is crossed out. Refers to the Staff of Magnus. Satisfied by a staff from the Magnus Gift set
		-- Cheesecake is a lie: Refers to 'the cake is a lie' and Sheogorath liking cheese. Satisfied by making a cheesecake
		-- Lord of the creatives, trickster, lord of the dranged, fourth corner (of the house of troubles), lord of the never there, and Dam Dog (Mad God backwards) are all names for sheogorath. 
		-- Translations can use any nickname for him, Uncle Sheo, or even just do Sheogorath if you can't find/don't know any

		-- Original: Shown prior to the completion of the first task
		-- Name: Shown in the pursuits window
		-- placehold: shown in place of name after completion (if present)
		-- completion: Shown as a popup when task is complete
		-- Description: Long form description. Should explain exactly what needs to be done. Shown as a tooltip on PC
		-- completedDescription: description after completion
		-------------------------
		{original="Вы нашли брошюру под названием 'Требуется помощь'... Может быть, вам стоит прочитать /read это",name="Прочтите брошюру, которую вы нашли",placehold="Вы нашли брошюру с объявлением о поиске сотрудников от Владыки Творцов", completion = "Похоже, Владыка Творцов набирает сотрудников?",
			description="Вы нашли брошюру под названием 'Требуется помощь'. Вы можете использовать эмоцию /read, чтобы прочитать ее", completedDescription="Вы прочитали брошюру"},

		{original="???", name = "Создайте Куртку Разбойника (Роббаджек)", completion = "Возможно, это никого не превратит в сыр, но зато преобразит ваш образ!",
			description="Пройдоха любит преобразовывать вещи. Превратитесь в разбойника, создав куртку из набора Удалой корсар", 
			completedDescription="Может быть, со временем Роббаджек станет таким же могущественным, как Ваббаджек"}, -- requires 3 traits

		{original="???", name = "Создайте Амулет из побрякушек", completion = "Это ожерелье, вероятно, смотрелось бы на вас потрясающе! Если бы только вы могли видеть его, когда носите",
			description="Безумный Лорд богат! Покажите ему, что вы можете использовать его богатства, создав Электрумное ожерелье",
		completedDescription="Несмотря на то, что оно сделано из настоящего металла, кажется, что оно исчезает, когда его надеваешь... может быть, это признак власти?"},

		{original="???", name = "Создайте Эбонитовый Клинок", completion = "Разве это не должно было украсть твою душу или что-то в этом роде? Может быть, ты что-то сделал не так?",
			description="Четвёртый Угол стремится повторить свойство Эбонитового Клинка — сводить с ума тех, кто им владеет. Покажите, что вы можете помочь, изготовив оружие с эбонитовым лезвием",
		completedDescription="Эбонитовый Клинок. Какое неприметное название для такого... На самом деле, этот клинок довольно заурядный, так что название идеально подходит"},

		{original="???", name = "Создайте посох Дара |L0:0:0:40%%:20%%:|lМагнуса|l", completion = "Сила Дара |L0:0:0:40%%:20%%:|lМагнуса|l — в ваших руках!",
		description="Главному ремесленнику Повелителя Нетленных нужно уметь создавать |L0:0:0:50%%:10%%:|lмощные|l посохи. Создайте посох из набора Дар Магнуса",
		completedDescription="К сожалению, игнорирование этого надоедливого |L0:0:0:50%%:10%%:|lдара|l в названии не сделало его более мощным"}, -- requires 4 traits

		{original="???", name = "Испечь 1 чизкейк - это просто ложь", completion = "Чииииизкейк.. Он определенно кажется достаточно реальным",
		description="Адские псы не прочь отведать чизкейка! Ведущий ремесленник должен уметь испечь самый ЛУЧШИЙ торт",completedDescription="Вы испекли чизкейк и почти уверены, что он настоящий"},
	},
	["unknownMonumentalTask"] = "Прочитайте брошюру, чтобы узнать задание",
	['claimRewardHeader'] = "Надеюсь, вам было весело заниматься |cFFBF00Охотой за Пиритом|r!",
	['claimRewardSubheading'] = "Оцените новый дизайн Writ Crafter, когда в следующий раз будете выполнять заказы!",

	-- Note for translation: Crafting Helper Add-on To Generate Processed Trash = CHAT GPT. For translations, could also use/reference AI, Automation, etc.
	["bookText"] = 
[[
Узнав, что его главный ремесленник использовал вспомогательное дополнение для создания низкокачественных предметов, Владыка Творцов ищет нового ведущего ремесленника. Попробуй свои силы, чтобы получить эту работу! (У него по‑прежнему есть главный ремесленник — только вот голова без тела мало что может)

Для подачи заявки, пожалуйста, изготовьте следующее:
1 Куртака Разбойника
1 Амулет из побрякушек
1 Абсолютно настоящий Эбонитовый Клинок
1 Посох Дара |L0:0:0:40%%:20%%:|lМагнуса|
1 Чизкейк — это ложь
]],
	["bookTitle"] = "Требуется помощь",
	["superAmazingCraftSounds"] = { 
		-- Translation notes: These are displayed randomly when crafting around the screen
		{"БРЯНЦ", "БАЦ", "ЦОК", "КЛАЦ", "ДЗЫНЬ"}, -- Blacksmithing sounds
		{"ЩЕЛК", "ШИРК"}, -- Clothing sounds
		{"АЛАКАЗАМ", "АБРАКАДАБРА", "ФОКУС-ПОКУС", "ВУАЛЯ"}, -- Enchanting sounds
		{"ШЛЕП", "БУЛЬК", "ПЛЮХ", "ХЛЮП"}, -- Alchemy sounds
		{"ПШШШ", "ХЛЮП", "БУЛЬК"}, -- Cooking sounds
		{"ЖУ-ЖУ-ЖУ", "БУМ", "ТРЫК", "БАМ"}, -- Woodworking sounds
		{"ДИНЬ", "ПЛИНК", "ПИНГ"}, -- Jewelry sounds
	},
	["extraSlash"] = nil, -- if your language has a translation for /read, put it here. 
}

-------------------------------
-- END TRANSLATIONS HERE, DO NOT TRANSLATE FURTHER
-- Deleted ideas:
-- Stuff of Worms
-- Ghastly Eye Bowl - Crafted using worms. So 'Stuff' of worms
-- Maybe replace craft result with 'new name'?
-- Alchemical mix of violet coprinus and Dragon's Bile - inert. Might need to rethink
-- Vile and dung/Bile an' Dung - imp stoll + Vile Coagulant or Dragon's Bile. But both are inert as well


--/esoui/art/icons/pet_041.dds
--/esoui/art/icons/pet_042.dds
--/esoui/art/icons/pet_sheepbrown.dds

-----------------------------------------------------------------------------------
-- Addon Name: Dolgubon's Lazy Writ Crafter
-- Creator: Dolgubon (Joseph Heinzle)
-- Addon Ideal: Simplifies Crafting Writs as much as possible
-- Addon Creation Date: March 14, 2016
--
-- File Name: Languages/en.lua
-- File Description: Russian Localization
-- File Translator: @Torvard

-----------------------------------------------------------------------------------

WritCreater = WritCreater or {}

function WritCreater.langWritNames() -- Vital to translate
	-- Exact!!!  I know for german alchemy writ is Alchemistenschrieb - so ["G"] = schrieb, and ["A"]=Alchemisten
	local names = {
	["G"] = "Заказ",
	[CRAFTING_TYPE_ENCHANTING] 	= "Зачар.",
	[CRAFTING_TYPE_BLACKSMITHING] 	= "Кузн.",
	[CRAFTING_TYPE_CLOTHIER] 	= "Портн.",
	[CRAFTING_TYPE_PROVISIONING] 	= "Снаб.",
	[CRAFTING_TYPE_WOODWORKING] 	= "Столяр.",
	[CRAFTING_TYPE_ALCHEMY] 	= "Алхим.",
	[CRAFTING_TYPE_JEWELRYCRAFTING] = "Ювелир.",
	}
	return names
end

function WritCreater.writCompleteStrings() -- Vital for translation
	local strings = {
	["place"] = "Положить предметы в ящик",
	["sign"] = "Подписать декларацию",
	["masterPlace"] = "Я закончил",
	["masterSign"] = "<Закончить работу>",
	["masterStart"] = "<Принять заказ>",
	["Rolis Hlaalu"] = "Ролис Хлаалу", -- This is the same in most languages but ofc chinese and japanese
	["Deliver"] = "Доставить",
        ["Acquire"] = "Добыть",
	}
	return strings
end

function WritCreater.langStationNames()
	return
	{["Кузница"] = 1, ["Портняжный станок"] = 2, 
	 ["Стол зачарователя"] = 3,["Алхимический стол"] = 4, ["Огонь для приготовления пищи"] = 5, ["Столярный верстак"] = 6, ["Стол ювелира"] = 7, }
end

--------------------------------------------------------------------------------------------------------------------
-- Translators can skip these, if you want.
-- These are April 1 strings, so don't need to be translated, unless you really want to.


-- What is this??! This is just a fun 'easter egg' that is never activated on easter.
-- Replaces mat names with a random DivineMats on Halloween, New Year's, and April Fools day. You don't need this many! Just one is enough :D
-- Translate it or don't, completely up to you. If you don't translate it, just remove it
local DivineMats =
{
	{"Ржавые гвозди", "Призрачные одеяния", "","","", "Гнилые бревна","Проклятое золото", "Печеночный паштет", "Раскрошившиеся надгробия", "Жабьи глаза", "Когти оборотня", "Кишки зомби", "Мозги ящерицы"},
	{"Зуммеры","Куклы из носков", "Шутовские шляпы","Носы выдры", "Красная селедка", "Деревянные змеи", "Золотые зубы", "Грязевики"},
	{"Уголь", "Чулки", "","","","Вечнозеленые ветви", "Золотые кольца", "Время в бутылках", "Оленьи колокольчики", "Эльфийские шляпы", "Сосновые иголки", "Чашки снега"},
}

-- confetti?
-- random sounds?
-- 

local function shouldDivinityprotocolbeactivatednowornotitshouldbeallthetimebutwhateveritlljustbeforabit()
	if not DivineMats then
		return false
	end
	if GetDate()%10000 == 1031 then return 1 end
	if GetDate()%10000 == 401 then return 2 end
	if GetDate()%10000 == 1231 then return 3 end
	if GetDisplayName() == "@Dolgubon" or GetDisplayName() == "@Gitaelia" or GetDisplayName() == "@mithra62" or GetDisplayName() == "@PacoHasPants" then
		return 2
	end
	return false
end

WritCreater.shouldDivinityprotocolbeactivatednowornotitshouldbeallthetimebutwhateveritlljustbeforabit = shouldDivinityprotocolbeactivatednowornotitshouldbeallthetimebutwhateveritlljustbeforabit

local function wellWeShouldUseADivineMatButWeHaveNoClueWhichOneItIsSoWeNeedToAskTheGodsWhichDivineMatShouldBeUsed() local a= math.random(1, #DivineMats ) return DivineMats[a] end
local l = shouldDivinityprotocolbeactivatednowornotitshouldbeallthetimebutwhateveritlljustbeforabit()

if l then
	DivineMats = DivineMats[l]
	local DivineMat = wellWeShouldUseADivineMatButWeHaveNoClueWhichOneItIsSoWeNeedToAskTheGodsWhichDivineMatShouldBeUsed()

	WritCreater.strings.smithingReqM = function (amount, _,more)
		local craft = GetCraftingInteractionType()
		DivineMat = DivineMats[craft]
		return zo_strformat( "Для создания потребуется <<1>> <<4>> (|cf60000Нужно ещё <<3>>|r)" ,amount, type, more, DivineMat) end
	WritCreater.strings.smithingReqM2 = function (amount, _,more)
		local craft = GetCraftingInteractionType()
		DivineMat = DivineMats[craft]
		return zo_strformat( "А также <<1>> <<4>> (|cf60000Нужно ещё <<3>>|r)" ,amount, type, more, DivineMat) end
	WritCreater.strings.smithingReq = function (amount, _,more)
		local craft = GetCraftingInteractionType()
		DivineMat = DivineMats[craft]
		return zo_strformat( "Для создания потребуется <<1>> <<4>> (|c2dff00<<3>> доступно|r)" ,amount, type, more, DivineMat) end
	WritCreater.strings.smithingReq2 = function (amount, _,more)
		local craft = GetCraftingInteractionType()
		DivineMat = DivineMats[craft] 
		return zo_strformat( "А также <<1>> <<4>> (|c2dff00<<3>> доступно|r)" ,amount, type, more, DivineMat) end
end


-- [[ /script local writcreater = {} local c = {a = 1} local g = {__index = c} setmetatable(writ, g) d(a.a) local e = {__index = {Z = 2}} setmetatable(c, e) d(a.Z)


-----------------------------------------------
-- Translators should skip all of the following. Will probably not be used again
local h = {__index = {}}
local t = {}
local g = {["__index"] = t}
setmetatable(t, h)
setmetatable(WritCreater, g) --]]

local function enableAlternateUniverse(override)

	if shouldDivinityprotocolbeactivatednowornotitshouldbeallthetimebutwhateveritlljustbeforabit() == 2 or override then
	--if true then
		local stations =
			{"Кузница", "Портняжный станок", "Стол зачарователя", 
			"Алхимический стол", "Огонь для приготовления пищи", "Столярный верстак", "Стол ювелира", "Станция создания нарядов", "Станция трансмутации", "Дорожное святилище"}
			local stationNames =  -- in the comments are other names that were also considered, though not all were considered seriously
			{"Тяжелый металл", -- Popcorn Machine , Skyforge, Heavy Metal Station, Metal Clockwork Solid, Wightsmithing Station., Coyote Stopper
			"Чулочная фабрика", -- Sock Distribution Center, Soul-Shriven Sock Station, Grandma's Sock Knitting Station, Knits and Pieces, Sock Knitting Station
			"Дело в шляпе", -- Mahjong Station, Magic Store, Card Finder, Five Aces, Top Hat Store
			"Старый скуума-бар", -- Chemical Laboratory , Drugstore, White's Garage, Cocktail Bar, Med-Tek Pharmaceutical Company, Med-Tek Laboratories, Skooma Central, Skooma Backdoor Dealers, Sheogorath's Pharmacy
			"Каджитская курочка во фритюре", -- Khajit Fried Chicken, soup Kitchen, Some kind of bar, misspelling?, Roast Bosmer
			"Станция сборки IKEA", -- Chainsaw Massace, Saw Station, Shield Corp, IKEA Assembly Station, Wood Splinter Removal Station
			"Золото дураков",--"Diamond Scam Store", -- Lucy in the Sky, Wedding Planning Hub, Shiny Maker, Oooh Shiny, Shiny Bling Maker, Cubit Zirconia, Rhinestone Palace
			-- April Fool's Gold
			"Каджитские торговые меха", -- Jester Dressing Room Loincloth Shop, Khajit Walk, Khajit Fashion Show, Mummy Maker, Thalmor Spy Agency, Tamriel Catwalk, 
			--	Tamriel Khajitwalk, second hand warehouse,. Dye for Me, Catfur Jackets, Outfit station "Khajiit Furriers", Khajit Fur Trading Outpost
			"Алтарь заклания козла",-- Heisenberg's Station Correction Facility, Time Machine, Probability Redistributor, Slot Machine Rigger, RNG Countermeasure, Lootcifer Shrine, Whack-a-mole
			-- Anti Salt Machine, Department of Corrections, Quantum State Rigger , Unnerf Station
			"ТАРДИС" } -- Transporter, Molecular Discombobulator, Beamer, Warp Tunnel, Portal, Stargate, Cannon!, Warp Gate
			
			local crafts = {"Кузнечное дело", "Портняжное дело", "Зачарование", "Алхимия", "Снабжение", "Столярное дело", "Ювелирное дело"}
			local craftNames = {
				"Тяжёлый металл",
				"Кройка и шитьё",
				"Дело в шляпе",
				"Скуумодел",
				"МакДаэдра",--"Chicken Frying",
				"IKEA",
				"Золото дураков",
			}
			local quest = {"кузнец", "портно", "зачаров" ,"алхимик", "снабжен", "столяр", "ювелир", "снабжен"}
			local questNames = 	
			{
				"Жестянщик",
				"Вязальщица носков",
				"Ловкач в цилиндре",
				"Пивовар Скуума",
				"Куриная фритюрница",
				"Сборка IKEA",
				"Золото дураков",
                                "Доставка МакДаэдра",
			}
			local items = {"кузне", "портно", "зачаров", "алхими", "еда и напитки",  "столяр", "ювелир"}
			local itemNames = {
				"Жестянка",
				"Кукла из носка",
				"Цилиндр",
				"Скуума",
				"Наггетсы МакДаэдра",
				"IKEA",
				"Золото дураков",
			}
			local coffers = {"кузнеца", "портного", "зачарователя" ,"алхимика", "снабженца", "столяра", "ювелира",}
			local cofferNames = {
				"Жестянщик",
				"Вязальщица носков",
				"Ловкач в цилиндре",
				"Пивовар Скуума",
				"Куриная фритюрница",
				"Сборка IKEA",
				"Золото дураков",
			}
			local ones = {"Ювелир"}
			local oneNames = {"Золото дураков"}


		local t = {["__index"] = {}}
		function h.__index.alternateUniverse()
			return stations, stationNames
		end
		function h.__index.alternateUniverseCrafts()
			return crafts, craftNames
		end
		function h.__index.alternateUniverseQuests()
			return quest, questNames
		end
		function h.__index.alternateUniverseItems()
			return items, itemNames
		end
		function h.__index.alternateUniverseCoffers()
			return coffers, cofferNames
		end
		function h.__index.alternateUniverseOnes()
			return ones, oneNames
		end

 
		h.__metatable = "No looky!"
		local a = WritCreater.langStationNames()
		a[1] = 1
		for i = 1, 7 do
			a[stationNames[i]] = i
		end
		WritCreater.langStationNames = function() 
			return a
		end
		local b =WritCreater.langWritNames()
		for i = 1, 7 do
			b[i] = questNames[i]
		end
		-- WritCreater.langWritNames = function() return b end

	end
end

-- For Transmutation: "Well Fitted Forever"
-- So far, I like blacksmithing, clothing, woodworking, and wayshrine, enchanting
-- that leaves , alchemy, cooking, jewelry, outfits, and transmutation

local lastYearStations = 
{"Кузница", "Портняжный станок", "Столярный верстак", "Огонь для приготовления пищи", 
"Стол зачарователя", "Алхимический стол", "Станция создания нарядов", "Станция трансмутации", "Дорожное святилище"}
local stationNames =  -- in the comments are other names that were also considered, though not all were considered seriously
{"Тяжёлый металл 112.3 FM", -- Popcorn Machine , Skyforge, Heavy Metal Station
 "Кукольный театр", -- Sock Distribution Center, Soul-Shriven Sock Station, Grandma's Sock Knitting Station, Knits and Pieces
 "Стружки и опилки", -- Chainsaw Massace, Saw Station, Shield Corp, IKEA Assembly Station, Wood Splinter Removal Station
 "МакШеогорат", 
 "Тетрис", -- Mahjong Station
 "Центр контроля заражений", -- Chemical Laboratory , Drugstore, White's Garage, Cocktail Bar, Med-Tek Pharmaceutical Company, Med-Tek Laboratories
 "Уголок талморского шпиона", -- Jester Dressing Room Loincloth Shop, Khajit Walk, Khajit Fashion Show, Mummy Maker, Thalmor Spy Agency, Morag Tong Information Hub, Tamriel Spy HQ, 
 "Отдел коррекции",-- Heisenberg's Station Correction Facility, Time Machine, Probability Redistributor, Slot Machine Rigger, RNG Countermeasure, Lootcifer Shrine, Whack-a-mole
 -- Anti Salt Machine, Department of Corrections
 "Варп-врата" } -- Transporter, Molecular Discombobulator, Beamer, Warp Tunnel, Portal, Stargate, Cannon!, Warp Gate

-- enableAlternateUniverse(GetDisplayName()=="@Dolgubon")
enableAlternateUniverse()

local function alternateListener(eventCode,  channelType, fromName, text, isCustomerService, fromDisplayName)
	if not WritCreater.alternateUniverse and fromDisplayName == "@Dolgubon"and (text == "Пусть Острова прольют кровь в Нирн!" ) then	
		enableAlternateUniverse(true)
		WritCreater.WipeThatFrownOffYourFace(true)	
	end	
	-- if GetDisplayName() == "@Dolgubon" then
	-- 	enableAlternateUniverse(true)	
	-- 	WritCreater.WipeThatFrownOffYourFace(true)	
	-- end
end	

 EVENT_MANAGER:RegisterForEvent(WritCreater.name,EVENT_CHAT_MESSAGE_CHANNEL, alternateListener)

WritCreater.optionStrings["alternate universe"]			= "Отключить 1-апрельские шутки"
WritCreater.optionStrings["alternate universe tooltip"] 	= "Отключает переименование ремесленных станций, ремесла и прочих интерактивных предметов"

WritCreater.lang = "ru"
WritCreater.langIsMasterWritSupported = true

WritCreater.cheeseyLocalizations["alreadyUnlocked"] = "Разблокировать скин Writ Crafter"
WritCreater.cheeseyLocalizations["alreadyUnlockedTooltip"] = "Вы уже разблокировали скин 1 апреля 2023 года. Повторите это действие просто ради удовольствия!"
WritCreater.cheeseyLocalizations["settingsChooseSkin"] = "Вы можете изменить скин в меню настроек"