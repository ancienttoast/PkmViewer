import
  streams, strutils, hashes, lz77

# From:
#   http://members.iinet.net.au/~freeaxs/gbacomp/#GBA Header
#
# GBA rom header
#   0x00 - 0x03 32 bit ARM B Jump to start of ROM executable
#   0x04 - 0x9F Nintendo Logo data
#   0xA0 - 0xAB Game Title
#   0xAC - 0xAF Game Code
#   0xB0 - 0xB1 Maker Code
#   0xB2 - 0xB2 0x96 Fixed
#   0xB3 - 0xB3 Main Unit Code
#   0xB4 - 0xB4 Device Type
#   0xB5 - 0xBB Reserved Area
#   0xBC - 0xBC Mask ROM Version
#   0xBD - 0xBD Compliment Check
#   0xBE - 0xBF Reserved Area

type
  GBAPointer* = distinct uint32


proc `$`* (s: GBAPointer): string =
  "0x" & s.int.toHex (8)

proc hash* (s: GBAPointer): Hash =
  hash (s.uint32)

proc `==`* (a, b: GBAPointer): bool =
  a.uint32 == b.uint32

template `+`* (a: GBAPointer, b: int): GBAPointer =
  (a.int + b).GBAPointer

template `-`* (a: GBAPointer, b: int): GBAPointer =
  (a.int - b).GBAPointer



type
  GBARom* = ref object {.inheritable.}
    stream: Stream


proc init* (s: GBARom, stream: Stream) =
  s.stream = stream

proc newGBARom* (data: string): GBARom =
  GBARom (stream: newStringStream (data))

proc newGBARom* (s: Stream): GBARom =
  GBARom (stream: s)


proc tell* (s: GBARom): GBAPointer =
  s.stream.getPosition().GBAPointer

proc seek*[T: GBARom] (s: T, pos: int): T =
  s.stream.setPosition (pos)
  s

proc seek*[T: GBARom] (s: T, pos: GBAPointer): T =
  s.seek (pos.int)


proc read* (s: GBARom, T: typedesc): auto =
  var
    temp: T
    r = s.stream.readData (addr temp, sizeof T)
  if r != sizeof T:
    raise newException (Exception, "Failed to read " & $(sizeof T) & " bytes.")
  temp

proc read* (s: GBARom, num: int, T: typedesc): auto =
  result = newSeq[T] (num)
  for e in result.mitems:
    e = s.read (T)

proc read*[T] (s: GBARom, num: int, f: proc (s: GBARom): T): seq[T] =
  result.newSeq (num)
  for e in result.mitems:
    e = s.f()

proc read*[K: string] (s: GBARom, num: int, T: typedesc[K]): K =
  s.stream.readStr (num)


proc read*[K: tuple] (s: GBARom, T: typedesc[K]): K =
  for f in result.fields:
    f = s.read (type f)

proc read*[K: array] (s: GBARom, T: typedesc[K]): K =
  for f in result.mitems:
    f = s.read (type f)


proc read* (s: GBARom, T: typedesc[GBAPointer]): auto =
  result = (s.read (uint32) and 0x1ffffff).GBAPointer
  #if result.int == 0x71a7dc: raise newException (Exception, $result)


proc decompressLZ77* (s: GBARom): seq[uint8] =
  s.stream.decompressLZ77()


proc title* (s: GBARom): string =
  s.seek (0xa0).stream.readStr (12)

proc code* (s: GBARom): string =
  s.seek (0xac).stream.readStr (4)

proc maker* (s: GBARom): string =
  s.seek (0xb0).stream.readStr (2)

proc revision* (s: GBARom): int =
  s.seek (0xbc).read (uint8).int