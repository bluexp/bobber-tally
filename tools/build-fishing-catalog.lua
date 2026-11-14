-- Run from the repository root: lua tools/build-fishing-catalog.lua > docs/fishing/catalog.json
local addon = {}
for _, file in ipairs({ "FishData", "CookingData", "EnglishCatalog" }) do
    assert(loadfile("addons/WowfFishing/" .. file .. ".lua"))("WowfFishing", addon)
end

local function String(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
        if character == '"' or character == '\\' then return '\\' .. character end
        return ("\\u%04x"):format(character:byte())
    end) .. '"'
end

local function JSON(value)
    if type(value) == "string" then return String(value) end
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    if #value > 0 then
        for _, item in ipairs(value) do parts[#parts + 1] = JSON(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for key, item in pairs(value) do parts[#parts + 1] = String(tostring(key)) .. ":" .. JSON(item) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local data, cooking, english = addon.FishData, addon.CookingData, addon.EnglishCatalog
local featuredZones = { 12, 17, 44 }
local featuredFish = { 6289, 6291, 6303, 6308, 6358, 6359, 6361, 6522, 251524, 6317 }
local zones, names = {}, {}
for id, name in pairs(data.zones) do
    zones[tostring(id)] = { zh = name, en = english.zones[id] or name, map = data.zoneMaps[id] }
end
for id, name in pairs(cooking.materialNames) do
    names[tostring(id)] = { zh = name, en = english.items[id] or name }
end
local fish, recipes = {}, {}
for _, entry in ipairs(data.entries) do
    names[tostring(entry.id)] = { zh = entry.name, en = english.items[entry.id] or entry.name }
    fish[#fish + 1] = { id = entry.id, zones = #entry.zones > 0 and entry.zones or nil, uses = entry.uses,
        reported = entry.zoneSource:find("无限服玩家报告", 1, true) ~= nil }
end
for _, entry in ipairs(cooking.entries) do
    names[tostring(entry.itemID)] = { zh = entry.itemName, en = english.items[entry.itemID] or entry.itemName }
    recipes[#recipes + 1] = { id = entry.itemID, quantity = entry.quantity, materials = entry.materials }
end
print(JSON({ build = data.build, featuredZones = featuredZones, featuredFish = featuredFish,
    zones = zones, items = names, fish = fish, recipes = recipes }))
