-- Embedded add-on options, registered once inside the My UI menu tree.
MyUI_EmbeddedSections = MyUI_EmbeddedSections or {}
function MyUI_RegisterExternalSection(order, id, name, options)
    if not order or not id or type(options) ~= "table" then return end
    MyUI_EmbeddedSections[id] = {index = "Embedded_" .. id, name = name,
                                 options = options, order = order, noLegacyPanel = true}
end
