# LibExecuteSkills

Community library that provides a clean, shared database of **execute skills** for Elder Scrolls Online addons.

Instead of every addon hardcoding execute skill IDs, authors can depend on this library for reliable lookups and metadata.

## Features

- Check if an ability is an execute skill
- Get the execute health threshold percentage
- Get scaling type (`flat`, `linear`, or `explosion`)
- Retrieve full skill data (name, class, skill line, category, etc.)
- Filter skills by class or category
- Runtime registration of additional skills
- Safe data copying (no shared table references)
- Lightweight error handling (returns nil/false/empty table on bad input)

## Installation

1. Download and extract into your `AddOns` folder.
2. The folder must be named exactly `LibExecuteSkills`.
3. Enable the library in the AddOn menu (or let dependent addons load it automatically).

## Basic Usage

```lua
local LES = LibExecuteSkills

if LES:IsExecuteSkill(abilityId) then
    local percent = LES:GetExecutePercent(abilityId)
    local scaling = LES:GetScalingType(abilityId)
    local data = LES:GetSkillData(abilityId)
    -- data.name, data.class, data.skillLine, etc.
end

-- Get everything
local allExecutes = LES:GetExecuteSkillIds()   -- alias
-- or
local allExecutes = LES:GetAllSkills()