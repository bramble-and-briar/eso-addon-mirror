local Addon = LarvalTearMod
local RecipeStore = Addon.Modules.RecipeStore
local Util = Addon.Common.Util

function RecipeStore.NormalizeCharacterKey(characterKey)
    if characterKey ~= nil then
        return tostring(characterKey)
    end

    if type(GetCurrentCharacterId) ~= "function" then
        return nil
    end

    local ok, characterId = pcall(GetCurrentCharacterId)
    if ok and characterId ~= nil then
        return tostring(characterId)
    end

    return nil
end

function RecipeStore.NormalizeRecipeId(recipeId)
    if type(recipeId) ~= "string" or recipeId == "" then
        return nil
    end
    return recipeId
end

function RecipeStore.NormalizeCraftCount(count)
    return math.max(math.floor(tonumber(count) or 1), 1)
end

function RecipeStore.BuildDefaultRecipeName(recipeId)
    local suffix = type(recipeId) == "string" and recipeId:match("recipe_(%d+)$") or nil
    return "Recipe " .. (suffix or "0001")
end

function RecipeStore.EnsureSavedVarsShape(self, readOnly)
    if type(self.savedVars) ~= "table" then
        return nil
    end

    if type(self.savedVars[self.recipeStoreKey]) ~= "table" then
        if readOnly then
            return nil
        end
        self.savedVars[self.recipeStoreKey] = {}
    end

    return self.savedVars
end

function RecipeStore.BuildDefaultCharacterBucket(self, characterKey)
    return {
        recipes = {},
        recipeOrder = {},
        nextIndex = 1,
        activeRecipeId = nil,
        autoApplyEnabled = false,
        ownerCharacterId = characterKey,
    }
end

function RecipeStore.NormalizeCharacterBucket(self, bucket, characterKey)
    if type(bucket) ~= "table" then
        return nil
    end

    if type(bucket.recipes) ~= "table" then
        bucket.recipes = {}
    end
    -- The domain hook runs on both the readonly copy and the writable bucket.
    if type(self.NormalizeRecipe) == "function" then
        for recipeId, recipe in pairs(bucket.recipes) do
            if type(recipeId) == "string" and type(recipe) == "table" then
                recipe.id = recipe.id or recipeId
                self:NormalizeRecipe(recipe)
            end
        end
    end

    if type(bucket.recipeOrder) ~= "table" then
        bucket.recipeOrder = {}
        for recipeId, recipe in pairs(bucket.recipes) do
            if type(recipeId) == "string" and type(recipe) == "table" then
                bucket.recipeOrder[#bucket.recipeOrder + 1] = recipeId
            end
        end
        table.sort(bucket.recipeOrder)
    end

    bucket.nextIndex = math.max(tonumber(bucket.nextIndex) or 1, 1)
    bucket.autoApplyEnabled = bucket.autoApplyEnabled == true
    bucket.activeRecipeId = RecipeStore.NormalizeRecipeId(bucket.activeRecipeId)
    bucket.ownerCharacterId = bucket.ownerCharacterId or characterKey

    if bucket.activeRecipeId ~= nil and type(bucket.recipes[bucket.activeRecipeId]) ~= "table" then
        bucket.activeRecipeId = nil
    end

    return bucket
end

function RecipeStore.GetCharacterBucketReadonly(self)
    local savedVars = self:EnsureSavedVarsShape(true)
    if type(savedVars) ~= "table" or type(savedVars[self.recipeStoreKey]) ~= "table" then
        return nil
    end

    local characterKey = RecipeStore.NormalizeCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end

    local bucket = savedVars[self.recipeStoreKey][characterKey]
    if type(bucket) ~= "table" then
        return nil
    end

    bucket = Util:DeepCopy(bucket)
    return self:NormalizeCharacterBucket(bucket, characterKey)
end

function RecipeStore.EnsureCharacterBucketForWrite(self)
    local savedVars = self:EnsureSavedVarsShape(false)
    if type(savedVars) ~= "table" then
        return nil
    end

    local characterKey = RecipeStore.NormalizeCharacterKey()
    if type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end

    local bucket = savedVars[self.recipeStoreKey][characterKey]
    if type(bucket) ~= "table" then
        bucket = self:BuildDefaultCharacterBucket(characterKey)
        savedVars[self.recipeStoreKey][characterKey] = bucket
    end

    return self:NormalizeCharacterBucket(bucket, characterKey)
end

function RecipeStore.GenerateRecipeId(self, bucket)
    bucket = type(bucket) == "table" and bucket or self:EnsureCharacterBucketForWrite()
    if type(bucket) ~= "table" then
        return nil
    end

    if type(bucket.recipes) ~= "table" then
        bucket.recipes = {}
    end

    while true do
        local nextIndex = math.max(tonumber(bucket.nextIndex) or 1, 1)
        local recipeId = string.format("recipe_%04d", nextIndex)
        bucket.nextIndex = nextIndex + 1
        if type(bucket.recipes[recipeId]) ~= "table" then
            return recipeId
        end
    end
end

function RecipeStore.GetRecipe(self, recipeId)
    recipeId = RecipeStore.NormalizeRecipeId(recipeId)
    if recipeId == nil then
        return nil, "recipe_not_found"
    end

    local bucket = self:GetCharacterBucketReadonly()
    local recipe = type(bucket) == "table"
        and type(bucket.recipes) == "table"
        and bucket.recipes[recipeId]
        or nil
    if type(recipe) ~= "table" then
        return nil, "recipe_not_found"
    end

    return Util:DeepCopy(recipe)
end

function RecipeStore.GetAutoApplyEnabled(self)
    local bucket = self:GetCharacterBucketReadonly()
    return type(bucket) == "table" and bucket.autoApplyEnabled == true or false
end

function RecipeStore.SetAutoApplyEnabled(self, enabled)
    local bucket = self:EnsureCharacterBucketForWrite()
    if type(bucket) ~= "table" then
        return false
    end

    bucket.autoApplyEnabled = enabled == true
    return true
end

function RecipeStore.GetActiveRecipeId(self)
    local bucket = self:GetCharacterBucketReadonly()
    return type(bucket) == "table" and bucket.activeRecipeId or nil
end

local function GetExistingRecipeForWrite(self, recipeId)
    recipeId = RecipeStore.NormalizeRecipeId(recipeId)
    local existingBucket = self:GetCharacterBucketReadonly()
    if type(existingBucket) ~= "table"
        or recipeId == nil
        or type(existingBucket.recipes) ~= "table"
        or type(existingBucket.recipes[recipeId]) ~= "table" then
        return nil, nil
    end

    local bucket = self:EnsureCharacterBucketForWrite()
    if type(bucket) ~= "table" or type(bucket.recipes[recipeId]) ~= "table" then
        return nil, nil
    end
    return bucket, recipeId
end

function RecipeStore.SetActiveRecipe(self, recipeId)
    local bucket, normalizedId = GetExistingRecipeForWrite(self, recipeId)
    if bucket == nil then
        return nil, self.recipeNotFoundError
    end

    bucket.activeRecipeId = normalizedId
    return Util:DeepCopy(bucket.recipes[normalizedId])
end

function RecipeStore.RenameRecipe(self, recipeId, newName)
    recipeId = RecipeStore.NormalizeRecipeId(recipeId)
    newName = Util:NormalizeDisplayName(newName)
    if recipeId == nil or newName == nil then
        return nil, "invalid_recipe_name"
    end

    local bucket, normalizedId = GetExistingRecipeForWrite(self, recipeId)
    if bucket == nil then
        return nil, self.recipeNotFoundError
    end

    bucket.recipes[normalizedId].name = newName
    bucket.recipes[normalizedId].updatedAt = Util:GetTimestamp()
    return Util:DeepCopy(bucket.recipes[normalizedId])
end

function RecipeStore.SetRecipeCraftCount(self, recipeId, count)
    local bucket, normalizedId = GetExistingRecipeForWrite(self, recipeId)
    if bucket == nil then
        return nil, self.recipeNotFoundError
    end

    bucket.recipes[normalizedId].craftCount = RecipeStore.NormalizeCraftCount(count)
    bucket.recipes[normalizedId].updatedAt = Util:GetTimestamp()
    return Util:DeepCopy(bucket.recipes[normalizedId])
end

function RecipeStore.GetRecipeList(self)
    local bucket = self:GetCharacterBucketReadonly()
    local recipes = {}
    if type(bucket) ~= "table" or type(bucket.recipes) ~= "table" then
        return recipes
    end

    for _, recipeId in ipairs(bucket.recipeOrder or {}) do
        local recipe = bucket.recipes[recipeId]
        if type(recipe) == "table" then
            local copy = Util:DeepCopy(recipe)
            copy.isActive = bucket.activeRecipeId == recipeId
            recipes[#recipes + 1] = copy
        end
    end

    return recipes
end

function RecipeStore.DeleteRecipe(self, recipeId)
    local bucket, normalizedId = GetExistingRecipeForWrite(self, recipeId)
    if bucket == nil then
        return false, self.recipeNotFoundError
    end

    bucket.recipes[normalizedId] = nil
    if type(bucket.recipeOrder) == "table" then
        for index, value in ipairs(bucket.recipeOrder) do
            if value == normalizedId then
                table.remove(bucket.recipeOrder, index)
                break
            end
        end
    end
    if bucket.activeRecipeId == normalizedId then
        bucket.activeRecipeId = nil
    end

    return true
end

function RecipeStore.AddRecipe(self, bucket, recipe)
    bucket.recipes[recipe.id] = recipe
    bucket.recipeOrder[#bucket.recipeOrder + 1] = recipe.id
    if bucket.activeRecipeId == nil then
        bucket.activeRecipeId = recipe.id
    end
    return Util:DeepCopy(recipe)
end

function RecipeStore.Attach(self, recipeModule, savedVarsKey, notFoundError, hasCraftCount)
    recipeModule.recipeStoreKey = savedVarsKey
    recipeModule.recipeNotFoundError = notFoundError
    recipeModule.EnsureSavedVarsShape = RecipeStore.EnsureSavedVarsShape
    recipeModule.BuildDefaultCharacterBucket = RecipeStore.BuildDefaultCharacterBucket
    recipeModule.NormalizeCharacterBucket = RecipeStore.NormalizeCharacterBucket
    recipeModule.GetCharacterBucketReadonly = RecipeStore.GetCharacterBucketReadonly
    recipeModule.EnsureCharacterBucketForWrite = RecipeStore.EnsureCharacterBucketForWrite
    recipeModule.GenerateRecipeId = RecipeStore.GenerateRecipeId
    recipeModule.GetAutoApplyEnabled = RecipeStore.GetAutoApplyEnabled
    recipeModule.SetAutoApplyEnabled = RecipeStore.SetAutoApplyEnabled
    recipeModule.GetActiveRecipeId = RecipeStore.GetActiveRecipeId
    recipeModule.SetActiveRecipe = RecipeStore.SetActiveRecipe
    recipeModule.RenameRecipe = RecipeStore.RenameRecipe
    recipeModule.GetRecipeList = RecipeStore.GetRecipeList
    recipeModule.DeleteRecipe = RecipeStore.DeleteRecipe
    if hasCraftCount then
        recipeModule.SetRecipeCraftCount = RecipeStore.SetRecipeCraftCount
    end
end
