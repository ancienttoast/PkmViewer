{.push hint[XDeclaredButNotUsed]: off.}

import streams



type
  Color8*  = uint8
  Color16* = uint16
  Color24* = array[3, char]
  Color32* = uint32


  ImageKind* = enum
    ikGreyscale
    ikTruecolor


  Image* = ref object
    width*:  int
    height*: int

    case kind*: ImageKind
    of ikGreyscale:
      gPixels*: seq[Color8]
    of ikTruecolor:
      tPixels*: seq[Color32]


  TgaKind = enum
    tkBlank        = 0
    tkColorMap     = 1
    tkTrueColor    = 2
    tkGreyscale    = 3
    tkRleColorMap  = 9
    tkRleTrueColor = 10
    tkRleGreyscale = 11




proc rleDecode (s: Stream, T: typedesc, size: int): seq[T] =
  proc read[U] (s: Stream): U =
    discard s.readData (addr result, U.sizeof)

  result = newSeq[T] (size)
  var i = 0
  while i < size:
    let
      header = s.readInt8()

      kind   = (header and 0b10000000) != 0
      length = (header and 0b01111111).ze + 1

    if kind:
      let d = read[T] (s)
      for j in i.. <i+length:
        result[j] = d
    else:
      for j in i.. <i+length:
        result[j] = read[T] (s)

    i += length


import strutils

# TODO: Does not work
proc rleEncode (T: typedesc, data: seq[T], width, height: int): string =
  proc findPacket (data: seq[T], i: int, equal: bool): tuple[slice: Slice[int], size: int, header: uint8] =
    let
      op = if equal: proc (a, b: T): bool = a == b else: proc (a, b: T): bool = a != b
      d = data[i]

    var j = 1
    while i+j < data.high and i+j < i*height + width and j < 128 and
          op (d, data[i+j]):
      j += 1

    result =
      if equal:
        (i..i, j, (0b10000000 or (j-1)).uint8)
      else:
        (i..i+j, j, (0b00000000 or (j-1)).uint8)

  let
    s = newStringStream ("")

  var i = 0
  while i < data.high:
    let (slice, size, header) = findPacket (data, i, data[i] == data[i+1])

    s.write (header)
    for d in data[slice]: s.write (d)

    i += size

  let size = s.getPosition()
  s.setPosition (0)
  result = s.readStr (size)



proc to32 (r, g, b, a: Color8): Color32 =
  (a.Color32 shl 24) or (r.Color32 shl 16) or (g.Color32 shl 8) or (b.Color32)

proc conv24To32 (data: seq[Color24]): seq[Color32] =
  result.newSeq (data.len)
  for i, p in data:
    result[i] = to32 (p[2].Color8, p[1].Color8, p[0].Color8, 0xff.Color8)

proc conv16To32 (data: seq[Color16]): seq[Color32] =
  result.newSeq (data.len)
  for i, p in data:
    const
      mult = (255 / 31).uint16
    let
      b =  ((p and 0x1f) * mult).Color8
      g = (((p and 0x3e0) shr 5) * mult).Color8
      r = (((p and 0x7c00) shr 10) * mult).Color8
      a =  ((p shr 15) * 255).Color8
    result[i] = to32 (r, g, b, a)


proc readSeq (s: Stream, T: typedesc, size: int): seq[T] =
  result.newSeq (size)
  discard s.readData (addr result[0], T.sizeof * size)

proc handleGreyscale (s: Stream, size: int, rle: bool): seq[Color8] =
  if rle: s.rleDecode (Color8, size)
  else:   s.readSeq (Color8, size)

proc handleTruecolor (s: Stream, size: int, depth: int, rle: bool): seq[Color32] =
  if depth != 16 and depth != 24 and depth != 32:
    raise newException (Exception, "Unsupported depth '" & $depth & "'.")

  if depth == 24:
    if rle: s.rleDecode (Color24, size).conv24To32
    else:   s.readSeq (Color24, size).conv24To32
  elif depth == 16:
    if rle: s.rleDecode (Color16, size).conv16To32
    else:   s.readSeq (Color16, size).conv16To32
  else:
    if rle: s.rleDecode (Color32, size)
    else:   s.readSeq (Color32, size)



proc readTga* (s: Stream): Image =
  # Header
  let
    idLength   = s.readChar().int
    mapKind    = s.readChar().int
    kind       = s.readChar().TgaKind

    # Color map specification
    firstEntry = s.readInt16().ze
    mapLength  = s.readInt16().ze
    entrySize  = s.readChar().int

    # Image specification
    xOrigin    = s.readInt16().ze
    yOrigin    = s.readInt16().ze
    width      = s.readInt16().ze
    height     = s.readInt16().ze

    pixelDepth = s.readChar().int
    descriptor = s.readChar().int

    # Optional field containing identifying information
    id = s.readStr (idLength)

  # Look-up table containing color map data
  # we load it because not every stream supports setPosition
  discard s.readStr (mapLength)

  # Image data
  case kind
  of tkGreyscale, tkRleGreyscale:
    result = Image (width: width, height: height,
                    kind: ikGreyscale,
                    gPixels: s.handleGreyscale (width * height, kind == tkRleGreyscale))
  of tkTrueColor, tkRleTrueColor:
    result = Image (width: width, height: height,
                    kind: ikTruecolor,
                    tPixels: s.handleTruecolor (width * height, pixelDepth, kind == tkRleTrueColor))
  of tkColorMap, tkRleColorMap:
    raise newException (Exception, "Colormap not supported: " & $kind)
  of tkBlank:
    raise newException (Exception, "Blank images are not supported: " & $kind)



proc writeTga* (s: Stream, i: Image, rle: bool = false) =
  s.write (0'u8)
  s.write (0'u8)
  s.write (
    if i.kind == ikGreyscale:
      if rle: tkRleGreyscale.uint8
      else:   tkGreyscale.uint8
    else:
      if rle: tkRleTrueColor.uint8
      else:   tkTrueColor.uint8)

  s.write (0'u16)
  s.write (0'u16)
  s.write (0'u8)

  s.write (0'u16)
  s.write (0'u16)
  s.write (i.width.uint16)
  s.write (i.height.uint16)

  s.write (
    if i.kind == ikGreyscale: 8'u8
    else: 32'u8)
  s.write (0'u8)

  if i.kind == ikGreyscale:
    if rle: s.write (rleEncode (Color8, i.gPixels, i.width, i.height))
    else:   s.writeData (addr i.gPixels[0], i.gPixels.len)
  else:
    if rle: s.write (rleEncode (Color32, i.tPixels, i.width, i.height))
    else:   s.writeData (addr i.tPixels[0], i.tPixels.len * Color32.sizeof)




when isMainModule:
  import os

  proc test (path: string, compress: bool = false) =
    let
      m = if compress: ".rle." else: ""
      o = "out." & m & path.extractFilename
      a = path.newFileStream (fmRead).readTga()
    o.newFileStream (fmWRite).writeTga (a, compress)

  "tests/8b.tga".test()
  "tests/8b-rle.tga".test()
  "tests/16b.tga".test()
  "tests/16b-rle.tga".test()
  "tests/24b.tga".test()
  "tests/24b-rle.tga".test()
  "tests/32b.tga".test()
  "tests/32b-rle.tga".test()


{.pop.}