------------------------------------------------------------------------------------------------------------------------ Templated from ag_cpslots.lua -Kyzeragon
--
-- Global AlphaGear variable
------------------------------------------------------------------------------------------------------------------------
AG = AG or {}
AG.plugins = AG.plugins or {}

------------------------------------------------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------------------------------------------------
--Integration/Plugin coding for Dynamic CP addon.
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Global variables
------------------------------------------------------------------------------------------------------------------------
AG.plugins.DynamicCP = AG.plugins.DynamicCP or {}


------------------------------------------------------------------------------------------------------------------------
-- const
------------------------------------------------------------------------------------------------------------------------
local DCP_API_UNIQUE_NAME = "AlphaGearDynamicCPIntegration"


------------------------------------------------------------------------------------------------------------------------
-- Local variables
------------------------------------------------------------------------------------------------------------------------
local AGplugDCP = AG.plugins.DynamicCP


------------------------------------------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------------------------------------------
function AGplugDCP.isAddonReady()
    return (DynamicCP ~= nil and DynamicCP.GetSlottableSets ~= nil and DynamicCP.CommitSlottableSetsSupportsSuppression) or false
end

function AGplugDCP.useAddon()
    return AGplugDCP.isAddonReady() and AG.account.Integrations.Champion.UseDynamicCP or false
end

function AGplugDCP.LoadSlottableSets(sets)
    if not AGplugDCP.useAddon() then
        return
    end

    for tree, slotSetId in pairs(sets) do
        DynamicCP.QueueSlottableSet(DCP_API_UNIQUE_NAME, tree, slotSetId)
    end
    DynamicCP.CommitSlottableSets(DCP_API_UNIQUE_NAME, not AG.account.Integrations.Champion.DCPPrintNames, not AG.account.Integrations.Champion.DCPPrintSlottables)
end

function AGplugDCP.GetDCPSlottableSet(tree)
    return DynamicCP.GetSlottableSets(tree)
end

function AGplugDCP.GetDCPSlottableSetStars(tree, slotSetId)
    return DynamicCP.GetSlottableSets(tree)[slotSetId]
end


-- initialization
function AGplugDCP.LoadDynamicCP()
end
