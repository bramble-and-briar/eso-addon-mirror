local M=MountSwap
M.translations={en={}}

function M:LanguageCode()
    if self.activeLanguage then return self.activeLanguage end
    local chosen=self.saved and self.saved.language or 'auto'
    local code = chosen
    if chosen == 'auto' then code = GetCVar('Language.2') end
    if type(code)~='string' then return 'en' end
    code=string.lower(code)
    if code=='jp' then code='ja' end
    return self.translations[code] and code or 'en'
end

function M.L(text)
    if type(text)~='string' then return text end
    local dictionary=M.translations[M:LanguageCode()] or M.translations.en
    local exact=dictionary[text]
    if exact then return exact end
    -- Templates translate addon-owned sentences while preserving captured mount
    -- names, commands, numeric IDs and other ESO/user-supplied values verbatim.
    for _,template in ipairs(M.translationPatterns or {}) do
        local captures={text:match(template.pattern)}
        if #captures>0 then
            local translated=dictionary[template.key] or template.key
            return (translated:gsub('{(%d+)}',function(index) return captures[tonumber(index)] or '' end))
        end
    end
    return text
end

function M:InitializeLanguage()
    self.activeLanguage=nil
    self.activeLanguage=self:LanguageCode()
    local patterns={}
    for _,key in ipairs(self.translationKeys or {}) do
        if key:find('{1}',1,true) then
            local pattern=key:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])','%%%1'):gsub('{%d+}','(.-)')
            patterns[#patterns+1]={key=key,pattern='^'..pattern..'$'}
        end
    end
    table.sort(patterns,function(a,b) if #a.key==#b.key then return a.key<b.key end; return #a.key>#b.key end)
    self.translationPatterns=patterns
    if SafeAddString then
        for action,text in pairs(self.bindingTexts or {}) do
            local id=_G['SI_BINDING_NAME_'..action]
            if id then SafeAddString(id,M.L(text),2) end
        end
    end
end

function M:LanguageChoices()
    return {M.L('Automatic — follow ESO'),'English','Chinese (Simplified) — 简体中文','French — Français',
        'German — Deutsch','Japanese — 日本語','Russian — Русский','Spanish — Español'},
        {'auto','en','zh','fr','de','ja','ru','es'}
end

function M:LocalizeSettings(options)
    for _,data in ipairs(options) do
        for _,field in ipairs({'name','text','tooltip','useName'}) do
            local original=data[field]
            if type(original)=='string' then data[field]=M.L(original)
            elseif type(original)=='function' then data[field]=function(...) return M.L(original(...)) end end
        end
        if data.type=='dropdown' and data.choices then
            if not data.choicesValues then
                data.choicesValues={}
                for index,choice in ipairs(data.choices) do data.choicesValues[index]=choice end
            end
            local choices={}
            for index,choice in ipairs(data.choices) do choices[index]=M.L(choice) end
            data.choices=choices
        end
    end
end

function M:FitLocalizedButton(control)
    local label=control.GetLabelControl and control:GetLabelControl() or control
    if not label or not label.GetTextWidth or not control.GetWidth then return end
    control:SetFont('ZoFontGame')
    local width=control:GetWidth()-8
    local size=18
    local function measure()
        return label.GetStringWidth and label:GetStringWidth(label:GetText()) or label:GetTextWidth()
    end
    while width>0 and measure()>width and size>14 do
        size=size-1
        control:SetFont('$(MEDIUM_FONT)|'..size..'|soft-shadow-thin')
    end
end
