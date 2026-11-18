if not SemisPlaygroundCheckAccess() then return end

---@param argument string
SLASH_COMMANDS['/bslang'] = function(argument)
    local code = argument:lower():match('^%s*(%l%l)%s*$')
    if not code then
        d(GetCVar('language.2'))
        return
    end
    local current = GetCVar('language.2')
    if current == code then return end
    -- The three settings the console translation addons write. The language
    -- goes last because changing it reloads the UI.
    SetCVar('IgnorePatcherLanguageSetting', '1')
    SetCVar('LastPlatformLanguage', code)
    -- A switch replaces the loaded game text only when <code>.lang exists. An
    -- overlay-only language has none, so the previous language's text would
    -- stay under the overlay. Loading English first gives it the right base.
    -- If the reload cuts in after this step, running the command again
    -- finishes the switch.
    if current ~= 'en' and code ~= 'en' then
        SetCVar('language.2', 'en')
    end
    SetCVar('language.2', code)
end
