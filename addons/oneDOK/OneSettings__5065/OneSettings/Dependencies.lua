local OS = OneSettings
OS.Dependencies = {}

-- The installed catalog stays fixed until ReloadUI; reuse its reverse edges for edits.
function OS.Dependencies.Reverse(catalog)
    local reverse = {}
    for dependent, node in pairs(catalog) do
        for _, dependency in ipairs(node.dependencies) do
            reverse[dependency.name] = reverse[dependency.name] or {}
            reverse[dependency.name][#reverse[dependency.name] + 1] = dependent
        end
    end
    return reverse
end

-- Disabling a non-library component also disables its mandatory dependents.
-- Libraries stay protected while another active addon needs them.
function OS.Dependencies.Edit(catalog, edits, name, enabled, reverse)
    local result = {}
    for addon, state in pairs(edits) do result[addon] = state end
    result[name] = enabled
    if enabled or not catalog[name] or catalog[name].library then return result end
    reverse = reverse or OS.Dependencies.Reverse(catalog)
    local queue, visited, cursor = { name }, { [name] = true }, 1
    while cursor <= #queue do
        local parent = queue[cursor]
        cursor = cursor + 1
        for _, dependent in ipairs(reverse[parent] or {}) do
            result[dependent] = false
            if not visited[dependent] then
                visited[dependent] = true
                queue[#queue + 1] = dependent
            end
        end
    end
    return result
end

-- Row checks need only this addon's dependency closure, not a full resolved snapshot.
function OS.Dependencies.Check(catalog, name)
    if not catalog[name] then return false, false end
    local queue, seen, cursor, compatible = { name }, { [name] = true }, 1, true
    while cursor <= #queue do
        local node = catalog[queue[cursor]]
        cursor = cursor + 1
        for _, dependency in ipairs(node.dependencies) do
            local child = catalog[dependency.name]
            if not child then return false, false end
            if child.version < dependency.minimum then compatible = false end
            if not seen[dependency.name] then
                seen[dependency.name] = true
                queue[#queue + 1] = dependency.name
            end
        end
    end
    return true, compatible
end

-- Only mandatory dependencies returned by GetAddOnNumDependencies are in this graph.
-- A marked work list terminates on cycles and has no Lua recursion depth limit.
function OS.Dependencies.Resolve(catalog, requested)
    local result, needed, queue, issues, seenIssues = {}, {}, {}, {}, {}
    local function issue(name)
        if not seenIssues[name] then
            seenIssues[name] = true
            issues[#issues + 1] = name
        end
    end
    for name, node in pairs(catalog) do
        result[name] = requested[name] == true
        if result[name] and not node.library then
            needed[name] = true
            queue[#queue + 1] = name
        end
    end
    local cursor = 1
    while cursor <= #queue do
        local name = queue[cursor]
        cursor = cursor + 1
        for _, dependency in ipairs(catalog[name].dependencies) do
            local child = catalog[dependency.name]
            if child then
                if child.version < dependency.minimum then issue(dependency.name) end
                if not needed[dependency.name] then
                    needed[dependency.name] = true
                    queue[#queue + 1] = dependency.name
                end
                result[dependency.name] = true
            else
                issue(dependency.name)
            end
        end
    end
    for name, node in pairs(catalog) do
        if node.library then result[name] = needed[name] == true end
    end
    table.sort(issues)
    return result, issues
end
