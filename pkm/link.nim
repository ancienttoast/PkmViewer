import
  pkm.cart



type
  PkmMapLinkData = tuple
    direction: uint32   # connection direction
    offset:    int32    # offset in reference to connecting map
    bank:      uint8    # bank index
    map:       uint8    # map index
    filler:    uint16


  PkmLinkDir* = enum
    ldNone   = 0x0
    ldDown   = 0x1
    ldUp     = 0x2
    ldLeft   = 0x3
    ldRight  = 0x4
    ldDive   = 0x5
    ldEmerge = 0x6

  PkmMapLink* = object
    direction*: PkmLinkDir
    offset*: int
    bank*: int
    map*: int


proc readPkmMapLink (s: PkmRom): PkmMapLink =
  let
    data = s.read (PkmMapLinkData)
  PkmMapLink (
    direction: data.direction.PkmLinkDir,
    offset: data.offset.int,

    bank: data.bank.int,
    map: data.map.int
  )

proc readPkmMapLinks* (s: PkmRom): seq[PkmMapLink] =
  let
    num = s.read (uint32).int
    listPtr = s.read (GBAPointer)
  if num > 4:
    raise newException (Exception, "Map cannot have more than 4 neighbouring maps.")

  discard s.seek (listPtr)
  result.newSeq (num)
  for d in result.mitems:
    d = s.readPkmMapLink()