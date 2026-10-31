-- Archive Motifs module registration.
-- All Motifs-specific implementation remains in the proven screen code; this
-- definition is the contract future Archive modules will use to join the same UI.
local TC = TamrielCollections
TC:RegisterArchiveModule('motifs', {
    displayName = 'Motifs',
    addonName = 'Tamriel Collections - Archive Motifs',
    version = 1002,
    supportsSearch = true,
    onCategoryFocus = function(screen, data)
        screen:ShowMotifCategory(data)
    end,
    open = function(screen)
        screen:OpenMotifs()
    end,
    activateSearch = function(screen)
        screen:ActivateMotifSearch()
    end,
})
