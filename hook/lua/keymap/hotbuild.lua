-- Smart Factory
-- Merged mod: Alternative Preset Fix + Factory Smart Templates
-- Hook for /lua/keymap/hotbuild.lua

-- ============================================================
-- Shared helpers
-- ============================================================

local function GetUnitTech(unitId)
    local bp = __blueprints[unitId]
    if not bp then return 0 end
    local cats = bp.CategoriesHash
    if not cats then
        local arr = bp.Categories
        if not arr then return 0 end
        cats = {}
        for _, c in arr do cats[c] = true end
    end
    if cats['EXPERIMENTAL'] then return 4 end
    if cats['TECH3'] then return 3 end
    if cats['TECH2'] then return 2 end
    if cats['TECH1'] then return 1 end
    return 0
end

local function GetFactoryTech(selection)
    local sharedTech = nil
    for _, unit in selection do
        local bp = unit:GetBlueprint()
        if not bp then return nil end
        local cats = bp.CategoriesHash
        if not cats then
            local arr = bp.Categories
            if not arr then return nil end
            cats = {}
            for _, c in arr do cats[c] = true end
        end
        if not cats['FACTORY'] then return nil end
        local t = nil
        if cats['EXPERIMENTAL'] then t = 4
        elseif cats['TECH3'] then t = 3
        elseif cats['TECH2'] then t = 2
        elseif cats['TECH1'] then t = 1
        end
        if not t then return nil end
        if sharedTech == nil then
            sharedTech = t
        elseif sharedTech ~= t then
            return nil
        end
    end
    return sharedTech
end

-- ============================================================
-- Alternative Preset Fix (buildActionUnit)
-- ============================================================

local OldBuildActionUnit = buildActionUnit

function buildActionUnit(name, modifier)
    local selection = GetSelectedUnits()
    if not selection or table.empty(selection) then
        OldBuildActionUnit(name, modifier)
        return
    end

    local sharedTech = GetFactoryTech(selection)
    if not sharedTech then
        OldBuildActionUnit(name, modifier)
        return
    end

    local Construction = import('/lua/ui/game/construction.lua')
    local activeTech = Construction.GetCurrentTechTab()
    local targetTech = activeTech or sharedTech

    local values = unitkeygroups[name]
    if not values then
        OldBuildActionUnit(name, modifier)
        return
    end

    local availableOrders, availableToggles, buildableCategories = GetUnitCommandData(selection)
    local buildable = EntityCategoryGetUnitList(buildableCategories)

    local effectiveValues = {}
    for _, value in values do
        for i, buildableValue in buildable do
            if value == buildableValue then
                table.insert(effectiveValues, value)
            end
        end
    end

    local maxPos = table.getsize(effectiveValues)
    if maxPos <= 1 then
        OldBuildActionUnit(name, modifier)
        return
    end

    local targetPos = nil
    for i, unitId in effectiveValues do
        local t = GetUnitTech(unitId)
        if t == targetTech then
            targetPos = i
            break
        end
    end

    if not targetPos then
        OldBuildActionUnit(name, modifier)
        return
    end

    cycleLastName = nil
    cycleUnits(maxPos, name, effectiveValues, selection, modifier)
    cyclePos = targetPos

    hotbuildCyclePreview(maxPos, false)

    local unit = effectiveValues[cyclePos]
    local count = modifier == 'Shift' and 5 or 1
    local filteredUnits = TranslateExFacUnits(selection)
    if filteredUnits then
        IssueBlueprintCommandToUnits(filteredUnits, "UNITCOMMAND_BuildFactory", unit, count)
    else
        IssueBlueprintCommand("UNITCOMMAND_BuildFactory", unit, count)
    end
    Construction.RefreshUI()
end
