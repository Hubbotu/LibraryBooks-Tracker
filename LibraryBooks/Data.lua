local _, ns = ...
local K, E = 1414, 1415
local function S(map, x, y, kind, d) return { map = map, x = x, y = y, kind = kind, d = d } end
local function B(id, q, cont, mode, extra, locs)
    local t = extra or {}
    t.id, t.q, t.cont, t.mode, t.locs = id, q, cont, mode, locs
    ns.books[#ns.books + 1] = t
end
ns.books = {}

-- Kalimdor
B("etiquette", 81952, K, "solo", nil, { S(1447, 20.8, 62.0) })
B("almanac", 78124, K, "solo", nil, { S(1439, 59.6, 22.2) })
B("demons", 79950, K, "group", nil, { S(1443, 55.1, 26.2) })
B("rwl", 79952, K, "group", nil, { S(1445, 57.3, 20.4) })
B("northern", 84397, K, "solo", { hard = true }, { S(1448, 65.2, 3.3) })
B("liminal", nil, K, "missing", nil, { S(1444, 50.6, 15.7, "unconfirmed") })
B("tazo", 79094, K, "solo", { fav = "Horde" }, { S(1454, 38.7, 78.4) })
B("fury", 78149, K, "solo", nil, { S(1442, 74.4, 85.7) })
B("tidesages", 81949, K, "group", { hard = true }, { S(1446, 72.7, 47.8) })
B("arcanic", 78145, K, "solo", nil, { S(1413, 56.3, 8.8) })
B("baxtan", 79097, K, "solo", nil, { S(1413, 62.7, 36.3) })
B("dreamers", 78143, K, "solo", nil, { S(1413, 52.8, 54.7) })
B("geomancy", 79947, K, "group", { minLevel = 28 }, { S(1441, 34.5, 40.0), S(1441, 31.37, 36.87, "entrance") })
B("kaboom", 84399, K, "solo", { hard = true, long = true }, { S(1452, 60.7, 37.7) })
-- Eastern Kingdoms
B("defensive", 79948, E, "solo", nil, { S(1416, 48.5, 57.6) })
B("web", 79949, E, "depends", nil, { S(1417, 73.7, 65.5) })
B("mummies", 79951, E, "solo", nil, { S(1418, 56.6, 39.9) })
B("conjurer", 81956, E, "solo", { wait = true }, { S(1419, 55.5, 32.2, "approx") })
B("stonewrought", 81953, E, "solo", nil, { S(1428, 29.1, 28.9) })
B("magma", 84396, E, "solo", nil, { S(1428, 26.2, 22.5) })
B("anatomy", 78147, E, "solo", nil, { S(1431, 16.7, 28.5), S(1431, 16.0, 38.7, "entrance") })
B("light", 84398, E, "solo", nil, { S(1423, 71.8, 48.3) })
B("scourge", 84401, E, "solo", nil, { S(1423, 26.5, 15.1) })
B("knight", 84400, E, "solo", nil, { S(1423, 47.3, 42.2) })
B("theocritus", 79092, E, "solo", nil, { S(1429, 65.4, 70.1) })
B("venomous", 81954, E, "solo", nil, { S(1425, 36.0, 72.8) })
B("antonidas", 79091, E, "depends", { fav = "Alliance" }, { S(1455, 75.8, 11.6) })
B("rumi", 79093, E, "solo", nil, { S(1432, 35.6, 48.9, nil, "rumi1"), S(1436, 52.9, 53.4, nil, "rumi2") })
B("runes", 78148, E, "solo", nil, { S(1432, 77.5, 14.0) })
B("metal", 81955, E, "group", { hard = true }, { S(1427, 37.9, 49.6) })
B("ataeric", 79096, E, "solo", nil, { S(1421, 43.4, 41.2, "disputed") })
B("digest", 78127, E, "solo", nil, { S(1421, 63.5, 63.2) })
B("basilisks", 79535, E, "pet", nil, { S(1434, 41.5, 50.9) })
B("luddite", 79953, E, "group", nil, { S(1435, 61.6, 22.4) })
B("sanguine", 81947, E, "solo", nil, { S(1435, 70.5, 52.0) })
B("apothecary", 79095, E, "depends", { fav = "Horde" }, { S(1420, 59.5, 52.3) })
B("necromancy", 84402, E, "solo", nil, { S(1422, 69.2, 72.3) })
B("potatoes", 84395, E, "solo", nil, { S(1422, 38.2, 54.6) })
B("bewitchments", 78142, E, "solo", nil, { S(1436, 45.5, 70.3) })
B("goaz", 78146, E, "solo", nil, { S(1437, 33.6, 47.9) })

ns.bookItems = {
    defensive = 215815,
    web = 215816,
    mummies = 215820,
    conjurer = 220353,
    anatomy = 209849,
    light = 228135,
    scourge = 228140,
    knight = 228138,
    theocritus = 203755,
    venomous = 220350,
    antonidas = 203754,
    rumi = 208860,
    runes = 209850,
    metal = 220352,
    ataeric = 210177,
    digest = 209844,
    basilisks = 213165,
    sanguine = 220345,
    luddite = 215824,
    apothecary = 208185,
    necromancy = 228141,
    potatoes = 228132,
    bewitchments = 209845,
    goaz = 209848,
    stonewrought = 220349,
    magma = 228133,
    etiquette = 220348,
    almanac = 209843,
    demons = 215817,
    rwl = 215822,
    northern = 228134,
    tazo = 207972,
    fury = 209851,
    tidesages = 220346,
    arcanic = 209847,
    baxtan = 208800,
    dreamers = 209846,
    geomancy = 215683,
    kaboom = 228136,
    liminal = 220347,
}

ns.bookByID = {}
for i, b in ipairs(ns.books) do
    b.order = i; b.item = ns.bookItems[b.id]; ns.bookByID[b.id] = b
    for n, loc in ipairs(b.locs) do loc.alt = n > 1 end 
end

ns.quests = {
    { key = 1, id = 78150, need = 10, level = 1, items = { 277203, 277204 } },
    { key = 2, id = 79536, need = 20, level = 20, items = { 281634, 281635 } },
    { key = 3, id = 82208, need = 25, level = 35, items = { 277254, 277258, 277260 } },
    { key = 4, id = 84394, need = 38, level = 50, items = { 281637, 281636, 277202 } },
}

ns.turnIn = {
    Alliance = S(1453, 49.0, 86.4),
    Horde = S(1458, 73.8, 32.2),
}
