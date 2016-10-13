import
  pkm.cart, gba.image, pkm.types



const
  PkmBlockSize* = 2 * GbaTileSize

type
  PkmTilesetHeader = tuple
    compressed:    uint8
    isLocal:       uint8

    unkown:        uint16

    image:         GBAPointer
    palettes:      GBAPointer
    blocks:        GBAPointer
    animation:     GBAPointer
    behavior:      GBAPointer


  TripleKind = enum
    tkNone
    tkLegacy
    tkLegacy2
    tkReference

  PkmTile* = tuple
    num: int
    palette: int
    xFlip: bool
    yFlip: bool

    layer: int
    x: int
    y: int

  PkmBlock* = seq[PkmTile]


  PkmTileset* = object
    offset*: GBAPointer

    image*: GbaImage
    palettes*: array[13, GbaPalette]
    blocks*: seq[PkmBlock]



proc readBehavior (s: PkmRom, header: PkmTilesetHeader, blockNum: int): int =
  if s.gameData.engine == 1:
    s.seek (header.behavior + (blockNum * 4)).read (uint32).int
  else:
    (s.seek (header.behavior + (blockNum * 2)).read (uint32) and 0xffff).int

proc readBlock (s: PkmRom, header: PkmTilesetHeader, blockNum: int): PkmBlock =
  let
    behavior = s.readBehavior (header, blockNum)

    shiftSize = if s.gameData.engine == 1: 24 else: 8
    tripleTile = 
      if   ((behavior shr shiftSize) and 0x30) == 0x30: tkLegacy
      elif ((behavior shr shiftSize) and 0x40) == 0x40: tkLegacy2
      elif ((behavior shr shiftSize) and 0x60) == 0x60 and s.gameData.engine == 1: tkReference
      else:
        tkNone

  var
    blockPointer =
      if ((behavior shr shiftSize) and 0x40) == 0x40:
        header.blocks + 8 + (blockNum * 16)
      else:
        header.blocks + (blockNum * 16)

    numTiles = if tripleTile != tkNone: 12 else: 8

  result = newSeq[PkmTile] (numTiles)
  var
    x = 0
    y = 0
    layerNumber = 0
  for i, t in result.mpairs:
    # TODO: tripleTile?? Investigate!! (Fire Red doesn't seem to have theese)
    if tripleTile == tkReference and i == 16:
      var
        tripNum = ((behavior shr 14) and 0x3ff).int
        second = false
      if tripNum >= s.gameData.mainTSBlocks:
        second = true
        tripNum -= s.gameData.mainTSBlocks

      blockPointer = header.blocks + (tripNum * 16) + 8
      blockPointer = blockPointer - i*2

    let
      orig = s.seek (blockPointer + i*2).read (uint16).int
    t = (
      num:     orig and 0x3ff,
      palette: (orig and 0xf000) shr 12,
      xFlip:   (orig and 0x400) > 0,
      yFlip:   (orig and 0x800) > 0,

      layer: layerNumber,
      x: x,
      y: y      
    )

    x += 1
    if x > 1:
      x = 0
      y += 1
    if y > 1:
      x = 0
      y = 0
      layerNumber += 1


proc readPkmTileset* (s: PkmRom, numBlocks: int): PkmTileset =
  result = PkmTileset (offset: s.tell())
  let
    header = s.read (PkmTilesetHeader)
  if header.compressed != 1:
    raise newException (Exception, "Non compressed tileset loading not implemented!")

  for i, p in result.palettes.mpairs:
    p = s.seek (header.palettes + i*32).readGbaPalette (false)

  result.image = s.seek (header.image).readGbaImage()

  result.blocks = newSeq[PkmBlock] (numBlocks)
  for i in 0 ..< numBlocks:
    result.blocks[i] = s.readBlock (header, i)