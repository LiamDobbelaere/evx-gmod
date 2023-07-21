local EVXHL2 = {}

local hl2maps = {
    "d1_trainstation_01",
    "d1_trainstation_02",
    "d1_trainstation_03",
    "d1_trainstation_04",
    "d1_trainstation_05",
    "d1_trainstation_06",
    "d1_canals_01",
    "d1_canals_01a",
    "d1_canals_02",
    "d1_canals_03",
    "d1_canals_05",
    "d1_canals_06",
    "d1_canals_07",
    "d1_canals_08",
    "d1_canals_09",
    "d1_canals_10",
    "d1_canals_11",
    "d1_canals_12",
    "d1_canals_13",
    "d1_eli_01",
    "d1_eli_02",
    "d1_town_01",
    "d1_town_01a",
    "d1_town_02",
    "d1_town_03",
    "d1_town_02a",
    "d1_town_04",
    "d1_town_05",
    "d2_coast_01",
    "d2_coast_03",
    "d2_coast_04",
    "d2_coast_05",
    "d2_coast_07",
    "d2_coast_08",
    "d2_coast_09",
    "d2_coast_10",
    "d2_coast_11",
    "d2_coast_12",
    "d2_prison_01",
    "d2_prison_02",
    "d2_prison_03",
    "d2_prison_04",
    "d2_prison_05",
    "d2_prison_06",
    "d2_prison_07",
    "d2_prison_08",
    "d3_c17_01",
    "d3_c17_02",
    "d3_c17_03",
    "d3_c17_04",
    "d3_c17_05",
    "d3_c17_06a",
    "d3_c17_06b",
    "d3_c17_07",
    "d3_c17_08",
    "d3_c17_09",
    "d3_c17_10a",
    "d3_c17_10b",
    "d3_c17_11",
    "d3_c17_12",
    "d3_c17_12b",
    "d3_c17_13",
    "d3_citadel_01",
    "d3_citadel_02",
    "d3_citadel_03",
    "d3_citadel_04",
    "d3_citadel_05",
    "d3_breen_01",
};

local hl2mapSpecificWeights = {
    ["d1_town_01"] = {
        ["nothing"] = 0,
        ["cloaked"] = 100,
        ["possessed"] = 100,
        ["spy"] = 1,
        ["mix2"] = 1,
        -- ["spidersack"] = GetSpawnRateFor("spidersack"),
        -- ["possessed"] = GetSpawnRateFor("possessed"),
        -- ["gas"] = GetSpawnRateFor("gas"),
        -- ["lifesteal"] = GetSpawnRateFor("lifesteal"),
        -- ["metal"] = GetSpawnRateFor("metal"),
        -- ["gnome"] = GetSpawnRateFor("gnome"),
        -- ["knockback"] = GetSpawnRateFor("knockback"),
        -- ["puller"] = GetSpawnRateFor("puller"),
        -- ["pyro"] = GetSpawnRateFor("pyro"),
        -- ["explosion"] = GetSpawnRateFor("explosion"),
        -- ["cloaked"] = GetSpawnRateFor("cloaked"),
        -- ["mommy"] = GetSpawnRateFor("mommy"),
        -- ["boss"] = GetSpawnRateFor("boss"),
        -- ["bigboss"] = GetSpawnRateFor("bigboss"),
        -- ["mix2"] = GetSpawnRateFor("mix2"),
        -- ["spy"] = GetSpawnRateFor("spy"),
    }
}

function EVXHL2.IsHalfLife2Map()
    local map = game.GetMap()

    print(game.GetMap())

    return table.HasValue(hl2maps, map)
end

function EVXHL2.GetMapSpecificWeights()
    local map = game.GetMap()

    if hl2mapSpecificWeights[map] then
        return hl2mapSpecificWeights[map]
    else
        return {}
    end
end

return EVXHL2