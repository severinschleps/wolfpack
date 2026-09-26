-- Spell data lifted from What's Training? (MIT licence, Copyright (c) 2019 Sveng),
-- Classes/Camelot -- the tables it ships for this client. Nothing here is our own research.
-- https://www.curseforge.com/wow/addons/whats-training
--
-- Shape: ns.training.CLASS[level] = { { id, cost, requiredIds?, requiredTalentId?, race?/races?,
-- faction? }, ... }. Cost is in copper.
local _, ns = ...
ns.training = {}

ns.training.DRUID = {
    [1] = {{id = 1126, cost = 10}},
    [4] = {{id = 8921, cost = 100}, {id = 774, cost = 100}},
    [6] = {{id = 467, cost = 100}, {id = 5177, cost = 100, requiredIds = {5176}}},
    [8] = {{id = 339, cost = 200}, {id = 5186, cost = 200, requiredIds = {5185}}},
    [10] = {
        {id = 99, cost = 300, requiredIds = {5487}},
        {id = 5232, cost = 300, requiredIds = {1126}},
        {id = 8924, cost = 300, requiredIds = {8921}},
        {id = 16689, cost = 300, requiredIds = {339}},
        {id = 1058, cost = 300, requiredIds = {774}}
    },
    [12] = {{id = 5229, cost = 800, requiredIds = {5487}}, {id = 8936, cost = 800}, {id = 437138, cost = 800}},
    [14] = {
        {id = 5211, cost = 900, requiredIds = {5487}},
        {id = 5187, cost = 900, requiredIds = {5186}},
        {id = 782, cost = 900, requiredIds = {467}},
        {id = 5178, cost = 900, requiredIds = {5177}}
    },
    [16] = {
        {id = 8925, cost = 1400, requiredIds = {8924}},
        {id = 1430, cost = 1400, requiredIds = {1058}},
        {id = 779, cost = 1400, requiredIds = {5487}}
    },
    [18] = {
        {id = 1062, cost = 1500, requiredIds = {339}},
        {id = 770, cost = 1500},
        {id = 2637, cost = 1500},
        {id = 6808, cost = 1500, requiredIds = {6807}},
        {id = 16810, cost = 1500, requiredIds = {16689, 1062}},
        {id = 8938, cost = 1500, requiredIds = {8936}}
    },
    [20] = {
        {id = 1735, cost = 2400, requiredIds = {99}},
        {id = 5188, cost = 2400, requiredIds = {5187}},
        {id = 6756, cost = 2400, requiredIds = {5232}},
        {id = 16864, cost = 2400},
        {id = 20484, cost = 2400},
        {id = 2912, cost = 2400},
        {id = 768, cost = 2000},
        {id = 1079, cost = 2000},
        {id = 1082, cost = 2000},
        {id = 5215, cost = 2000}
    },
    [22] = {
        {id = 8926, cost = 3300, requiredIds = {8925}},
        {id = 2090, cost = 3300, requiredIds = {1430}},
        {id = 5221, cost = 3300, requiredIds = {768}},
        {id = 2908, cost = 3300},
        {id = 5179, cost = 3300, requiredIds = {5178}}
    },
    [24] = {
        {id = 1822, cost = 3800, requiredIds = {768}},
        {id = 8939, cost = 3800, requiredIds = {8938}},
        {id = 2782, cost = 3800},
        {id = 1237948, cost = 3800, requiredIds = {437138}},
        {id = 780, cost = 3800, requiredIds = {779}},
        {id = 1075, cost = 3800, requiredIds = {782}},
        {id = 5217, cost = 3800, requiredIds = {768}}
    },
    [26] = {
        {id = 2893, cost = 4400},
        {id = 1850, cost = 4400, requiredIds = {768}},
        {id = 5189, cost = 4400, requiredIds = {5188}},
        {id = 6809, cost = 4400, requiredIds = {6808}},
        {id = 8949, cost = 4400, requiredIds = {2912}}
    },
    [28] = {
        {id = 5209, cost = 4500, requiredIds = {5487}},
        {id = 3029, cost = 4500, requiredIds = {16942}, requiredTalentId = 16942},
        {id = 8998, cost = 4500, requiredIds = {768}},
        {id = 5195, cost = 4500, requiredIds = {1062}},
        {id = 8927, cost = 4500, requiredIds = {8926}},
        {id = 16811, cost = 4500, requiredIds = {16810, 5195}},
        {id = 2091, cost = 4500, requiredIds = {2090}},
        {id = 9492, cost = 4500, requiredIds = {1079}}
    },
    [30] = {
        {id = 6798, cost = 4600, requiredIds = {5211}},
        {id = 778, cost = 4600, requiredIds = {770}},
        {id = 24974, cost = 4600, requiredIds = {5570}, requiredTalentId = 5570},
        {id = 5234, cost = 4600, requiredIds = {6756}},
        {id = 20739, cost = 4600, requiredIds = {20484}},
        {id = 8940, cost = 4600, requiredIds = {8939}},
        {id = 6800, cost = 4600, requiredIds = {5221}},
        {id = 740, cost = 4600},
        {id = 783, cost = 4600},
        {id = 5180, cost = 4600, requiredIds = {5179}}
    },
    [32] = {
        {id = 9490, cost = 5000, requiredIds = {1735}},
        {id = 22568, cost = 5000, requiredIds = {768}},
        {id = 6778, cost = 5000, requiredIds = {5189}},
        {id = 6785, cost = 5000, requiredIds = {768}},
        {id = 5225, cost = 5000, requiredIds = {768}}
    },
    [34] = {
        {id = 8972, cost = 7000, requiredIds = {6809}},
        {id = 8928, cost = 7000, requiredIds = {8927}},
        {id = 1823, cost = 7000, requiredIds = {1822}},
        {id = 3627, cost = 7000, requiredIds = {2091}},
        {id = 8950, cost = 7000, requiredIds = {8949}},
        {id = 769, cost = 7000, requiredIds = {780}},
        {id = 8914, cost = 7000, requiredIds = {1075}}
    },
    [36] = {
        {id = 22842, cost = 8000, requiredIds = {5487}},
        {id = 9005, cost = 8000, requiredIds = {768}},
        {id = 8941, cost = 8000, requiredIds = {8940}},
        {id = 1237949, cost = 8000, requiredIds = {1237948}},
        {id = 9493, cost = 8000, requiredIds = {9492}}
    },
    [38] = {
        {id = 5201, cost = 10000, requiredIds = {3029}, requiredTalentId = 16942},
        {id = 5196, cost = 10000, requiredIds = {5195}},
        {id = 8903, cost = 10000, requiredIds = {6778}},
        {id = 18657, cost = 10000, requiredIds = {2637}},
        {id = 16812, cost = 10000, requiredIds = {16811, 5196}},
        {id = 8992, cost = 10000, requiredIds = {6800}},
        {id = 8955, cost = 10000, requiredIds = {2908}},
        {id = 6780, cost = 10000, requiredIds = {5180}}
    },
    [40] = {
        {id = 9000, cost = 11000, requiredIds = {8998}},
        {id = 9634, cost = 11000, requiredIds = {5487}},
        {id = 20719, cost = 11000, requiredIds = {768}},
        {id = 22827, cost = 11000, requiredIds = {22568}},
        {id = 16914, cost = 11000},
        {id = 29166, cost = 11000},
        {id = 24975, cost = 11000, requiredIds = {24974}, requiredTalentId = 5570},
        {id = 8907, cost = 11000, requiredIds = {5234}},
        {id = 8929, cost = 11000, requiredIds = {8928}},
        {id = 6783, cost = 11000, requiredIds = {5215}},
        {id = 20742, cost = 11000, requiredIds = {20739}},
        {id = 8910, cost = 11000, requiredIds = {3627}},
        {id = 8918, cost = 11000, requiredIds = {740}}
    },
    [42] = {
        {id = 9747, cost = 12000, requiredIds = {9490}},
        {id = 9749, cost = 12000, requiredIds = {778}},
        {id = 414644, cost = 12000, requiredIds = {9634}},
        {id = 9745, cost = 12000, requiredIds = {8972}},
        {id = 6787, cost = 12000, requiredIds = {6785}},
        {id = 9750, cost = 12000, requiredIds = {8941}},
        {id = 8951, cost = 12000, requiredIds = {8950}}
    },
    [44] = {
        {id = 22812, cost = 13000},
        {id = 9758, cost = 13000, requiredIds = {8903}},
        {id = 1824, cost = 13000, requiredIds = {1823}},
        {id = 9752, cost = 13000, requiredIds = {9493}},
        {id = 9754, cost = 13000, requiredIds = {769}},
        {id = 9756, cost = 13000, requiredIds = {8914}}
    },
    [46] = {
        {id = 8983, cost = 16000, requiredIds = {6798}},
        {id = 9821, cost = 16000, requiredIds = {1850}},
        {id = 9833, cost = 16000, requiredIds = {8929}},
        {id = 9823, cost = 16000, requiredIds = {9005}},
        {id = 9839, cost = 16000, requiredIds = {8910}},
        {id = 9829, cost = 16000, requiredIds = {8992}},
        {id = 8905, cost = 16000, requiredIds = {6780}}
    },
    [48] = {
        {id = 9849, cost = 17000, requiredIds = {5201}, requiredTalentId = 16942},
        {id = 9852, cost = 17000, requiredIds = {5196}},
        {id = 22828, cost = 17000, requiredIds = {22827}},
        {id = 16813, cost = 17000, requiredIds = {16812, 9852}},
        {id = 9856, cost = 17000, requiredIds = {9750}},
        {id = 1237950, cost = 17000, requiredIds = {1237949}}
    },
    [50] = {
        {id = 9888, cost = 18000, requiredIds = {9758}},
        {id = 17401, cost = 18000, requiredIds = {16914}},
        {id = 24976, cost = 18000, requiredIds = {24975}, requiredTalentId = 5570},
        {id = 1235826, cost = 18000, requiredIds = {414644}},
        {id = 9884, cost = 18000, requiredIds = {8907}},
        {id = 9880, cost = 18000, requiredIds = {9745}},
        {id = 9866, cost = 18000, requiredIds = {6787}},
        {id = 20747, cost = 18000, requiredIds = {20742}},
        {id = 9875, cost = 18000, requiredIds = {8951}},
        {id = 9862, cost = 18000, requiredIds = {8918}},
        {id = 1238214, cost = 18000, requiredIds = {408120}, requiredTalentId = 408120}
    },
    [52] = {
        {id = 9892, cost = 19000, requiredIds = {9000}},
        {id = 9898, cost = 19000, requiredIds = {9747}},
        {id = 9834, cost = 19000, requiredIds = {9833}},
        {id = 9840, cost = 19000, requiredIds = {9839}},
        {id = 9894, cost = 19000, requiredIds = {9752}}
    },
    [54] = {
        {id = 9907, cost = 20000, requiredIds = {9749}},
        {id = 9904, cost = 20000, requiredIds = {1824}},
        {id = 9857, cost = 20000, requiredIds = {9856}},
        {id = 9830, cost = 20000, requiredIds = {9829}},
        {id = 9901, cost = 20000, requiredIds = {8955}},
        {id = 9908, cost = 20000, requiredIds = {9754}},
        {id = 9910, cost = 20000, requiredIds = {9756}},
        {id = 9912, cost = 20000, requiredIds = {8905}}
    },
    [56] = {
        {id = 22829, cost = 21000, requiredIds = {22828}},
        {id = 9889, cost = 21000, requiredIds = {9888}},
        {id = 9827, cost = 21000, requiredIds = {9823}}
    },
    [58] = {
        {id = 9850, cost = 22000, requiredIds = {9849}, requiredTalentId = 16942},
        {id = 9853, cost = 22000, requiredIds = {9852}},
        {id = 18658, cost = 22000, requiredIds = {18657}},
        {id = 1235827, cost = 22000, requiredIds = {1235826}},
        {id = 9881, cost = 22000, requiredIds = {9880}},
        {id = 9835, cost = 22000, requiredIds = {9834}},
        {id = 17329, cost = 22000, requiredIds = {16813, 9853}},
        {id = 9867, cost = 22000, requiredIds = {9866}},
        {id = 9841, cost = 22000, requiredIds = {9840}},
        {id = 9876, cost = 22000, requiredIds = {9875}}
    },
    [60] = {
        {id = 17402, cost = 24000, requiredIds = {17401}},
        {id = 24977, cost = 24000, requiredIds = {24976}, requiredTalentId = 5570},
        {id = 9885, cost = 24000, requiredIds = {9884}},
        {id = 9913, cost = 24000, requiredIds = {6783}},
        {id = 20748, cost = 24000, requiredIds = {20747}},
        {id = 9858, cost = 24000, requiredIds = {9857}},
        {id = 1237951, cost = 24000, requiredIds = {1237950}},
        {id = 9896, cost = 24000, requiredIds = {9894}},
        {id = 9863, cost = 24000, requiredIds = {9862}},
        {id = 1238215, cost = 24000, requiredIds = {1238214}, requiredTalentId = 408120}
    }
}

ns.training.HUNTER = {
    [1] = {{id = 1494, cost = 10}},
    [4] = {{id = 13163, cost = 100}, {id = 1978, cost = 100}},
    [6] = {{id = 3044, cost = 100}, {id = 1130, cost = 100}},
    [8] = {{id = 5116, cost = 200}, {id = 3127, cost = 200}, {id = 14260, cost = 200}},
    [10] = {
        {id = 13165, cost = 400},
        {id = 13549, cost = 400, requiredIds = {1978}},
        {id = 19883, cost = 400},
        {id = 4187, cost = 10},
        {id = 24545, cost = 10}
    },
    [12] = {
        {id = 14281, cost = 600, requiredIds = {3044}},
        {id = 20736, cost = 600},
        {id = 136, cost = 600, requiredIds = {1515}},
        {id = 2974, cost = 600},
        {id = 4188, cost = 120},
        {id = 24549, cost = 120}
    },
    [14] = {{id = 6197, cost = 1200}, {id = 1002, cost = 1200}, {id = 1513, cost = 1200}},
    [16] = {{id = 13795, cost = 1500}, {id = 1495, cost = 1500}, {id = 14261, cost = 1500, requiredIds = {14260}}},
    [18] = {
        {id = 14318, cost = 1600, requiredIds = {13165}},
        {id = 2643, cost = 1600},
        {id = 13550, cost = 1600, requiredIds = {13549}},
        {id = 19884, cost = 1600},
        {id = 4189, cost = 400},
        {id = 24550, cost = 400}
    },
    [20] = {
        {id = 19434, cost = 2100},
        {id = 14282, cost = 2100, requiredIds = {14281}},
        {id = 5118, cost = 2100},
        {id = 781, cost = 2100},
        {id = 14274, cost = 2100, requiredIds = {20736}},
        {id = 674, cost = 2100},
        {id = 1499, cost = 2100},
        {id = 3111, cost = 2100, requiredIds = {136}},
        {id = 24493, cost = 440},
        {id = 23992, cost = 440},
        {id = 24446, cost = 440},
        {id = 14917, cost = 440},
        {id = 24492, cost = 440},
        {id = 24488, cost = 440}
    },
    [22] = {{id = 14323, cost = 7000, requiredIds = {1130}}, {id = 3043, cost = 7000}},
    [24] = {
        {id = 1462, cost = 7200},
        {id = 14262, cost = 7200, requiredIds = {14261}},
        {id = 19885, cost = 7200},
        {id = 4190, cost = 1400},
        {id = 24551, cost = 1400}
    },
    [26] = {
        {id = 14302, cost = 7400, requiredIds = {13795}},
        {id = 3045, cost = 7400},
        {id = 13551, cost = 7400, requiredIds = {13550}},
        {id = 19880, cost = 7400}
    },
    [28] = {
        {id = 20900, cost = 7500, requiredIds = {19434}},
        {id = 14283, cost = 7500, requiredIds = {14282}},
        {id = 14319, cost = 7500, requiredIds = {14318}},
        {id = 13809, cost = 7500},
        {id = 3661, cost = 7500, requiredIds = {3111}}
    },
    [30] = {
        {id = 13161, cost = 7600},
        {id = 1242634, cost = 7600, requiredIds = {19306}, requiredTalentId = 19306},
        {id = 15629, cost = 7600, requiredIds = {14274}},
        {id = 5384, cost = 7600},
        {id = 14269, cost = 7600, requiredIds = {1495}},
        {id = 14326, cost = 7600, requiredIds = {1513}},
        {id = 24497, cost = 1600},
        {id = 24439, cost = 1600},
        {id = 24447, cost = 1600},
        {id = 4191, cost = 1600},
        {id = 14918, cost = 1600},
        {id = 24552, cost = 1600},
        {id = 24502, cost = 1600},
        {id = 24505, cost = 1600}
    },
    [32] = {
        {id = 1543, cost = 10000},
        {id = 14263, cost = 10000, requiredIds = {14262}},
        {id = 19878, cost = 10000},
        {id = 1299348, cost = 10000, requiredIds = {1299346}, requiredTalentId = 1299346}
    },
    [34] = {
        {id = 14272, cost = 11000, requiredIds = {781}},
        {id = 13813, cost = 11000},
        {id = 13552, cost = 11000, requiredIds = {13551}}
    },
    [36] = {
        {id = 20901, cost = 13000, requiredIds = {20900}},
        {id = 14284, cost = 13000, requiredIds = {14283}},
        {id = 14303, cost = 13000, requiredIds = {14302}},
        {id = 3662, cost = 13000, requiredIds = {3661}},
        {id = 1293525, cost = 13000, requiredIds = {1293241}, requiredTalentId = 1293241},
        {id = 3034, cost = 13000},
        {id = 4192, cost = 2800},
        {id = 24553, cost = 2800}
    },
    [38] = {{id = 14320, cost = 15000, requiredIds = {14319}}, {id = 14267, cost = 15000, requiredIds = {2974}}},
    [40] = {
        {id = 1299445, cost = 16000, requiredIds = {13161}},
        {id = 13159, cost = 16000},
        {id = 15630, cost = 16000, requiredIds = {15629}},
        {id = 14310, cost = 16000, requiredIds = {1499}},
        {id = 14324, cost = 16000, requiredIds = {14323}},
        {id = 8737, cost = 16000},
        {id = 14264, cost = 16000, requiredIds = {14263}},
        {id = 19882, cost = 16000},
        {id = 19506, cost = 16000, requiredIds = {1299348}, requiredTalentId = 1299346},
        {id = 1510, cost = 16000},
        {id = 24500, cost = 3600},
        {id = 24444, cost = 3600},
        {id = 24448, cost = 3600},
        {id = 14919, cost = 3600},
        {id = 24503, cost = 3600},
        {id = 24506, cost = 3600}
    },
    [42] = {
        {id = 20909, cost = 22000, requiredIds = {1242634}, requiredTalentId = 19306},
        {id = 13553, cost = 24000, requiredIds = {13552}},
        {id = 4193, cost = 4800},
        {id = 24554, cost = 4800}
    },
    [44] = {
        {id = 20902, cost = 23000, requiredIds = {20901}},
        {id = 14285, cost = 26000, requiredIds = {14284}},
        {id = 14316, cost = 26000, requiredIds = {13813}},
        {id = 13542, cost = 26000, requiredIds = {3662}},
        {id = 14270, cost = 26000, requiredIds = {14269}}
    },
    [46] = {
        {id = 20043, cost = 28000},
        {id = 14304, cost = 28000, requiredIds = {14303}},
        {id = 14327, cost = 28000, requiredIds = {14326}},
        {id = 14279, cost = 28000, requiredIds = {3034}}
    },
    [48] = {
        {id = 14321, cost = 32000, requiredIds = {14320}},
        {id = 14273, cost = 32000, requiredIds = {14272}},
        {id = 14265, cost = 32000, requiredIds = {14264}},
        {id = 1310785, cost = 14000, requiredIds = {1310687}, requiredTalentId = 1310687},
        {id = 1293526, cost = 29000, requiredIds = {1293525}, requiredTalentId = 1293241},
        {id = 4194, cost = 6400},
        {id = 24555, cost = 6400}
    },
    [50] = {
        {id = 1299446, cost = 36000, requiredIds = {1299445}},
        {id = 15631, cost = 36000, requiredIds = {15630}},
        {id = 13554, cost = 36000, requiredIds = {13553}},
        {id = 19879, cost = 36000},
        {id = 20905, cost = 30000, requiredIds = {19506}, requiredTalentId = 1299346},
        {id = 14294, cost = 36000, requiredIds = {1510}},
        {id = 24501, cost = 7200},
        {id = 24445, cost = 7200},
        {id = 24449, cost = 7200},
        {id = 14920, cost = 7200},
        {id = 24504, cost = 7200},
        {id = 24507, cost = 7200}
    },
    [52] = {
        {id = 20903, cost = 20000, requiredIds = {20902}},
        {id = 14286, cost = 40000, requiredIds = {14285}},
        {id = 13543, cost = 40000, requiredIds = {13542}}
    },
    [54] = {
        {id = 20910, cost = 37000, requiredIds = {20909}, requiredTalentId = 19306},
        {id = 14317, cost = 42000, requiredIds = {14316}},
        {id = 5041, cost = 8400},
        {id = 24629, cost = 8400}
    },
    [56] = {
        {id = 20190, cost = 46000, requiredIds = {20043}},
        {id = 14305, cost = 46000, requiredIds = {14304}},
        {id = 14266, cost = 46000, requiredIds = {14265}},
        {id = 14280, cost = 46000, requiredIds = {14279}}
    },
    [58] = {
        {id = 14322, cost = 48000, requiredIds = {14321}},
        {id = 14325, cost = 48000, requiredIds = {14324}},
        {id = 14271, cost = 48000, requiredIds = {14270}},
        {id = 13555, cost = 48000, requiredIds = {13554}},
        {id = 1310786, cost = 24000, requiredIds = {1310785}, requiredTalentId = 1310687},
        {id = 14295, cost = 48000, requiredIds = {14294}}
    },
    [60] = {
        {id = 20904, cost = 25000, requiredIds = {20903}},
        {id = 14287, cost = 50000, requiredIds = {14286}},
        {id = 1299447, cost = 48000, requiredIds = {1299446}},
        {id = 15632, cost = 50000, requiredIds = {15631}},
        {id = 14311, cost = 50000, requiredIds = {14310}},
        {id = 13544, cost = 50000, requiredIds = {13543}},
        {id = 1293527, cost = 42000, requiredIds = {1293526}, requiredTalentId = 1293241},
        {id = 20906, cost = 42000, requiredIds = {20905}, requiredTalentId = 1299346},
        {id = 14268, cost = 50000, requiredIds = {14267}},
        {id = 5042, cost = 10000},
        {id = 14921, cost = 10000},
        {id = 24630, cost = 10000}
    }
}

ns.training.MAGE = {
    [1] = {{id = 1459, cost = 10}},
    [4] = {{id = 5504, cost = 100}, {id = 116, cost = 100}},
    [6] = {
        {id = 1296017, cost = 100},
        {id = 587, cost = 100},
        {id = 2136, cost = 100},
        {id = 143, cost = 100, requiredIds = {133}}
    },
    [8] = {{id = 5143, cost = 200}, {id = 205, cost = 200, requiredIds = {116}}, {id = 118, cost = 200}},
    [10] = {
        {id = 5505, cost = 400, requiredIds = {5504}},
        {id = 7300, cost = 400, requiredIds = {168}},
        {id = 122, cost = 400}
    },
    [12] = {
        {id = 597, cost = 600, requiredIds = {587}},
        {id = 604, cost = 600},
        {id = 145, cost = 600, requiredIds = {143}},
        {id = 130, cost = 600}
    },
    [14] = {
        {id = 1449, cost = 900},
        {id = 1460, cost = 900, requiredIds = {1459}},
        {id = 2137, cost = 900, requiredIds = {2136}},
        {id = 837, cost = 900, requiredIds = {205}}
    },
    [16] = {{id = 5144, cost = 1500, requiredIds = {5143}}, {id = 2120, cost = 1500}},
    [18] = {{id = 1008, cost = 1800}, {id = 3140, cost = 1800, requiredIds = {145}}, {id = 475, cost = 1800}},
    [20] = {
        {id = 1953, cost = 2000},
        {id = 10, cost = 2000},
        {id = 5506, cost = 2000, requiredIds = {5505}},
        {id = 12051, cost = 2000},
        {id = 543, cost = 2000},
        {id = 7301, cost = 2000, requiredIds = {7300}},
        {id = 7322, cost = 2000, requiredIds = {837}},
        {id = 1463, cost = 2000},
        {id = 12824, cost = 2000, requiredIds = {118}},
        {id = 3561, cost = 2000, faction = "Alliance"},
        {id = 3562, cost = 2000, faction = "Alliance"},
        {id = 3563, cost = 2000, faction = "Horde"},
        {id = 3567, cost = 2000, faction = "Horde"}
    },
    [22] = {
        {id = 8437, cost = 3000, requiredIds = {1449}},
        {id = 990, cost = 3000, requiredIds = {597}},
        {id = 2138, cost = 3000, requiredIds = {2137}},
        {id = 6143, cost = 3000},
        {id = 2948, cost = 3000}
    },
    [24] = {
        {id = 5145, cost = 4000, requiredIds = {5144}},
        {id = 2139, cost = 4000},
        {id = 8450, cost = 4000, requiredIds = {604}},
        {id = 8400, cost = 4000, requiredIds = {3140}},
        {id = 2121, cost = 4000, requiredIds = {2120}},
        {id = 12505, cost = 200, requiredIds = {11366}, requiredTalentId = 11366}
    },
    [26] = {
        {id = 120, cost = 5000},
        {id = 865, cost = 5000, requiredIds = {122}},
        {id = 8406, cost = 5000, requiredIds = {7322}}
    },
    [28] = {
        {id = 1461, cost = 7000, requiredIds = {1460}},
        {id = 6141, cost = 7000, requiredIds = {10}},
        {id = 759, cost = 7000},
        {id = 400640, cost = 3000, requiredIds = {1312002}, requiredTalentId = 1312002},
        {id = 8494, cost = 7000, requiredIds = {1463}},
        {id = 8444, cost = 7000, requiredIds = {2948}}
    },
    [30] = {
        {id = 8455, cost = 8000, requiredIds = {1008}},
        {id = 1239696, cost = 8000, requiredIds = {400574}, requiredTalentId = 400574},
        {id = 8438, cost = 8000, requiredIds = {8437}},
        {id = 6127, cost = 8000, requiredIds = {5506}},
        {id = 8412, cost = 8000, requiredIds = {2138}},
        {id = 8457, cost = 8000, requiredIds = {543}},
        {id = 8401, cost = 8000, requiredIds = {8400}},
        {id = 7302, cost = 8000},
        {id = 12522, cost = 400, requiredIds = {12505}, requiredTalentId = 11366},
        {id = 3565, cost = 8000, faction = "Alliance"},
        {id = 3566, cost = 8000, faction = "Horde"}
    },
    [32] = {
        {id = 8416, cost = 10000, requiredIds = {5145}},
        {id = 6129, cost = 10000, requiredIds = {990}},
        {id = 8422, cost = 10000, requiredIds = {2121}},
        {id = 8461, cost = 10000, requiredIds = {6143}},
        {id = 8407, cost = 10000, requiredIds = {8406}}
    },
    [34] = {
        {id = 8492, cost = 12000, requiredIds = {120}},
        {id = 1240044, cost = 14500, requiredIds = {400640}, requiredTalentId = 1312002},
        {id = 6117, cost = 12000},
        {id = 8445, cost = 12000, requiredIds = {8444}}
    },
    [36] = {
        {id = 13018, cost = 650, requiredIds = {11113}, requiredTalentId = 11113},
        {id = 8427, cost = 13000, requiredIds = {6141}},
        {id = 8451, cost = 13000, requiredIds = {8450}},
        {id = 8402, cost = 13000, requiredIds = {8401}},
        {id = 8495, cost = 13000, requiredIds = {8494}},
        {id = 12523, cost = 650, requiredIds = {12522}, requiredTalentId = 11366}
    },
    [38] = {
        {id = 8439, cost = 14000, requiredIds = {8438}},
        {id = 3552, cost = 14000, requiredIds = {759}},
        {id = 8413, cost = 14000, requiredIds = {8412}},
        {id = 8408, cost = 14000, requiredIds = {8407}}
    },
    [40] = {
        {id = 1239697, cost = 15000, requiredIds = {1239696}, requiredTalentId = 400574},
        {id = 8417, cost = 15000, requiredIds = {8416}},
        {id = 10138, cost = 15000, requiredIds = {6127}},
        {id = 8458, cost = 15000, requiredIds = {8457}},
        {id = 8423, cost = 15000, requiredIds = {8422}},
        {id = 6131, cost = 15000, requiredIds = {865}},
        {id = 401502, cost = 15000},
        {id = 7320, cost = 15000, requiredIds = {7302}},
        {id = 12825, cost = 15000, requiredIds = {12824}},
        {id = 8446, cost = 15000, requiredIds = {8445}},
        {id = 10059, cost = 15000, faction = "Alliance"},
        {id = 11416, cost = 15000, faction = "Alliance"},
        {id = 11417, cost = 15000, faction = "Horde"},
        {id = 11418, cost = 15000, faction = "Horde"}
    },
    [42] = {
        {id = 10169, cost = 18000, requiredIds = {8455}},
        {id = 10156, cost = 18000, requiredIds = {1461}},
        {id = 10159, cost = 18000, requiredIds = {8492}},
        {id = 10144, cost = 18000, requiredIds = {6129}},
        {id = 10148, cost = 18000, requiredIds = {8402}},
        {id = 8462, cost = 18000, requiredIds = {8461}},
        {id = 1240045, cost = 18000, requiredIds = {1240044}, requiredTalentId = 1312002},
        {id = 12524, cost = 900, requiredIds = {12523}, requiredTalentId = 11366}
    },
    [44] = {
        {id = 13019, cost = 1150, requiredIds = {13018}, requiredTalentId = 11113},
        {id = 10185, cost = 23000, requiredIds = {8427}},
        {id = 10179, cost = 23000, requiredIds = {8408}},
        {id = 10191, cost = 23000, requiredIds = {8495}}
    },
    [46] = {
        {id = 10201, cost = 26000, requiredIds = {8439}},
        {id = 10197, cost = 26000, requiredIds = {8413}},
        {id = 13031, cost = 1300, requiredIds = {11426}, requiredTalentId = 11426},
        {id = 22782, cost = 28000, requiredIds = {6117}},
        {id = 10205, cost = 26000, requiredIds = {8446}}
    },
    [48] = {
        {id = 10211, cost = 28000, requiredIds = {8417}},
        {id = 10053, cost = 28000, requiredIds = {3552}},
        {id = 10173, cost = 28000, requiredIds = {8451}},
        {id = 10149, cost = 28000, requiredIds = {10148}},
        {id = 10215, cost = 28000, requiredIds = {8423}},
        {id = 1240046, cost = 32000, requiredIds = {1240045}, requiredTalentId = 1312002},
        {id = 12525, cost = 1400, requiredIds = {12524}, requiredTalentId = 11366}
    },
    [50] = {
        {id = 1239699, cost = 32000, requiredIds = {1239697}, requiredTalentId = 400574},
        {id = 10160, cost = 32000, requiredIds = {10159}},
        {id = 10139, cost = 32000, requiredIds = {10138}},
        {id = 10223, cost = 32000, requiredIds = {8458}},
        {id = 10180, cost = 32000, requiredIds = {10179}},
        {id = 1237312, cost = 32000, requiredIds = {401502}},
        {id = 10219, cost = 32000, requiredIds = {7320}},
        {id = 11419, cost = 32000, faction = "Alliance"},
        {id = 11420, cost = 32000, faction = "Horde"}
    },
    [52] = {
        {id = 13020, cost = 1750, requiredIds = {13019}, requiredTalentId = 11113},
        {id = 10186, cost = 35000, requiredIds = {10185}},
        {id = 10145, cost = 35000, requiredIds = {10144}},
        {id = 10177, cost = 35000, requiredIds = {8462}},
        {id = 13032, cost = 1750, requiredIds = {13031}, requiredTalentId = 11426},
        {id = 10192, cost = 35000, requiredIds = {10191}},
        {id = 10206, cost = 35000, requiredIds = {10205}}
    },
    [54] = {
        {id = 10170, cost = 36000, requiredIds = {10169}},
        {id = 10202, cost = 36000, requiredIds = {10201}},
        {id = 10199, cost = 36000, requiredIds = {10197}},
        {id = 10150, cost = 36000, requiredIds = {10149}},
        {id = 10230, cost = 36000, requiredIds = {6131}},
        {id = 12526, cost = 1800, requiredIds = {12525}, requiredTalentId = 11366}
    },
    [56] = {
        {id = 10157, cost = 38000, requiredIds = {10156}},
        {id = 10212, cost = 38000, requiredIds = {10211}},
        {id = 10216, cost = 38000, requiredIds = {10215}},
        {id = 10181, cost = 38000, requiredIds = {10180}},
        {id = 1240047, cost = 40000, requiredIds = {1240046}, requiredTalentId = 1312002}
    },
    [58] = {
        {id = 10161, cost = 40000, requiredIds = {10160}},
        {id = 10054, cost = 40000, requiredIds = {10053}},
        {id = 13033, cost = 2000, requiredIds = {13032}, requiredTalentId = 11426},
        {id = 22783, cost = 40000, requiredIds = {22782}},
        {id = 10207, cost = 40000, requiredIds = {10206}}
    },
    [60] = {
        {id = 1239700, cost = 42000, requiredIds = {1239699}, requiredTalentId = 400574},
        {id = 13021, cost = 2100, requiredIds = {13020}, requiredTalentId = 11113},
        {id = 10187, cost = 42000, requiredIds = {10186}},
        {id = 10174, cost = 42000, requiredIds = {10173}},
        {id = 10225, cost = 42000, requiredIds = {10223}},
        {id = 10151, cost = 42000, requiredIds = {10150}},
        {id = 1237313, cost = 42000, requiredIds = {1237312}},
        {id = 10220, cost = 42000, requiredIds = {10219}},
        {id = 10193, cost = 42000, requiredIds = {10192}},
        {id = 12826, cost = 42000, requiredIds = {12825}},
        {id = 18809, cost = 2100, requiredIds = {12526}, requiredTalentId = 11366}
    }
}

ns.training.PALADIN = {
    [1] = {{id = 465, cost = 10}},
    [4] = {{id = 19740, cost = 100}, {id = 20271, cost = 100}},
    [6] = {
        {id = 498, cost = 100},
        {id = 639, cost = 100, requiredIds = {635}},
        {id = 679, cost = 100},
        {id = 21082, cost = 100}
    },
    [8] = {{id = 853, cost = 100}, {id = 3127, cost = 100}, {id = 1152, cost = 100}},
    [10] = {
        {id = 1022, cost = 300},
        {id = 10290, cost = 300, requiredIds = {465}},
        {id = 633, cost = 300},
        {id = 1311649, cost = 300},
        {id = 20287, cost = 300, requiredIds = {20154}}
    },
    [12] = {
        {id = 19834, cost = 1000, requiredIds = {19740}},
        {id = 678, cost = 1000, requiredIds = {679}},
        {id = 20162, cost = 1000, requiredIds = {21082}}
    },
    [14] = {{id = 19742, cost = 2000}, {id = 647, cost = 2000, requiredIds = {639}}},
    [16] = {{id = 7294, cost = 3000}, {id = 25780, cost = 3000}},
    [18] = {
        {id = 1044, cost = 3500},
        {id = 5573, cost = 3500, requiredIds = {498}},
        {id = 1311656, cost = 3500, requiredIds = {1311649}},
        {id = 20288, cost = 3500, requiredIds = {20287}}
    },
    [20] = {
        {id = 20217, cost = 4000},
        {id = 26573, cost = 4000},
        {id = 643, cost = 4000, requiredIds = {10290}},
        {id = 879, cost = 4000},
        {id = 19750, cost = 4000},
        {id = 1866, cost = 4000, requiredIds = {678}}
    },
    [22] = {
        {id = 19835, cost = 4000, requiredIds = {19834}},
        {id = 19746, cost = 4000},
        {id = 1026, cost = 4000, requiredIds = {647}},
        {id = 20164, cost = 4000},
        {id = 20305, cost = 4000, requiredIds = {20162}}
    },
    [24] = {
        {id = 5599, cost = 5000, requiredIds = {1022}},
        {id = 19850, cost = 5000, requiredIds = {19742}},
        {id = 5588, cost = 5000, requiredIds = {853}},
        {id = 10322, cost = 5000, requiredIds = {7328}},
        {id = 2878, cost = 5000}
    },
    [25] = {{id = 20163, cost = 6000, requiredIds = {1311656}}},
    [26] = {
        {id = 1038, cost = 6000},
        {id = 19939, cost = 6000, requiredIds = {19750}},
        {id = 10298, cost = 6000, requiredIds = {7294}},
        {id = 20289, cost = 6000, requiredIds = {20288}}
    },
    [28] = {
        {id = 5614, cost = 9000, requiredIds = {879}},
        {id = 680, cost = 9000, requiredIds = {1866}},
        {id = 19876, cost = 9000}
    },
    [30] = {
        {id = 20116, cost = 11000, requiredIds = {26573}},
        {id = 10291, cost = 11000, requiredIds = {643}},
        {id = 19752, cost = 11000},
        {id = 1042, cost = 11000, requiredIds = {1026}},
        {id = 2800, cost = 11000, requiredIds = {633}},
        {id = 20915, cost = 550, requiredIds = {20375}, requiredTalentId = 20375},
        {id = 20165, cost = 11000}
    },
    [32] = {
        {id = 19836, cost = 12000, requiredIds = {19835}},
        {id = 19888, cost = 12000},
        {id = 20306, cost = 12000, requiredIds = {20305}}
    },
    [34] = {
        {id = 19852, cost = 13000, requiredIds = {19850}},
        {id = 642, cost = 13000},
        {id = 19940, cost = 13000, requiredIds = {19939}},
        {id = 20419, cost = 13000, requiredIds = {20163}},
        {id = 20290, cost = 13000, requiredIds = {20289}}
    },
    [36] = {
        {id = 5615, cost = 14000, requiredIds = {5614}},
        {id = 19891, cost = 14000},
        {id = 2495, cost = 14000, requiredIds = {680}},
        {id = 10324, cost = 14000, requiredIds = {10322}},
        {id = 10299, cost = 14000, requiredIds = {10298}}
    },
    [38] = {
        {id = 10278, cost = 16000, requiredIds = {5599}},
        {id = 3472, cost = 16000, requiredIds = {1042}},
        {id = 20166, cost = 16000},
        {id = 5627, cost = 16000, requiredIds = {2878}}
    },
    [40] = {
        {id = 19977, cost = 20000},
        {id = 20922, cost = 20000, requiredIds = {20116}},
        {id = 1032, cost = 20000, requiredIds = {10291}},
        {id = 5589, cost = 20000, requiredIds = {5588}},
        {id = 20473, cost = 1000, requiredIds = {1311606}, requiredTalentId = 1311606},
        {id = 750, cost = 20000},
        {id = 20918, cost = 1000, requiredIds = {20915}, requiredTalentId = 20375},
        {id = 20347, cost = 20000, requiredIds = {20165}},
        {id = 19895, cost = 20000, requiredIds = {19876}}
    },
    [42] = {
        {id = 19837, cost = 21000, requiredIds = {19836}},
        {id = 4987, cost = 21000},
        {id = 19941, cost = 21000, requiredIds = {19940}},
        {id = 20421, cost = 21000, requiredIds = {20419}},
        {id = 20291, cost = 21000, requiredIds = {20290}},
        {id = 20307, cost = 21000, requiredIds = {20306}}
    },
    [44] = {
        {id = 19853, cost = 22000, requiredIds = {19852}},
        {id = 10312, cost = 22000, requiredIds = {5615}},
        {id = 19897, cost = 22000, requiredIds = {19888}},
        {id = 24275, cost = 22000},
        {id = 5569, cost = 22000, requiredIds = {2495}}
    },
    [46] = {
        {id = 6940, cost = 24000},
        {id = 10328, cost = 24000, requiredIds = {3472}},
        {id = 10300, cost = 24000, requiredIds = {10299}}
    },
    [48] = {
        {id = 19899, cost = 26000, requiredIds = {19891}},
        {id = 20929, cost = 1300, requiredIds = {20473}, requiredTalentId = 1311606},
        {id = 20772, cost = 26000, requiredIds = {10324}},
        {id = 20356, cost = 26000, requiredIds = {20166}}
    },
    [50] = {
        {id = 19978, cost = 28000, requiredIds = {19977}},
        {id = 20923, cost = 28000, requiredIds = {20922}},
        {id = 10292, cost = 28000, requiredIds = {1032}},
        {id = 1020, cost = 28000, requiredIds = {642}},
        {id = 19942, cost = 28000, requiredIds = {19941}},
        {id = 20927, cost = 1400, requiredIds = {20925}, requiredTalentId = 20925},
        {id = 2812, cost = 28000},
        {id = 10310, cost = 28000, requiredIds = {2800}},
        {id = 1311590, cost = 1400, requiredIds = {1310911}, requiredTalentId = 1310911},
        {id = 20919, cost = 1400, requiredIds = {20918}, requiredTalentId = 20375},
        {id = 20422, cost = 28000, requiredIds = {20421}},
        {id = 20348, cost = 28000, requiredIds = {20347}},
        {id = 20292, cost = 28000, requiredIds = {20291}}
    },
    [52] = {
        {id = 19838, cost = 34000, requiredIds = {19837}},
        {id = 10313, cost = 34000, requiredIds = {10312}},
        {id = 25782, cost = 46000, requiredIds = {19838}},
        {id = 24274, cost = 34000, requiredIds = {24275}},
        {id = 10332, cost = 34000, requiredIds = {5569}},
        {id = 20308, cost = 34000, requiredIds = {20307}},
        {id = 19896, cost = 34000, requiredIds = {19895}},
        {id = 10326, cost = 34000, requiredIds = {5627}}
    },
    [54] = {
        {id = 20729, cost = 40000, requiredIds = {6940}},
        {id = 19854, cost = 40000, requiredIds = {19853}},
        {id = 25894, cost = 46000, requiredIds = {19854}},
        {id = 10308, cost = 40000, requiredIds = {5589}},
        {id = 10329, cost = 40000, requiredIds = {10328}}
    },
    [56] = {
        {id = 19898, cost = 42000, requiredIds = {19897}},
        {id = 20930, cost = 2100, requiredIds = {20929}, requiredTalentId = 1311606},
        {id = 10301, cost = 42000, requiredIds = {10300}}
    },
    [58] = {
        {id = 19943, cost = 44000, requiredIds = {19942}},
        {id = 20423, cost = 44000, requiredIds = {20422}},
        {id = 20293, cost = 44000, requiredIds = {20292}},
        {id = 20357, cost = 44000, requiredIds = {20356}}
    },
    [60] = {
        {id = 19979, cost = 46000, requiredIds = {19978}},
        {id = 20924, cost = 46000, requiredIds = {20923}},
        {id = 10293, cost = 46000, requiredIds = {10292}},
        {id = 10314, cost = 46000, requiredIds = {10313}},
        {id = 19900, cost = 46000, requiredIds = {19899}},
        {id = 25898, cost = 46000, requiredIds = {20217}},
        {id = 25890, cost = 46000, requiredIds = {19979}},
        {id = 25916, cost = 46000, requiredIds = {19740}},
        {id = 25895, cost = 46000, requiredIds = {1038}},
        {id = 25918, cost = 46000, requiredIds = {19742}},
        {id = 24239, cost = 46000, requiredIds = {24274}},
        {id = 20928, cost = 2300, requiredIds = {20927}, requiredTalentId = 20925},
        {id = 10333, cost = 46000, requiredIds = {10332}},
        {id = 10318, cost = 46000, requiredIds = {2812}},
        {id = 1311595, cost = 2300, requiredIds = {1311590}, requiredTalentId = 1310911},
        {id = 20773, cost = 46000, requiredIds = {20772}},
        {id = 20920, cost = 2300, requiredIds = {20919}, requiredTalentId = 20375},
        {id = 20349, cost = 46000, requiredIds = {20348}}
    }
}

ns.training.PRIEST = {
    [1] = {{id = 1243, cost = 10}},
    [4] = {{id = 2052, cost = 100, requiredIds = {2050}}, {id = 589, cost = 100}},
    [6] = {{id = 17, cost = 100}, {id = 591, cost = 100, requiredIds = {585}}},
    [8] = {{id = 586, cost = 200}, {id = 139, cost = 200}},
    [10] = {
        {id = 2053, cost = 300, requiredIds = {2052}},
        {id = 8092, cost = 300},
        {id = 2006, cost = 300},
        {id = 594, cost = 300, requiredIds = {589}}
    },
    [12] = {
        {id = 588, cost = 800},
        {id = 1244, cost = 800, requiredIds = {1243}},
        {id = 592, cost = 800, requiredIds = {17}}
    },
    [14] = {
        {id = 528, cost = 1200},
        {id = 8122, cost = 1200},
        {id = 6074, cost = 1200, requiredIds = {139}},
        {id = 598, cost = 1200, requiredIds = {591}}
    },
    [16] = {{id = 2054, cost = 1600}, {id = 8102, cost = 1600, requiredIds = {8092}}},
    [18] = {
        {id = 527, cost = 2000},
        {id = 1277371, cost = 100, requiredIds = {1277370}, race = 1},
        {id = 600, cost = 2000, requiredIds = {592}},
        {id = 970, cost = 2000, requiredIds = {594}},
        {id = 19236, cost = 100, requiredIds = {13908}, race = 3},
        {id = 19296, cost = 100, requiredIds = {10797}, race = 4}
    },
    [20] = {
        {id = 2944, cost = 300},
        {id = 9578, cost = 3000, requiredIds = {586}},
        {id = 6346, cost = 300},
        {id = 2061, cost = 3000},
        {id = 14914, cost = 3000},
        {id = 7128, cost = 3000, requiredIds = {588}},
        {id = 453, cost = 3000},
        {id = 6075, cost = 3000, requiredIds = {6074}},
        {id = 9484, cost = 3000},
        {id = 19261, cost = 150, requiredIds = {2652}, race = 5},
        {id = 19281, cost = 150, requiredIds = {9035}, race = 8}
    },
    [22] = {
        {id = 2055, cost = 4000, requiredIds = {2054}},
        {id = 8103, cost = 4000, requiredIds = {8102}},
        {id = 2096, cost = 4000},
        {id = 2010, cost = 4000, requiredIds = {2006}},
        {id = 984, cost = 4000, requiredIds = {598}}
    },
    [24] = {
        {id = 15262, cost = 5000, requiredIds = {14914}},
        {id = 8129, cost = 5000},
        {id = 1245, cost = 5000, requiredIds = {1244}},
        {id = 3747, cost = 5000, requiredIds = {600}}
    },
    [26] = {
        {id = 1277372, cost = 300, requiredIds = {1277371}, race = 1},
        {id = 9472, cost = 6000, requiredIds = {2061}},
        {id = 6076, cost = 6000, requiredIds = {6075}},
        {id = 992, cost = 6000, requiredIds = {970}},
        {id = 19238, cost = 300, requiredIds = {19236}, race = 3},
        {id = 19299, cost = 300, requiredIds = {19296}, race = 4}
    },
    [28] = {
        {id = 19276, cost = 400, requiredIds = {2944}},
        {id = 6063, cost = 8000, requiredIds = {2055}},
        {id = 15430, cost = 400, requiredIds = {15237}, requiredTalentId = 15237},
        {id = 8104, cost = 8000, requiredIds = {8103}},
        {id = 17311, cost = 400, requiredIds = {15407}, requiredTalentId = 15407},
        {id = 8124, cost = 8000, requiredIds = {8122}},
        {id = 19308, cost = 400, requiredIds = {18137}, race = 8}
    },
    [30] = {
        {id = 14752, cost = 10000},
        {id = 9579, cost = 10000, requiredIds = {9578}},
        {id = 19271, cost = 500, requiredIds = {13896}, race = 1},
        {id = 15263, cost = 10000, requiredIds = {15262}},
        {id = 602, cost = 10000, requiredIds = {7128}},
        {id = 605, cost = 10000},
        {id = 6065, cost = 10000, requiredIds = {3747}},
        {id = 596, cost = 10000},
        {id = 976, cost = 10000},
        {id = 1004, cost = 10000, requiredIds = {984}},
        {id = 19262, cost = 500, requiredIds = {19261}, race = 5},
        {id = 19282, cost = 500, requiredIds = {19281}, race = 8},
        {id = 1277332, cost = 500, requiredIds = {1277331}, race = 3},
        {id = 1277634, cost = 500, requiredIds = {1277462}, race = 7},
        {id = 1277325, cost = 500, requiredIds = {1277324}, race = 5}
    },
    [32] = {
        {id = 552, cost = 11000},
        {id = 1240770, cost = 11000, requiredIds = {401937}, requiredTalentId = 401937},
        {id = 9473, cost = 11000, requiredIds = {9472}},
        {id = 8131, cost = 11000, requiredIds = {8129}},
        {id = 6077, cost = 11000, requiredIds = {6076}},
        {id = 1309595, cost = 11000}
    },
    [34] = {
        {id = 1277374, cost = 600, requiredIds = {1277372}, race = 1},
        {id = 6064, cost = 12000, requiredIds = {6063}},
        {id = 1706, cost = 12000},
        {id = 8105, cost = 12000, requiredIds = {8104}},
        {id = 10880, cost = 12000, requiredIds = {2010}},
        {id = 2767, cost = 12000, requiredIds = {992}},
        {id = 19240, cost = 600, requiredIds = {19238}, race = 3},
        {id = 19302, cost = 600, requiredIds = {19299}, race = 4}
    },
    [36] = {
        {id = 19277, cost = 700, requiredIds = {19276}},
        {id = 988, cost = 14000, requiredIds = {527}},
        {id = 15264, cost = 14000, requiredIds = {15263}},
        {id = 15431, cost = 700, requiredIds = {15430}, requiredTalentId = 15237},
        {id = 17312, cost = 700, requiredIds = {17311}, requiredTalentId = 15407},
        {id = 8192, cost = 14000, requiredIds = {453}},
        {id = 2791, cost = 14000, requiredIds = {1245}},
        {id = 6066, cost = 14000, requiredIds = {6065}},
        {id = 19309, cost = 700, requiredIds = {19308}, race = 8}
    },
    [38] = {
        {id = 1240771, cost = 16000, requiredIds = {1240770}, requiredTalentId = 401937},
        {id = 9474, cost = 16000, requiredIds = {9473}},
        {id = 6078, cost = 16000, requiredIds = {6077}},
        {id = 6060, cost = 16000, requiredIds = {1004}}
    },
    [40] = {
        {id = 14818, cost = 900, requiredIds = {14752}},
        {id = 9592, cost = 18000, requiredIds = {9579}},
        {id = 19273, cost = 900, requiredIds = {19271}, race = 1},
        {id = 2060, cost = 18000},
        {id = 1006, cost = 18000, requiredIds = {602}},
        {id = 10874, cost = 18000, requiredIds = {8131}},
        {id = 8106, cost = 18000, requiredIds = {8105}},
        {id = 1240720, cost = 16000, requiredIds = {402174}, requiredTalentId = 402174},
        {id = 996, cost = 18000, requiredIds = {596}},
        {id = 9485, cost = 18000, requiredIds = {9484}},
        {id = 1309633, cost = 18000, requiredIds = {1309595}},
        {id = 19264, cost = 900, requiredIds = {19262}, race = 5},
        {id = 19283, cost = 900, requiredIds = {19282}, race = 8},
        {id = 1277333, cost = 900, requiredIds = {1277332}, race = 3},
        {id = 1277638, cost = 900, requiredIds = {1277634}, race = 7},
        {id = 1277326, cost = 900, requiredIds = {1277325}, race = 5}
    },
    [42] = {
        {id = 1277376, cost = 1100, requiredIds = {1277374}, race = 1},
        {id = 15265, cost = 22000, requiredIds = {15264}},
        {id = 10898, cost = 22000, requiredIds = {6066}},
        {id = 10888, cost = 22000, requiredIds = {8124}},
        {id = 10957, cost = 22000, requiredIds = {976}},
        {id = 10892, cost = 22000, requiredIds = {2767}},
        {id = 19241, cost = 1100, requiredIds = {19240}, race = 3},
        {id = 19303, cost = 1100, requiredIds = {19302}, race = 4}
    },
    [44] = {
        {id = 1240772, cost = 24000, requiredIds = {1240771}, requiredTalentId = 401937},
        {id = 19278, cost = 1200, requiredIds = {19277}},
        {id = 10915, cost = 24000, requiredIds = {9474}},
        {id = 27799, cost = 1200, requiredIds = {15431}, requiredTalentId = 15237},
        {id = 10911, cost = 24000, requiredIds = {605}},
        {id = 17313, cost = 1200, requiredIds = {17312}, requiredTalentId = 15407},
        {id = 10909, cost = 24000, requiredIds = {2096}},
        {id = 10927, cost = 24000, requiredIds = {6078}},
        {id = 19310, cost = 1200, requiredIds = {19309}, race = 8}
    },
    [46] = {
        {id = 10963, cost = 26000, requiredIds = {2060}},
        {id = 10945, cost = 26000, requiredIds = {8106}},
        {id = 10881, cost = 26000, requiredIds = {10880}},
        {id = 10933, cost = 26000, requiredIds = {6060}}
    },
    [48] = {
        {id = 15266, cost = 28000, requiredIds = {15265}},
        {id = 10875, cost = 28000, requiredIds = {10874}},
        {id = 10937, cost = 28000, requiredIds = {2791}},
        {id = 10899, cost = 28000, requiredIds = {10898}},
        {id = 1309635, cost = 28000, requiredIds = {1309633}}
    },
    [50] = {
        {id = 1240773, cost = 30000, requiredIds = {1240772}, requiredTalentId = 401937},
        {id = 1277377, cost = 1500, requiredIds = {1277376}, race = 1},
        {id = 14819, cost = 1500, requiredIds = {14818}},
        {id = 10941, cost = 30000, requiredIds = {9592}},
        {id = 19274, cost = 1500, requiredIds = {19273}, race = 1},
        {id = 10916, cost = 30000, requiredIds = {10915}},
        {id = 10951, cost = 30000, requiredIds = {1006}},
        {id = 1240721, cost = 30000, requiredIds = {1240720}, requiredTalentId = 402174},
        {id = 10960, cost = 30000, requiredIds = {996}},
        {id = 1240826, cost = 30000, requiredIds = {401859}, requiredTalentId = 401859},
        {id = 10928, cost = 30000, requiredIds = {10927}},
        {id = 10893, cost = 30000, requiredIds = {10892}},
        {id = 19242, cost = 1500, requiredIds = {19241}, race = 3},
        {id = 19265, cost = 1500, requiredIds = {19264}, race = 5},
        {id = 19284, cost = 1500, requiredIds = {19283}, race = 8},
        {id = 19304, cost = 1500, requiredIds = {19303}, race = 4},
        {id = 27870, cost = 1200},
        {id = 1277334, cost = 1500, requiredIds = {1277333}, race = 3},
        {id = 1277639, cost = 1500, requiredIds = {1277638}, race = 7},
        {id = 1277327, cost = 1500, requiredIds = {1277326}, race = 5}
    },
    [52] = {
        {id = 19279, cost = 1900, requiredIds = {19278}},
        {id = 10964, cost = 38000, requiredIds = {10963}},
        {id = 27800, cost = 1900, requiredIds = {27799}, requiredTalentId = 15237},
        {id = 10946, cost = 38000, requiredIds = {10945}},
        {id = 17314, cost = 1900, requiredIds = {17313}, requiredTalentId = 15407},
        {id = 10953, cost = 38000, requiredIds = {8192}},
        {id = 19311, cost = 1900, requiredIds = {19310}, race = 8}
    },
    [54] = {
        {id = 15267, cost = 40000, requiredIds = {15266}},
        {id = 10900, cost = 40000, requiredIds = {10899}},
        {id = 10934, cost = 40000, requiredIds = {10933}}
    },
    [56] = {
        {id = 1240774, cost = 42000, requiredIds = {1240773}, requiredTalentId = 401937},
        {id = 10917, cost = 42000, requiredIds = {10916}},
        {id = 10876, cost = 42000, requiredIds = {10875}},
        {id = 10890, cost = 42000, requiredIds = {10888}},
        {id = 10929, cost = 42000, requiredIds = {10928}},
        {id = 10958, cost = 42000, requiredIds = {10957}},
        {id = 1309636, cost = 42000, requiredIds = {1309635}}
    },
    [58] = {
        {id = 1277378, cost = 2200, requiredIds = {1277377}, race = 1},
        {id = 10965, cost = 44000, requiredIds = {10964}},
        {id = 10947, cost = 44000, requiredIds = {10946}},
        {id = 10912, cost = 44000, requiredIds = {10911}},
        {id = 20770, cost = 44000, requiredIds = {10881}},
        {id = 10894, cost = 44000, requiredIds = {10893}},
        {id = 19243, cost = 2200, requiredIds = {19242}, race = 3},
        {id = 19305, cost = 2200, requiredIds = {19304}, race = 4}
    },
    [60] = {
        {id = 19280, cost = 2300, requiredIds = {19279}},
        {id = 27841, cost = 2300, requiredIds = {14819}},
        {id = 10942, cost = 46000, requiredIds = {10941}},
        {id = 19275, cost = 2300, requiredIds = {19274}, race = 1},
        {id = 15261, cost = 46000, requiredIds = {15267}},
        {id = 27801, cost = 2300, requiredIds = {27800}, requiredTalentId = 15237},
        {id = 10952, cost = 46000, requiredIds = {10951}},
        {id = 18807, cost = 2300, requiredIds = {17314}, requiredTalentId = 15407},
        {id = 1316995, cost = 46000, requiredIds = {1240721}, requiredTalentId = 402174},
        {id = 10938, cost = 46000, requiredIds = {10937}},
        {id = 10901, cost = 46000, requiredIds = {10900}},
        {id = 10961, cost = 46000, requiredIds = {10960}},
        {id = 1240827, cost = 46000, requiredIds = {1240826}, requiredTalentId = 401859},
        {id = 27681, cost = 2300, requiredIds = {27841}},
        {id = 10955, cost = 46000, requiredIds = {9485}},
        {id = 19266, cost = 2300, requiredIds = {19265}, race = 5},
        {id = 19285, cost = 2300, requiredIds = {19284}, race = 8},
        {id = 19312, cost = 2300, requiredIds = {19311}, race = 8},
        {id = 27871, cost = 1500, requiredIds = {27870}},
        {id = 1277335, cost = 2300, requiredIds = {1277334}, race = 3},
        {id = 1277640, cost = 2300, requiredIds = {1277639}, race = 7},
        {id = 1277328, cost = 2300, requiredIds = {1277327}, race = 5}
    }
}

ns.training.ROGUE = {
    [1] = {{id = 1784, cost = 10}},
    [4] = {{id = 53, cost = 100}, {id = 921, cost = 100}},
    [6] = {{id = 1776, cost = 100}, {id = 1757, cost = 100, requiredIds = {1752}}},
    [8] = {{id = 5277, cost = 200}, {id = 6760, cost = 200, requiredIds = {2098}}},
    [10] = {{id = 674, cost = 300}, {id = 6770, cost = 300}, {id = 5171, cost = 300}, {id = 2983, cost = 300}},
    [12] = {{id = 2589, cost = 800, requiredIds = {53}}, {id = 1766, cost = 800}, {id = 3127, cost = 800}},
    [14] = {{id = 8647, cost = 1200}, {id = 703, cost = 1200}, {id = 1758, cost = 1200, requiredIds = {1757}}},
    [16] = {{id = 6761, cost = 1800, requiredIds = {6760}}, {id = 1966, cost = 1800}, {id = 1804, cost = 1800}},
    [18] = {{id = 8676, cost = 2900}, {id = 1777, cost = 2900, requiredIds = {1776}}},
    [20] = {
        {id = 2590, cost = 3000, requiredIds = {2589}},
        {id = 3420, cost = 3000, skills = {{skill = 40, level = 1}}},
        {id = 1943, cost = 3000},
        {id = 1785, cost = 3000, requiredIds = {1784}}
    },
    [22] = {
        {id = 1725, cost = 4000},
        {id = 8631, cost = 4000, requiredIds = {703}},
        {id = 1759, cost = 4000, requiredIds = {1758}},
        {id = 1856, cost = 4000}
    },
    [24] = {
        {id = 2836, cost = 5000},
        {id = 6762, cost = 5000, requiredIds = {6761}},
        {id = 5763, cost = 5000, skills = {{skill = 40, level = 100}}}
    },
    [26] = {
        {id = 8724, cost = 6000, requiredIds = {8676}},
        {id = 1833, cost = 6000},
        {id = 8649, cost = 6000, requiredIds = {8647}},
        {id = 1767, cost = 6000, requiredIds = {1766}}
    },
    [28] = {
        {id = 2591, cost = 8000, requiredIds = {2590}},
        {id = 6768, cost = 8000, requiredIds = {1966}},
        {id = 8687, cost = 8000, skills = {{skill = 40, level = 120}}},
        {id = 8639, cost = 8000, requiredIds = {1943}},
        {id = 2070, cost = 8000, requiredIds = {6770}}
    },
    [30] = {
        {id = 2835, cost = 10000, skills = {{skill = 40, level = 130}}},
        {id = 1842, cost = 10000, requiredIds = {2836}},
        {id = 8632, cost = 10000, requiredIds = {8631}},
        {id = 408, cost = 10000},
        {id = 1760, cost = 10000, requiredIds = {1759}}
    },
    [32] = {
        {id = 8623, cost = 12000, requiredIds = {6762}},
        {id = 8629, cost = 12000, requiredIds = {1777}},
        {id = 13220, cost = 12000, skills = {{skill = 40, level = 140}}}
    },
    [34] = {
        {id = 8725, cost = 14000, requiredIds = {8724}},
        {id = 2094, cost = 14000, skills = {{skill = 40, level = 1}}},
        {id = 6510, cost = 14000, skills = {{skill = 40, level = 150}}},
        {id = 8696, cost = 14000, requiredIds = {2983}}
    },
    [36] = {
        {id = 8721, cost = 16000, requiredIds = {2591}},
        {id = 8650, cost = 16000, requiredIds = {8649}},
        {id = 8691, cost = 16000, skills = {{skill = 40, level = 160}}},
        {id = 8640, cost = 16000, requiredIds = {8639}}
    },
    [38] = {
        {id = 2837, cost = 18000, skills = {{skill = 40, level = 170}}},
        {id = 8633, cost = 18000, requiredIds = {8632}},
        {id = 8694, cost = 18000, skills = {{skill = 40, level = 170}}},
        {id = 8621, cost = 18000, requiredIds = {1760}}
    },
    [40] = {
        {id = 8624, cost = 20000, requiredIds = {8623}},
        {id = 8637, cost = 20000, requiredIds = {6768}},
        {id = 399956, cost = 10000, requiredIds = {1310706}, requiredTalentId = 1310706},
        {id = 1860, cost = 20000},
        {id = 1786, cost = 20000, requiredIds = {1785}},
        {id = 13228, cost = 20000, skills = {{skill = 40, level = 180}}}
    },
    [42] = {
        {id = 11267, cost = 27000, requiredIds = {8725}},
        {id = 1768, cost = 27000, requiredIds = {1767}},
        {id = 6774, cost = 27000, requiredIds = {5171}},
        {id = 1857, cost = 27000, requiredIds = {1856}}
    },
    [44] = {
        {id = 11279, cost = 29000, requiredIds = {8721}},
        {id = 11341, cost = 29000, skills = {{skill = 40, level = 200}}},
        {id = 11273, cost = 29000, requiredIds = {8640}}
    },
    [46] = {
        {id = 11357, cost = 31000, skills = {{skill = 40, level = 210}}},
        {id = 11197, cost = 31000, requiredIds = {8650}},
        {id = 11289, cost = 31000, requiredIds = {8633}},
        {id = 11285, cost = 31000, requiredIds = {8629}},
        {id = 11293, cost = 31000, requiredIds = {8621}}
    },
    [48] = {
        {id = 11299, cost = 33000, requiredIds = {8624}},
        {id = 11297, cost = 33000, requiredIds = {2070}},
        {id = 13229, cost = 33000, skills = {{skill = 40, level = 220}}}
    },
    [50] = {
        {id = 11268, cost = 35000, requiredIds = {11267}},
        {id = 3421, cost = 35000, skills = {{skill = 40, level = 230}}},
        {id = 8643, cost = 35000, requiredIds = {408}},
        {id = 1241582, cost = 35000, requiredIds = {399956}, requiredTalentId = 1310706}
    },
    [52] = {
        {id = 11280, cost = 46000, requiredIds = {11279}},
        {id = 11303, cost = 46000, requiredIds = {8637}},
        {id = 11342, cost = 46000, skills = {{skill = 40, level = 240}}},
        {id = 11400, cost = 46000, skills = {{skill = 40, level = 240}}},
        {id = 11274, cost = 46000, requiredIds = {11273}}
    },
    [54] = {
        {id = 11358, cost = 48000, skills = {{skill = 40, level = 250}}},
        {id = 11290, cost = 48000, requiredIds = {11289}},
        {id = 11294, cost = 48000, requiredIds = {11293}}
    },
    [56] = {
        {id = 11300, cost = 50000, requiredIds = {11299}},
        {id = 11198, cost = 50000, requiredIds = {11197}},
        {id = 13230, cost = 50000, skills = {{skill = 40, level = 260}}}
    },
    [58] = {
        {id = 11269, cost = 52000, requiredIds = {11268}},
        {id = 1769, cost = 52000, requiredIds = {1768}},
        {id = 11305, cost = 52000, requiredIds = {8696}}
    },
    [60] = {
        {id = 11281, cost = 54000, requiredIds = {11280}},
        {id = 11286, cost = 54000, requiredIds = {11285}},
        {id = 11343, cost = 54000, skills = {{skill = 40, level = 280}}},
        {id = 1241584, cost = 54000, requiredIds = {1241582}, requiredTalentId = 1310706},
        {id = 11275, cost = 54000, requiredIds = {11274}},
        {id = 1787, cost = 54000, requiredIds = {1786}}
    }
}

ns.training.SHAMAN = {
    [1] = {{id = 8017, cost = 10}},
    [4] = {{id = 8042, cost = 100}},
    [6] = {{id = 2484, cost = 100}, {id = 332, cost = 100, requiredIds = {331}}},
    [8] = {
        {id = 8044, cost = 100, requiredIds = {8042}},
        {id = 529, cost = 100, requiredIds = {403}},
        {id = 324, cost = 100},
        {id = 8018, cost = 100, requiredIds = {8017}},
        {id = 5730, cost = 100}
    },
    [10] = {{id = 8050, cost = 400}, {id = 8024, cost = 400}, {id = 8075, cost = 400}},
    [12] = {
        {id = 2008, cost = 800},
        {id = 408341, cost = 800},
        {id = 547, cost = 800, requiredIds = {332}},
        {id = 370, cost = 800}
    },
    [14] = {
        {id = 8045, cost = 900, requiredIds = {8044}},
        {id = 548, cost = 900, requiredIds = {529}},
        {id = 8154, cost = 900, requiredIds = {8071}}
    },
    [16] = {
        {id = 526, cost = 1800},
        {id = 325, cost = 1800, requiredIds = {324}},
        {id = 8019, cost = 1800, requiredIds = {8018}}
    },
    [18] = {
        {id = 8052, cost = 2000, requiredIds = {8050}},
        {id = 8027, cost = 2000, requiredIds = {8024}},
        {id = 913, cost = 2000, requiredIds = {547}},
        {id = 6390, cost = 2000, requiredIds = {5730}},
        {id = 8143, cost = 2000}
    },
    [20] = {
        {id = 66842, cost = 7000},
        {id = 8056, cost = 2200},
        {id = 8033, cost = 2200},
        {id = 2645, cost = 2200},
        {id = 8004, cost = 2200},
        {id = 915, cost = 2200, requiredIds = {548}},
        {id = 6363, cost = 2200, requiredIds = {3599}},
        {id = 36936, cost = 7000}
    },
    [22] = {
        {id = 2870, cost = 3000},
        {id = 408342, cost = 3000, requiredIds = {408341}},
        {id = 8166, cost = 3000},
        {id = 437009, cost = 3000},
        {id = 131, cost = 3000}
    },
    [24] = {
        {id = 20609, cost = 3500, requiredIds = {2008}},
        {id = 8046, cost = 3500, requiredIds = {8045}},
        {id = 8181, cost = 3500},
        {id = 939, cost = 3500, requiredIds = {913}},
        {id = 905, cost = 3500, requiredIds = {325}},
        {id = 10399, cost = 3500, requiredIds = {8019}},
        {id = 8155, cost = 3500, requiredIds = {8154}},
        {id = 8160, cost = 3500, requiredIds = {8075}}
    },
    [26] = {
        {id = 6196, cost = 4000},
        {id = 8030, cost = 4000, requiredIds = {8027}},
        {id = 943, cost = 4000, requiredIds = {915}},
        {id = 8190, cost = 4000},
        {id = 5675, cost = 4000}
    },
    [28] = {
        {id = 8184, cost = 6000},
        {id = 8053, cost = 6000, requiredIds = {8052}},
        {id = 8227, cost = 6000},
        {id = 8038, cost = 6000, requiredIds = {8033}},
        {id = 8008, cost = 6000, requiredIds = {8004}},
        {id = 6391, cost = 6000, requiredIds = {6390}},
        {id = 546, cost = 6000}
    },
    [30] = {
        {id = 556, cost = 7000},
        {id = 66843, cost = 7000, requiredIds = {66842}},
        {id = 8177, cost = 7000},
        {id = 6375, cost = 7000, requiredIds = {5394}},
        {id = 10595, cost = 7000},
        {id = 20608, cost = 7000},
        {id = 6364, cost = 7000, requiredIds = {6363}},
        {id = 8232, cost = 7000}
    },
    [32] = {
        {id = 421, cost = 8000},
        {id = 408343, cost = 8000, requiredIds = {408342}},
        {id = 959, cost = 8000, requiredIds = {939}},
        {id = 6041, cost = 8000, requiredIds = {943}},
        {id = 945, cost = 8000, requiredIds = {905}},
        {id = 8012, cost = 8000, requiredIds = {370}},
        {id = 8512, cost = 8000}
    },
    [34] = {
        {id = 8058, cost = 9000, requiredIds = {8056}},
        {id = 16314, cost = 9000, requiredIds = {10399}},
        {id = 6495, cost = 9000},
        {id = 10406, cost = 9000, requiredIds = {8155}}
    },
    [36] = {
        {id = 20610, cost = 10000, requiredIds = {20609}},
        {id = 10412, cost = 10000, requiredIds = {8046}},
        {id = 16339, cost = 10000, requiredIds = {8030}},
        {id = 8010, cost = 10000, requiredIds = {8008}},
        {id = 10585, cost = 10000, requiredIds = {8190}},
        {id = 10495, cost = 10000, requiredIds = {5675}},
        {id = 15107, cost = 10000}
    },
    [38] = {
        {id = 8170, cost = 11000},
        {id = 8249, cost = 11000, requiredIds = {8227}},
        {id = 10478, cost = 11000, requiredIds = {8181}},
        {id = 10456, cost = 11000, requiredIds = {8038}},
        {id = 10391, cost = 11000, requiredIds = {6041}},
        {id = 6392, cost = 11000, requiredIds = {6391}},
        {id = 8161, cost = 11000, requiredIds = {8160}}
    },
    [40] = {
        {id = 66844, cost = 7000, requiredIds = {66843}},
        {id = 1064, cost = 12000},
        {id = 930, cost = 12000, requiredIds = {421}},
        {id = 10447, cost = 12000, requiredIds = {8053}},
        {id = 6377, cost = 12000, requiredIds = {6375}},
        {id = 8005, cost = 12000, requiredIds = {959}},
        {id = 8134, cost = 12000, requiredIds = {945}},
        {id = 8737, cost = 12000},
        {id = 6365, cost = 12000, requiredIds = {6364}},
        {id = 8235, cost = 12000, requiredIds = {8232}}
    },
    [42] = {
        {id = 408344, cost = 16000, requiredIds = {408343}},
        {id = 10537, cost = 16000, requiredIds = {8184}},
        {id = 8835, cost = 16000},
        {id = 10613, cost = 16000, requiredIds = {8512}}
    },
    [44] = {
        {id = 10466, cost = 18000, requiredIds = {8010}},
        {id = 10392, cost = 18000, requiredIds = {10391}},
        {id = 10600, cost = 18000, requiredIds = {10595}},
        {id = 16315, cost = 18000, requiredIds = {16314}},
        {id = 10407, cost = 18000, requiredIds = {10406}}
    },
    [46] = {
        {id = 10622, cost = 20000, requiredIds = {1064}},
        {id = 16341, cost = 20000, requiredIds = {16339}},
        {id = 10472, cost = 20000, requiredIds = {8058}},
        {id = 10586, cost = 20000, requiredIds = {10585}},
        {id = 10496, cost = 20000, requiredIds = {10495}},
        {id = 15111, cost = 20000, requiredIds = {15107}}
    },
    [48] = {
        {id = 20776, cost = 22000, requiredIds = {20610}},
        {id = 2860, cost = 22000, requiredIds = {930}},
        {id = 10413, cost = 22000, requiredIds = {10412}},
        {id = 10526, cost = 22000, requiredIds = {8249}},
        {id = 16355, cost = 22000, requiredIds = {10456}},
        {id = 10395, cost = 22000, requiredIds = {8005}},
        {id = 10431, cost = 22000, requiredIds = {8134}},
        {id = 17354, cost = 800, requiredIds = {16190}, requiredTalentId = 16190},
        {id = 10427, cost = 22000, requiredIds = {6392}}
    },
    [50] = {
        {id = 10462, cost = 24000, requiredIds = {6377}},
        {id = 1238299, cost = 24000, requiredIds = {408490}, requiredTalentId = 408490},
        {id = 15207, cost = 24000, requiredIds = {10392}},
        {id = 1239242, cost = 800, requiredIds = {408521}, requiredTalentId = 408521},
        {id = 10437, cost = 24000, requiredIds = {6365}},
        {id = 10486, cost = 24000, requiredIds = {8235}}
    },
    [52] = {
        {id = 408345, cost = 27000, requiredIds = {408344}},
        {id = 10448, cost = 27000, requiredIds = {10447}},
        {id = 10467, cost = 27000, requiredIds = {10466}},
        {id = 10442, cost = 27000, requiredIds = {8161}},
        {id = 10614, cost = 27000, requiredIds = {10613}}
    },
    [54] = {
        {id = 10623, cost = 29000, requiredIds = {10622}},
        {id = 10479, cost = 29000, requiredIds = {10478}},
        {id = 16316, cost = 29000, requiredIds = {16315}},
        {id = 10408, cost = 29000, requiredIds = {10407}}
    },
    [56] = {
        {id = 10605, cost = 30000, requiredIds = {2860}},
        {id = 16342, cost = 30000, requiredIds = {16341}},
        {id = 10627, cost = 30000, requiredIds = {8835}},
        {id = 10396, cost = 30000, requiredIds = {10395}},
        {id = 15208, cost = 30000, requiredIds = {15207}},
        {id = 10432, cost = 30000, requiredIds = {10431}},
        {id = 10587, cost = 30000, requiredIds = {10586}},
        {id = 10497, cost = 30000, requiredIds = {10496}},
        {id = 15112, cost = 30000, requiredIds = {15111}}
    },
    [58] = {
        {id = 10538, cost = 32000, requiredIds = {10537}},
        {id = 16387, cost = 32000, requiredIds = {10526}},
        {id = 10473, cost = 32000, requiredIds = {10472}},
        {id = 16356, cost = 32000, requiredIds = {16355}},
        {id = 17359, cost = 1600, requiredIds = {17354}, requiredTalentId = 16190},
        {id = 10428, cost = 32000, requiredIds = {10427}}
    },
    [60] = {
        {id = 20777, cost = 34000, requiredIds = {20776}},
        {id = 10414, cost = 34000, requiredIds = {10413}},
        {id = 10463, cost = 34000, requiredIds = {10462}},
        {id = 1238300, cost = 34000, requiredIds = {1238299}, requiredTalentId = 408490},
        {id = 10468, cost = 34000, requiredIds = {10467}},
        {id = 10601, cost = 34000, requiredIds = {10600}},
        {id = 1239243, cost = 1600, requiredIds = {1239242}, requiredTalentId = 408521},
        {id = 10438, cost = 34000, requiredIds = {10437}},
        {id = 16362, cost = 34000, requiredIds = {10486}}
    }
}

ns.training.WARLOCK = {
    [1] = {{id = 348, cost = 10}},
    [4] = {{id = 172, cost = 100}, {id = 702, cost = 100}},
    [6] = {{id = 1454, cost = 100}, {id = 695, cost = 100, requiredIds = {686}}},
    [8] = {{id = 980, cost = 200}, {id = 5782, cost = 200}},
    [10] = {
        {id = 6201, cost = 300, requiredIds = {1120}},
        {id = 696, cost = 300, requiredIds = {687}},
        {id = 1120, cost = 300},
        {id = 707, cost = 300, requiredIds = {348}}
    },
    [12] = {
        {id = 1108, cost = 600, requiredIds = {702}},
        {id = 755, cost = 600},
        {id = 705, cost = 600, requiredIds = {695}}
    },
    [14] = {{id = 6222, cost = 900, requiredIds = {172}}, {id = 704, cost = 900}, {id = 689, cost = 900}},
    [16] = {{id = 1455, cost = 1200, requiredIds = {1454}}, {id = 5697, cost = 1200}},
    [18] = {
        {id = 1014, cost = 1500, requiredIds = {980}},
        {id = 693, cost = 1500, requiredIds = {1120}},
        {id = 5676, cost = 1500}
    },
    [20] = {
        {id = 440892, cost = 2000},
        {id = 706, cost = 2000},
        {id = 3698, cost = 2000, requiredIds = {755}},
        {id = 1094, cost = 2000, requiredIds = {707}},
        {id = 5740, cost = 2000},
        {id = 698, cost = 2000},
        {id = 1088, cost = 2000, requiredIds = {705}}
    },
    [22] = {
        {id = 6202, cost = 2500, requiredIds = {6201}},
        {id = 6205, cost = 2500, requiredIds = {1108}},
        {id = 699, cost = 2500, requiredIds = {689}},
        {id = 126, cost = 2500}
    },
    [24] = {
        {id = 6223, cost = 3000, requiredIds = {6222}},
        {id = 5138, cost = 3000},
        {id = 8288, cost = 3000, requiredIds = {1120}},
        {id = 5500, cost = 3000},
        {id = 18867, cost = 150, requiredIds = {17877}, requiredTalentId = 17877}
    },
    [26] = {
        {id = 1714, cost = 4000},
        {id = 132, cost = 4000},
        {id = 1456, cost = 4000, requiredIds = {1455}},
        {id = 17919, cost = 4000, requiredIds = {5676}}
    },
    [28] = {
        {id = 6217, cost = 5000, requiredIds = {1014}},
        {id = 710, cost = 5000},
        {id = 6366, cost = 5000},
        {id = 7658, cost = 5000, requiredIds = {704}},
        {id = 3699, cost = 5000, requiredIds = {3698}},
        {id = 1106, cost = 5000, requiredIds = {1088}}
    },
    [30] = {
        {id = 20752, cost = 6000, requiredIds = {693}},
        {id = 1311676, cost = 6000, requiredIds = {440892}},
        {id = 1086, cost = 6000, requiredIds = {706}},
        {id = 709, cost = 6000, requiredIds = {699}},
        {id = 1949, cost = 6000},
        {id = 2941, cost = 6000, requiredIds = {1094}},
        {id = 1098, cost = 6000}
    },
    [32] = {
        {id = 1293818, cost = 300, requiredIds = {1293817}, requiredTalentId = 1293817},
        {id = 7646, cost = 7000, requiredIds = {6205}},
        {id = 6213, cost = 7000, requiredIds = {5782}},
        {id = 6229, cost = 7000},
        {id = 18868, cost = 350, requiredIds = {18867}, requiredTalentId = 17877}
    },
    [34] = {
        {id = 7648, cost = 8000, requiredIds = {6223}},
        {id = 5699, cost = 8000, requiredIds = {6202}},
        {id = 6226, cost = 8000, requiredIds = {5138}},
        {id = 6219, cost = 8000, requiredIds = {5740}},
        {id = 17920, cost = 8000, requiredIds = {17919}}
    },
    [36] = {
        {id = 17951, cost = 9000, requiredIds = {6366}},
        {id = 2362, cost = 9000, requiredIds = {1120}},
        {id = 3700, cost = 9000, requiredIds = {3699}},
        {id = 11687, cost = 9000, requiredIds = {1456}},
        {id = 7641, cost = 9000, requiredIds = {1106}}
    },
    [38] = {
        {id = 11711, cost = 10000, requiredIds = {6217}},
        {id = 2970, cost = 10000, requiredIds = {132}},
        {id = 7651, cost = 10000, requiredIds = {709}},
        {id = 8289, cost = 10000, requiredIds = {8288}},
        {id = 18879, cost = 1000, requiredIds = {18265}, requiredTalentId = 18265}
    },
    [40] = {
        {id = 17962, cost = 500, requiredIds = {1293818}, requiredTalentId = 1293817},
        {id = 20755, cost = 11000, requiredIds = {20752}},
        {id = 1311677, cost = 11000, requiredIds = {1311676}},
        {id = 11733, cost = 11000, requiredIds = {1086}},
        {id = 5484, cost = 11000},
        {id = 11665, cost = 11000, requiredIds = {2941}},
        {id = 18869, cost = 550, requiredIds = {18868}, requiredTalentId = 17877}
    },
    [42] = {
        {id = 7659, cost = 11000, requiredIds = {7658}},
        {id = 11707, cost = 11000, requiredIds = {7646}},
        {id = 6789, cost = 11000},
        {id = 11683, cost = 11000, requiredIds = {1949}},
        {id = 17921, cost = 11000, requiredIds = {17920}},
        {id = 11739, cost = 11000, requiredIds = {6229}}
    },
    [44] = {
        {id = 11671, cost = 12000, requiredIds = {7648}},
        {id = 11703, cost = 12000, requiredIds = {6226}},
        {id = 11693, cost = 12000, requiredIds = {3700}},
        {id = 11659, cost = 12000, requiredIds = {7641}},
        {id = 11725, cost = 12000, requiredIds = {1098}}
    },
    [46] = {
        {id = 17952, cost = 13000, requiredIds = {17951}},
        {id = 11729, cost = 13000, requiredIds = {5699}},
        {id = 11699, cost = 13000, requiredIds = {7651}},
        {id = 11688, cost = 13000, requiredIds = {11687}},
        {id = 11677, cost = 13000, requiredIds = {6219}}
    },
    [48] = {
        {id = 11712, cost = 14000, requiredIds = {11711}},
        {id = 18647, cost = 14000, requiredIds = {710}},
        {id = 18930, cost = 700, requiredIds = {17962}, requiredTalentId = 1293817},
        {id = 17727, cost = 14000, requiredIds = {2362}},
        {id = 18870, cost = 700, requiredIds = {18869}, requiredTalentId = 17877},
        {id = 18880, cost = 1400, requiredIds = {18879}, requiredTalentId = 18265},
        {id = 6353, cost = 14000}
    },
    [50] = {
        {id = 20756, cost = 15000, requiredIds = {20755}},
        {id = 1311680, cost = 15000, requiredIds = {1311677}},
        {id = 11719, cost = 15000, requiredIds = {1714}},
        {id = 17925, cost = 15000, requiredIds = {6789}},
        {id = 11734, cost = 15000, requiredIds = {11733}},
        {id = 11743, cost = 15000, requiredIds = {2970}},
        {id = 11667, cost = 15000, requiredIds = {11665}},
        {id = 1293812, cost = 900, requiredIds = {412758}, requiredTalentId = 412758},
        {id = 17922, cost = 15000, requiredIds = {17921}}
    },
    [52] = {
        {id = 11708, cost = 18000, requiredIds = {11707}},
        {id = 11675, cost = 18000, requiredIds = {8289}},
        {id = 11694, cost = 18000, requiredIds = {11693}},
        {id = 11660, cost = 18000, requiredIds = {11659}},
        {id = 11740, cost = 18000, requiredIds = {11739}}
    },
    [54] = {
        {id = 18931, cost = 1000, requiredIds = {18930}, requiredTalentId = 1293817},
        {id = 11672, cost = 20000, requiredIds = {11671}},
        {id = 11700, cost = 20000, requiredIds = {11699}},
        {id = 11704, cost = 20000, requiredIds = {11703}},
        {id = 11684, cost = 20000, requiredIds = {11683}},
        {id = 17928, cost = 20000, requiredIds = {5484}}
    },
    [56] = {
        {id = 17953, cost = 22000, requiredIds = {17952}},
        {id = 11717, cost = 22000, requiredIds = {7659}},
        {id = 6215, cost = 22000, requiredIds = {6213}},
        {id = 11689, cost = 22000, requiredIds = {11688}},
        {id = 18871, cost = 1100, requiredIds = {18870}, requiredTalentId = 17877},
        {id = 17924, cost = 22000, requiredIds = {6353}}
    },
    [58] = {
        {id = 11713, cost = 24000, requiredIds = {11712}},
        {id = 11730, cost = 24000, requiredIds = {11729}},
        {id = 17926, cost = 24000, requiredIds = {17925}},
        {id = 11678, cost = 24000, requiredIds = {11677}},
        {id = 17923, cost = 24000, requiredIds = {17922}},
        {id = 18881, cost = 2400, requiredIds = {18880}, requiredTalentId = 18265},
        {id = 11726, cost = 24000, requiredIds = {11725}}
    },
    [60] = {
        {id = 603, cost = 26000},
        {id = 18932, cost = 1300, requiredIds = {18931}, requiredTalentId = 1293817},
        {id = 20757, cost = 26000, requiredIds = {20756}},
        {id = 17728, cost = 26000, requiredIds = {17727}},
        {id = 11735, cost = 26000, requiredIds = {11734}},
        {id = 11695, cost = 26000, requiredIds = {11694}},
        {id = 11668, cost = 26000, requiredIds = {11667}},
        {id = 1293813, cost = 1100, requiredIds = {1293812}, requiredTalentId = 412758},
        {id = 11661, cost = 26000, requiredIds = {11660}}
    }
}

ns.training.WARRIOR = {
    [1] = {{id = 6673, cost = 10}},
    [4] = {{id = 100, cost = 100}, {id = 772, cost = 100}},
    [6] = {{id = 3127, cost = 100}, {id = 6343, cost = 100}},
    [8] = {{id = 1715, cost = 200}, {id = 284, cost = 200, requiredIds = {78}}},
    [10] = {{id = 2687, cost = 600}, {id = 6546, cost = 600, requiredIds = {772}}},
    [12] = {{id = 5242, cost = 1000, requiredIds = {6673}}, {id = 7384, cost = 1000}, {id = 72, cost = 1000}},
    [14] = {{id = 1160, cost = 1500}, {id = 6572, cost = 1500, requiredIds = {71}}, {id = 1310185, cost = 1500}},
    [16] = {
        {id = 285, cost = 2000, requiredIds = {284}},
        {id = 694, cost = 2000},
        {id = 2565, cost = 2000, requiredIds = {71}}
    },
    [18] = {{id = 676, cost = 3000, requiredIds = {71}}, {id = 8198, cost = 3000, requiredIds = {6343}}},
    [20] = {
        {id = 845, cost = 4000},
        {id = 674, cost = 4000},
        {id = 6547, cost = 4000, requiredIds = {6546}},
        {id = 20230, cost = 4000},
        {id = 1240193, cost = 4000},
        {id = 402927, cost = 4000}
    },
    [22] = {
        {id = 6192, cost = 6000, requiredIds = {5242}},
        {id = 5246, cost = 6000},
        {id = 7405, cost = 6000, requiredIds = {7386}}
    },
    [24] = {
        {id = 6190, cost = 8000, requiredIds = {1160}},
        {id = 5308, cost = 8000},
        {id = 1608, cost = 8000, requiredIds = {285}},
        {id = 6574, cost = 8000, requiredIds = {6572}}
    },
    [26] = {
        {id = 1161, cost = 10000},
        {id = 6178, cost = 10000, requiredIds = {100}},
        {id = 7400, cost = 10000, requiredIds = {694}}
    },
    [28] = {
        {id = 7887, cost = 11000, requiredIds = {7384}},
        {id = 871, cost = 11000, requiredIds = {71}},
        {id = 8204, cost = 11000, requiredIds = {8198}}
    },
    [30] = {
        {id = 7369, cost = 12000, requiredIds = {845}},
        {id = 6548, cost = 12000, requiredIds = {6547}},
        {id = 1464, cost = 12000, requiredIds = {1240193}}
    },
    [32] = {
        {id = 11549, cost = 14000, requiredIds = {6192}},
        {id = 18499, cost = 14000, requiredIds = {2458}},
        {id = 20658, cost = 14000, requiredIds = {5308}},
        {id = 7372, cost = 14000, requiredIds = {1715}},
        {id = 11564, cost = 14000, requiredIds = {1608}},
        {id = 1671, cost = 14000, requiredIds = {72}}
    },
    [34] = {
        {id = 11554, cost = 16000, requiredIds = {6190}},
        {id = 7379, cost = 16000, requiredIds = {6574}},
        {id = 8380, cost = 16000, requiredIds = {7405}}
    },
    [36] = {{id = 7402, cost = 18000, requiredIds = {7400}}, {id = 1680, cost = 18000, requiredIds = {2458}}},
    [38] = {
        {id = 6552, cost = 20000, requiredIds = {2458}},
        {id = 8820, cost = 20000, requiredIds = {1464}},
        {id = 8205, cost = 20000, requiredIds = {8204}}
    },
    [40] = {
        {id = 11608, cost = 22000, requiredIds = {7369}},
        {id = 20660, cost = 22000, requiredIds = {20658}},
        {id = 11565, cost = 22000, requiredIds = {11564}},
        {id = 750, cost = 22000},
        {id = 11572, cost = 22000, requiredIds = {6548}}
    },
    [42] = {{id = 11550, cost = 32000, requiredIds = {11549}}, {id = 20616, cost = 32000, requiredIds = {20252}}},
    [44] = {
        {id = 11555, cost = 34000, requiredIds = {11554}},
        {id = 11584, cost = 34000, requiredIds = {7887}},
        {id = 11600, cost = 34000, requiredIds = {7379}}
    },
    [46] = {
        {id = 11578, cost = 36000, requiredIds = {6178}},
        {id = 20559, cost = 36000, requiredIds = {7402}},
        {id = 11604, cost = 36000, requiredIds = {8820}},
        {id = 11596, cost = 36000, requiredIds = {8380}}
    },
    [48] = {
        {id = 23892, cost = 2000, requiredIds = {23881}, requiredTalentId = 23881},
        {id = 20661, cost = 40000, requiredIds = {20660}},
        {id = 11566, cost = 40000, requiredIds = {11565}},
        {id = 21551, cost = 2000, requiredIds = {12294}, requiredTalentId = 12294},
        {id = 23923, cost = 2000, requiredIds = {23922}, requiredTalentId = 23922},
        {id = 11580, cost = 40000, requiredIds = {8205}}
    },
    [50] = {
        {id = 11609, cost = 42000, requiredIds = {11608}},
        {id = 1719, cost = 42000, requiredIds = {2458}},
        {id = 11573, cost = 42000, requiredIds = {11572}}
    },
    [52] = {
        {id = 11551, cost = 54000, requiredIds = {11550}},
        {id = 20617, cost = 54000, requiredIds = {20616}},
        {id = 1672, cost = 54000, requiredIds = {1671}}
    },
    [54] = {
        {id = 23893, cost = 2800, requiredIds = {23892}, requiredTalentId = 23881},
        {id = 11556, cost = 56000, requiredIds = {11555}},
        {id = 7373, cost = 56000, requiredIds = {7372}},
        {id = 21552, cost = 2800, requiredIds = {21551}, requiredTalentId = 12294},
        {id = 11601, cost = 56000, requiredIds = {11600}},
        {id = 23924, cost = 2800, requiredIds = {23923}, requiredTalentId = 23922},
        {id = 11605, cost = 56000, requiredIds = {11604}}
    },
    [56] = {
        {id = 20662, cost = 58000, requiredIds = {20661}},
        {id = 11567, cost = 58000, requiredIds = {11566}},
        {id = 20560, cost = 58000, requiredIds = {20559}}
    },
    [58] = {
        {id = 6554, cost = 60000, requiredIds = {6552}},
        {id = 11597, cost = 60000, requiredIds = {11596}},
        {id = 11581, cost = 60000, requiredIds = {11580}}
    },
    [60] = {
        {id = 23894, cost = 3100, requiredIds = {23893}, requiredTalentId = 23881},
        {id = 20569, cost = 62000, requiredIds = {11609}},
        {id = 21553, cost = 3100, requiredIds = {21552}, requiredTalentId = 12294},
        {id = 11585, cost = 62000, requiredIds = {11584}},
        {id = 11574, cost = 62000, requiredIds = {11573}},
        {id = 23925, cost = 3100, requiredIds = {23924}, requiredTalentId = 23922}
    }
}
