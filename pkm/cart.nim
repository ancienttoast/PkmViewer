import
  streams, tables,
  gba/rom, pkm/[data, tileset, types]

export
  rom



type
  PkmRom* = ref object of GBARom
    gameData*: PkmGameData
    tilesetCache*: TableRef[int64, PkmRenderedTileset]


proc loadPkmRom*(stream: Stream): PkmRom =
  result = PkmRom()
  result.GBARom.init(stream)
  result.gameData = dataStore[result.code]
  result.tilesetCache = newTable[int64, PkmRenderedTileset]()