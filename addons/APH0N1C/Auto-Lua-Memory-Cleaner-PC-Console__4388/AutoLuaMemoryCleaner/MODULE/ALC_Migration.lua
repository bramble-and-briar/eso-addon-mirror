--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC

function ALC.migrate_data()
	if ALC.settings then
		ALC.settings.pmOverridden = nil
	end
end

ALC._modules.migration = true