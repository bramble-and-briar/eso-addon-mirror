LibDeconValue = LibDeconValue or {}
local LibDeconValue = LibDeconValue
local Data = {}
LibDeconValue.Data = Data

Data.base_id = {
  [CRAFTING_TYPE_BLACKSMITHING] = {
    level = {
      { min = 1,  max = 15, id = 5413 },
      { min = 16, max = 25, id = 4487 },
      { min = 26, max = 35, id = 23107 },
      { min = 36, max = 45, id = 6000 },
      { min = 46, max = 50, id = 6001 },
    },
    cp = {
      { min = 10,  max = 30,  id = 46127 },
      { min = 40,  max = 60,  id = 46128 },
      { min = 70,  max = 80,  id = 46129 },
      { min = 90,  max = 140, id = 46130 },
      { min = 150, max = 160, id = 64489 },
    },
  },
  [CRAFTING_TYPE_CLOTHIER] = {
    level = {
      { min = 1,  max = 15, light = 811,  medium = 794,  heavy = 5413 },
      { min = 16, max = 25, light = 4463, medium = 4447, heavy = 4487 },
      { min = 26, max = 35, light = 23125, medium = 23099, heavy = 23107 },
      { min = 36, max = 45, light = 23126, medium = 23100, heavy = 6000 },
      { min = 46, max = 50, light = 23127, medium = 23101, heavy = 6001 },
    },
    cp = {
      { min = 10,  max = 30,  light = 46131, medium = 46135, heavy = 46127 },
      { min = 40,  max = 60,  light = 46132, medium = 46136, heavy = 46128 },
      { min = 70,  max = 80,  light = 46133, medium = 46137, heavy = 46129 },
      { min = 90,  max = 140, light = 46134, medium = 46138, heavy = 46130 },
      { min = 150, max = 160, light = 64504, medium = 64506, heavy = 64489 },
    },
  },
  [CRAFTING_TYPE_WOODWORKING] = {
    level = {
      { min = 1,  max = 15, id = 803 },
      { min = 16, max = 25, id = 533 },
      { min = 26, max = 35, id = 23121 },
      { min = 36, max = 45, id = 23122 },
      { min = 46, max = 50, id = 23123 },
    },
    cp = {
      { min = 10,  max = 30,  id = 46139 },
      { min = 40,  max = 60,  id = 46140 },
      { min = 70,  max = 80,  id = 46141 },
      { min = 90,  max = 140, id = 46142 },
      { min = 150, max = 160, id = 64502 },
    },
  },
  [CRAFTING_TYPE_JEWELRYCRAFTING] = {
    level = {
      { min = 1,  max = 25, id = 135138 },
      { min = 26, max = 50, id = 135140 },
    },
    cp = {
      { min = 10,  max = 70,  id = 135142 },
      { min = 71,  max = 140, id = 135144 },
      { min = 141, max = 160, id = 135146 },
    },
  },
}

-- Trait materials of the Nirnhoned trait (Fortified Nirncrux, Potent Nirncrux).
Data.nirncrux = {
  [56862] = true,
  [56863] = true,
}

-- Style materials that deconstruction never returns (Crown Mimic Stone).
Data.styleMaterialBlacklist = {
  [71668] = true,
}
