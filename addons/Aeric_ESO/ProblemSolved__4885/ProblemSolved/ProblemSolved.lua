ProblemSolved = {}

ZO_CreateStringId("SI_BINDING_NAME_PROBLEMSOLVED_DESTROY", "Destroy Problem Item")

function ProblemSolved_OnKeybindPressed()
    local bagId = BAG_BACKPACK
    local totalRemoved = 0
    local itemLink = nil

    for slotIndex = GetBagSize(bagId) - 1, 0, -1 do
        if HasItemInSlot(bagId, slotIndex)
            and GetItemId(bagId, slotIndex) == 224302 then

            local stack = GetSlotStackSize(bagId, slotIndex)
            itemLink = itemLink or GetItemLink(bagId, slotIndex)

            if IsItemPlayerLocked(bagId, slotIndex) then
                SetItemIsPlayerLocked(bagId, slotIndex, false)
            end

            if CanItemBeMarkedAsJunk(bagId, slotIndex) then
                SetItemIsJunk(bagId, slotIndex, true)
            end

            DestroyItem(bagId, slotIndex)

            totalRemoved = totalRemoved + stack
        end
    end

    if totalRemoved > 0 then
        d(string.format("Problem was solved. %d %s were removed. Enjoy the game!", totalRemoved, itemLink))
    end
end

