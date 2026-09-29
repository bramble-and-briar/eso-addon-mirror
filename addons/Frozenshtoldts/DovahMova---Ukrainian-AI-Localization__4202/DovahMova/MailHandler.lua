-- =================================================================================================
-- Автозбір вкладень з листів найманців при відкритті поштової скриньки.
-- =================================================================================================

local DovahMova = DovahMova

local MailHandler = {}
DovahMova.MailHandler = MailHandler

local DELAY_AFTER_OPEN_MS = 1000
local DELAY_BETWEEN_MAILS_MS = 300

local HIRELING_SUBJECTS = {
	["Матеріали від коваля"] = true,
	["Матеріали від кравця"] = true,
	["Матеріали від тесляра"] = true,
	["Матеріали від зачарувальника"] = true,
	["Інгредієнти від постачальника"] = true,
	["Матеріали від ювеліра"] = true,
	["Blacksmithing Hireling"] = true,
	["Clothier Hireling"] = true,
	["Woodworking Hireling"] = true,
	["Enchanting Hireling"] = true,
	["Provisioning Hireling"] = true,
	["Jewelry Crafting Hireling"] = true,
}

function MailHandler.IsHirelingMail(subject)
	if not subject then
		return false
	end
	return HIRELING_SUBJECTS[subject]
		or zo_plainstrfind(subject, "Матеріали від")
		or zo_plainstrfind(subject, "Інгредієнти від")
		or zo_plainstrfind(subject, "Hireling")
		or false
end

local function FindHirelingMails()
	local mailIds = {}
	local mailId = GetNextMailId(nil)
	while mailId do
		local _, _, subject, _, _, fromSystem, fromCustomerService, _, numAttachments, attachedMoney = GetMailItemInfo(mailId)
		if fromSystem and not fromCustomerService and attachedMoney == 0 and numAttachments > 0 and MailHandler.IsHirelingMail(subject) then
			mailIds[#mailIds + 1] = mailId
		end
		mailId = GetNextMailId(mailId)
	end
	return mailIds
end

function MailHandler.CollectAttachments()
	if not DovahMova.settings.AutoCollectHirelingMail then
		return
	end
	local mailIds = FindHirelingMails()
	if #mailIds == 0 then
		return
	end

	DovahMova.Print("знайдено %d листів від найманців, забираю матеріали...", #mailIds)
	local deleteAfterTaking = DovahMova.settings.AutoDeleteHirelingMail
	local index = 0
	local function TakeNext()
		index = index + 1
		local mailId = mailIds[index]
		if not mailId then
			DovahMova.Print("автозбір листів завершено.")
			return
		end
		TakeMailAttachments(mailId, deleteAfterTaking)
		zo_callLater(TakeNext, DELAY_BETWEEN_MAILS_MS)
	end
	TakeNext()
end

function MailHandler.Initialize()
	EVENT_MANAGER:RegisterForEvent(DovahMova.name .. "_MailHandler", EVENT_MAIL_OPEN_MAILBOX, function()
		zo_callLater(MailHandler.CollectAttachments, DELAY_AFTER_OPEN_MS)
	end)
end
