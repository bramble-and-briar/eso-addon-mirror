-- Source-anchored to ZO_AddOnManager:BuildMasterList, before SetupTypeId.
-- Only our own metadata changes; original callbacks and other addons are untouched.
local description = "ﻲﻧﺎﻄﺤﻘﻟﺍ ﺰﻳﺰﻌﻟﺍﺪﺒﻋ ﺔﻄﺳﺍﻮﺑ ﻲﻤﺳﺭ ﺮﻴﻐﻟﺍ ﺔﺒﻌﻟ ﺐﻳﺮﻌﺗ\n:ﺕﺎﻤﻴﻠﻌﺘﻟﺍ\n.ﺔﻴﺑﺮﻌﻟﺍ ﻰﻟﺇ ﺔﻐﻠﻟﺍ ﺮﻴﻴﻐﺘﻟ : /ar\n.ﺔﻳﺰﻴﻠﺠﻧﺍ ﻰﻟﺇ ﺔﻐﻠﻟﺍ ﺮﻴﻴﻐﺘﻟ : /en"
if ZO_AddOnManager and type(ZO_AddOnManager.BuildMasterList) == "function" and SecurePostHook then
    SecurePostHook(ZO_AddOnManager, "BuildMasterList", function(self)
        for _, entries in pairs(self.addonTypes or {}) do
            for _, entry in ipairs(entries) do
                if entry.addOnFileName == "EsoAR" then
                    entry.addOnDescription = description
                end
            end
        end
    end)
end
