-- What stands between you and each locked door.
-- Checked against Wowhead's Forever pages by tools/bake_attune.py: a step whose name
-- does not come back the same is left out rather than shipped wrong. Nothing here is
-- taken from the Attune addon, which is All Rights Reserved.
--
-- ns.attune[i] = { place, side, steps = { { kind, id, name } } }
-- kind: q a quest you must have finished, i an item you must hold, r a reputation
local _, ns = ...
ns.attune = {
    { place = "Blackrock Depths", side = "both", steps = {
        { "i", 11000, "Shadowforge Key" },
        { "i", 11197, "Dark Keeper Key" },
    } },
    { place = "Upper Blackrock Spire", side = "both", steps = {
        { "q", 4742, "Seal of Ascension" },
        { "i", 12219, "Unadorned Seal of Ascension" },
        { "i", 12335, "Gemstone of Smolderthorn" },
        { "i", 12336, "Gemstone of Spirestone" },
        { "i", 12337, "Gemstone of Bloodaxe" },
    } },
    { place = "Scholomance", side = "both", steps = {
        { "i", 13704, "Skeleton Key" },
    } },
    { place = "Stratholme", side = "both", steps = {
        { "i", 12382, "Key to the City" },
        { "q", 5214, "The Great Fras Siabi" },
    } },
    { place = "Dire Maul", side = "both", steps = {
        { "i", 18249, "Crescent Key" },
        { "i", 18250, "Gordok Shackle Key" },
    } },
    { place = "Maraudon", side = "both", steps = {
        { "q", 7046, "The Scepter of Celebras" },
        { "i", 17191, "Scepter of Celebras" },
    } },
    { place = "Molten Core", side = "both", steps = {
        { "q", 7848, "Attunement to the Core" },
        { "i", 17333, "Aqual Quintessence" },
    } },
    { place = "Onyxia's Lair", side = "alliance", steps = {
        { "q", 6502, "Drakefire Amulet" },
    } },
    { place = "Onyxia's Lair", side = "horde", steps = {
        { "q", 4903, "Warlord's Command" },
    } },
    { place = "Blackwing Lair", side = "both", steps = {
        { "q", 7761, "Blackhand's Command" },
    } },
    { place = "Naxxramas", side = "both", steps = {
        { "r", 529, "Argent Dawn" },
    } },
}
