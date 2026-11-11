-- Cooking skill line 185, from the Forever 1.60.1.70862 client data.
-- See README.md for the source and selection criteria.
local _, addon = ...

addon.CookingData = {
    materialNames = {
        [159] = "清凉的泉水",
        [2678] = "甜香料",
        [2692] = "辣椒",
        [3713] = "舒心草",
    },
    entries = {
        {
            spellID = 7751, name = "闪亮小鱼",
            itemID = 6290, itemName = "闪亮小鱼", quantity = 1,
            yellow = 45, grey = 85,
            materials = { { 6291, 1 } },
        },
        {
            spellID = 7752, name = "滑皮鲭鱼",
            itemID = 787, itemName = "滑皮鲭鱼", quantity = 1,
            yellow = 45, grey = 85,
            materials = { { 6303, 1 } },
        },
        {
            spellID = 7753, name = "长颌泥鲷",
            itemID = 4592, itemName = "长颌泥鲷", quantity = 1,
            yellow = 90, grey = 130,
            materials = { { 6289, 1 } },
        },
        {
            spellID = 7754, name = "洛克湖狂鱼",
            itemID = 6316, itemName = "洛克湖狂鱼", quantity = 1,
            yellow = 90, grey = 130,
            materials = { { 6317, 1 }, { 2678, 1 } },
        },
        {
            spellID = 7827, name = "彩鳍鱼",
            itemID = 5095, itemName = "彩鳍鱼", quantity = 1,
            yellow = 90, grey = 130,
            materials = { { 6361, 1 } },
        },
        {
            spellID = 25704, name = "烤鼠尾鱼",
            itemID = 21072, itemName = "烤鼠尾鱼", quantity = 1,
            yellow = 120, grey = 160,
            materials = { { 21071, 1 }, { 2678, 1 } },
        },
        {
            spellID = 8238, name = "美味变异鱼",
            itemID = 6657, itemName = "美味变异鱼", quantity = 1,
            yellow = 125, grey = 165,
            materials = { { 6522, 1 }, { 2678, 1 } },
        },
        {
            spellID = 1252566, name = "美味奇想鳍鱼",
            itemID = 251525, itemName = "美味奇想鳍鱼", quantity = 1,
            yellow = 125, grey = 165,
            materials = { { 251524, 1 }, { 2678, 1 } },
        },
        {
            spellID = 7755, name = "刺须鲶鱼",
            itemID = 4593, itemName = "刺须鲶鱼", quantity = 1,
            yellow = 140, grey = 180,
            materials = { { 6308, 1 } },
        },
        {
            spellID = 7828, name = "石鳞鳕鱼",
            itemID = 4594, itemName = "石鳞鳕鱼", quantity = 1,
            yellow = 190, grey = 230,
            materials = { { 6362, 1 } },
        },
        {
            spellID = 1247741, name = "刺脊比目鱼",
            itemID = 8957, itemName = "刺脊比目鱼", quantity = 1,
            yellow = 210, grey = 220,
            materials = { { 8959, 1 } },
        },
        {
            spellID = 20916, name = "秘银冠鳟",
            itemID = 8364, itemName = "秘银冠鳟", quantity = 1,
            yellow = 215, grey = 255,
            materials = { { 8365, 1 } },
        },
        {
            spellID = 25954, name = "美味鼠尾鱼",
            itemID = 21217, itemName = "美味鼠尾鱼", quantity = 1,
            yellow = 215, grey = 255,
            materials = { { 21153, 1 }, { 2692, 1 } },
        },
        {
            spellID = 1319313, name = "板鳞鱼",
            itemID = 286152, itemName = "板鳞鱼", quantity = 1,
            yellow = 245, grey = 255,
            materials = { { 13890, 1 }, { 3713, 1 } },
        },
        {
            spellID = 18238, name = "斑点黄尾鱼",
            itemID = 6887, itemName = "斑点黄尾鱼", quantity = 1,
            yellow = 265, grey = 305,
            materials = { { 4603, 1 } },
        },
        {
            spellID = 18239, name = "煮熟的光滑大鱼",
            itemID = 13927, itemName = "煮熟的光滑大鱼", quantity = 1,
            yellow = 265, grey = 305,
            materials = { { 13754, 1 }, { 3713, 1 } },
        },
        {
            spellID = 18241, name = "油炸红腮鱼",
            itemID = 13930, itemName = "油炸红腮鱼", quantity = 1,
            yellow = 265, grey = 305,
            materials = { { 13758, 1 } },
        },
        {
            spellID = 18240, name = "烤鱿鱼",
            itemID = 13928, itemName = "烤鱿鱼", quantity = 1,
            yellow = 280, grey = 320,
            materials = { { 13755, 1 }, { 3713, 1 } },
        },
        {
            spellID = 18242, name = "烟熏鲈鱼",
            itemID = 13929, itemName = "烟熏鲈鱼", quantity = 1,
            yellow = 280, grey = 320,
            materials = { { 13756, 1 }, { 2692, 2 } },
        },
        {
            spellID = 18243, name = "夜鳞鱼汤",
            itemID = 13931, itemName = "夜鳞鱼汤", quantity = 1,
            yellow = 290, grey = 330,
            materials = { { 13759, 1 }, { 159, 1 } },
        },
        {
            spellID = 18244, name = "水煮阳鳞鲑鱼",
            itemID = 13932, itemName = "水煮阳鳞鲑鱼", quantity = 1,
            yellow = 290, grey = 330,
            materials = { { 13760, 1 } },
        },
        {
            spellID = 18245, name = "炖龙虾",
            itemID = 13933, itemName = "炖龙虾", quantity = 1,
            yellow = 315, grey = 355,
            materials = { { 13888, 1 }, { 159, 1 } },
        },
        {
            spellID = 18246, name = "大鱼片",
            itemID = 13934, itemName = "大鱼片", quantity = 1,
            yellow = 315, grey = 355,
            materials = { { 13893, 1 }, { 2692, 1 }, { 3713, 1 } },
        },
        {
            spellID = 18247, name = "烤鲑鱼",
            itemID = 13935, itemName = "烤鲑鱼", quantity = 1,
            yellow = 315, grey = 355,
            materials = { { 13889, 1 }, { 3713, 1 } },
        },
    },
}
