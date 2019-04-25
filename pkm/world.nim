import
  sequtils, tables,
  pkm.cart, pkm.types, pkm.tileset, pkm.render, pkm.link



type
  PkmMapHeader = tuple
    layout:      GBAPointer
    events:      GBAPointer
    scripts:     GBAPointer
    links:       GBAPointer   # pointer to the map links field, 0 if there is none

    musicIndex:  uint16
    mapPtrIndex: uint16
    labelIndex:  uint8

    visibility:  uint8
    weather:     uint8
    mapKind:     uint8
    unkown0:     uint8
    unkown1:     uint8
    showLabel:   uint8
    battleField: uint8

  PkmMapLayout = tuple
    size:          array[2, uint32]
    border:        GBAPointer

    tiles:         GBAPointer
    globalTileset: GBAPointer
    localTileset:  GBAPointer

    borderSize:    array[2, uint8]


  PkmMapTile = tuple
    num: int
    attribute: int

  PkmMap* = object
    offset: GBAPointer
    header: PkmMapHeader

    size*: array[2, uint32]

    tileset*: PkmRenderedTileset
    tiles*: seq[PkmMapTile]
    links*: seq[PkmMapLink]


proc calcNumBlocks(s: PkmRom, tiles: seq[uint16]): int =
  var z = 0
  for t in tiles:
    # search for the biggest tile index
    if (t.int and 0x03ff) > z:
      z = (t.int and 0x03ff)
  z - s.gameData.mainTSBlocks + 1

proc readPkmMap(s: PkmRom): PkmMap =
  let
    offset = s.tell()

    header = s.seek(offset).read(PkmMapHeader)
    layout = s.seek(header.layout).read(PkmMapLayout)

    tiles  = s.seek(layout.tiles).read(layout.size[0].int * layout.size[1].int, uint16)

  result = PkmMap(
    offset: offset,
    header: header,

    size: layout.size,
    tiles: tiles.mapIt(PkmMapTile, (num: it.int and 0x03ff, attribute: (it.int and 0xff00) shr 8)),
    links:
      if header.links.int == 0:
        newSeq[PkmMapLink]()
      else:
        s.seek(header.links).readPkmMapLinks()
  )

  let
    tsId = (layout.globalTileset.int64 shl 32) + layout.localTileset.int64
  if tsId notin s.tilesetCache:
    let
      globalTs = s.seek(layout.globalTileset).readPkmTileset(s.gameData.mainTSBlocks)
      localTs  = s.seek(layout.localTileset).readPkmTileset(s.calcNumBlocks(tiles))

    s.tilesetCache[tsId] = s.renderTileset(globalTs, localTs)

  result.tileset = s.tilesetCache[tsId]





type
  PkmMapBank* = seq[PkmMap]

  PkmWorld* = object
    banks: seq[PkmMapBank]


proc readPkmBank*(s: PkmRom, numMaps: int): PkmMapBank =
  result.newSeq(numMaps)
  let
    mapPtrs = s.read(result.len, GBAPointer)

  for i, m in result.mpairs:
    m = s.seek(mapPtrs[i]).readPkmMap()

proc readPkmWorld*(s: PkmRom): PkmWorld =
  result = PkmWorld(
    banks: newSeq[PkmMapBank](s.gameData.numBanks)
  )

  let
    bankListPtr = s.seek(s.gameData.mapHeaders).read(GBAPointer)
  for i, b in result.banks.mpairs:
    let
      bankPtr = s.seek(bankListPtr + i*4).read(GBAPointer)
    b = s.seek(bankPtr).readPkmBank(s.gameData.bankMapNums[i])