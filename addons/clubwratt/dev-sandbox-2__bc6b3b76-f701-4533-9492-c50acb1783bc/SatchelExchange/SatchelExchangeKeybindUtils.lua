-- SatchelExchangeKeybindUtils.lua: Pure builder for the store keybind descriptor.

local SatchelExchangeKeybindUtils = {}

---Build the keybind strip descriptor entry for the buy screen toggle.
---Y / Triangle (UI_SHORTCUT_TERTIARY) is unused on the gamepad buy screen;
---X / Square (UI_SHORTCUT_SECONDARY) is taken by Repair All at repair-capable vendors.
---@param callbacks {name: (fun(): string), callback: fun(), visible: (fun(): boolean)}
---@return table keybindDescriptor
function SatchelExchangeKeybindUtils.BuildToggleDescriptor(callbacks)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        keybind = "UI_SHORTCUT_TERTIARY",
        name = callbacks.name,
        callback = callbacks.callback,
        visible = callbacks.visible,
        enabled = callbacks.enabled,
    }
end

SatchelExchange.KeybindUtils = SatchelExchangeKeybindUtils
