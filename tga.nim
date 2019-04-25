##[

  Format specification: http://www.dca.fee.unicamp.br/~martino/disciplinas/ea978/tgaffs.pdf

]##
import streams, endians



proc littleEndian[T: uint16 | int16](value: T): T =
  littleEndian16(addr result, unsafeAddr value)


type
  Color8*  = uint8
  Color16* = uint16
  Color24* = array[3, char]
  Color32* = uint32


  ImageKind* = enum
    ikGreyscale
    ikTruecolor
    ikColormap


  Image* = ref object
    width*:  int
    height*: int

    case kind*: ImageKind
    of ikGreyscale:
      gPixels*: seq[Color8]
    of ikTruecolor:
      tPixels*: seq[Color32]
    of ikColormap:
      cPixels*: seq[Color8]
      cColormap*: string


  TgaKind = enum
    tkBlank        = 0
    tkColorMap     = 1
    tkTrueColor    = 2
    tkGreyscale    = 3
    tkRleColorMap  = 9
    tkRleTrueColor = 10
    tkRleGreyscale = 11

const
  TGA_RLE_KIND = {tkRleColorMap, tkRleTrueColor, tkRleGreyscale}




proc rleDecode(s: Stream, T: typedesc, size: int): seq[T] =
  proc read[U](s: Stream): U =
    discard s.readData(addr result, U.sizeof)

  result = newSeq[T](size)
  var i = 0
  while i < size:
    let
      header = s.readInt8()

      kind   = (header and 0b10000000) != 0
      length = (header and 0b01111111).ze + 1

    if kind:
      let d = read[T](s)
      for j in i..<i+length:
        result[j] = d
    else:
      for j in i..<i+length:
        result[j] = read[T](s)

    i += length



proc rleEncode(s: Stream, T: typedesc, data: seq[T], width, height: int) =
  proc findPacket(data: seq[T], i: int): tuple[size: int, header: uint8] =
    var j = 1
    while i+j < data.high and (i+j) mod width != 0 and j < 128 and data[i] == data[i+j]:
      j += 1
    (j, if j == 1: 0b00000000'u8 else: (0b10000000 or (j-1)).uint8)

  var i = 0
  while i < data.high:
    let (size, header) = findPacket(data, i)

    s.write(header)
    s.write(data[i])
    i += size



proc to32(r, g, b, a: Color8): Color32 =
  (a.Color32 shl 24) or (r.Color32 shl 16) or (g.Color32 shl 8) or (b.Color32)

proc conv24To32(data: seq[Color24]): seq[Color32] =
  result.newSeq(data.len)
  for i, p in data:
    result[i] = to32(p[2].Color8, p[1].Color8, p[0].Color8, 0xff.Color8)

proc conv16To32(data: seq[Color16]): seq[Color32] =
  result.newSeq(data.len)
  for i, p in data:
    const
      mult = (255 / 31).uint16
    let
      b =  ((p and 0x1f) * mult).Color8
      g = (((p and 0x3e0) shr 5) * mult).Color8
      r = (((p and 0x7c00) shr 10) * mult).Color8
      a =  ((p shr 15) * 255).Color8
    result[i] = to32(r, g, b, a)


proc readSeq(s: Stream, T: typedesc, size: int): seq[T] =
  result.newSeq(size)
  discard s.readData(addr result[0], T.sizeof * size)

proc handleGreyscale(s: Stream, size: int, rle: bool): seq[Color8] =
  if rle: s.rleDecode(Color8, size)
  else:   s.readSeq(Color8, size)

proc handleColorMapped(s: Stream, size: int, rle: bool): seq[Color8] =
  if rle: s.rleDecode(Color8, size)
  else:   s.readSeq(Color8, size)

proc handleTruecolor(s: Stream, size: int, depth: int, rle: bool): seq[Color32] =
  assert depth in {16, 24, 32}, "Unsupported depth '" & $depth & "'."
  if depth == 24:
    if rle: s.rleDecode(Color24, size).conv24To32
    else:   s.readSeq(Color24, size).conv24To32
  elif depth == 16:
    if rle: s.rleDecode(Color16, size).conv16To32
    else:   s.readSeq(Color16, size).conv16To32
  else:
    if rle: s.rleDecode(Color32, size)
    else:   s.readSeq(Color32, size)



proc readTga*(s: Stream): Image =
  # Header
  let
    idLength = s.readUint8().int
    mapKind = s.readUint8().int
    kind = try: s.readUint8().TgaKind except RangeError: assert false, "Invalid tga type"; tkBlank
  assert mapKind in {0, 1}, "Invalid color-map type"

  # Color map specification
  let
    firstEntry = s.readInt16().littleEndian()
    mapLength = s.readUint16().littleEndian().int
    entryBits = s.readUint8().int
  if mapKind == 1:
    assert entryBits in {16, 24, 32}, "Only 16, 24 and 32 bits are supported per color-map entry"

  # Image specification
  discard s.readInt16().littleEndian() # xOrigin
  discard s.readInt16().littleEndian() # yOrigin
  let
    width      = s.readUint16().littleEndian().int
    height     = s.readUint16().littleEndian().int
    pixelDepth = s.readUint8().int
  discard s.readUint8() # descriptor

  # Optional field containing identifying information
  discard s.readStr(idLength)

  # Look-up table containing color map data
  # we load it because not every stream supports setPosition
  let
    colormap = s.readStr(mapLength * (entryBits div 8))

  # Image data
  case kind
  of tkGreyscale, tkRleGreyscale:
    result = Image(
      width: width, height: height,
      kind: ikGreyscale,
      gPixels: s.handleGreyscale(width * height, kind in TGA_RLE_KIND))
  of tkTrueColor, tkRleTrueColor:
    result = Image(
      width: width, height: height,
      kind: ikTruecolor,
      tPixels: s.handleTruecolor(width * height, pixelDepth, kind in TGA_RLE_KIND))
  of tkColorMap, tkRleColorMap:
    result = Image(
      width: width, height: height,
      kind: ikColormap,
      cColormap: colormap,
      cPixels: s.handleColorMapped(width * height, kind in TGA_RLE_KIND))
  of tkBlank:
    result = Image(
      width: width, height: height,
      kind: ikGreyscale,
      gPixels: newSeq[Color8]()
    )



proc writeTga*(s: Stream, i: Image, rle: bool = false) =
  s.write(0'u8)
  s.write(0'u8)
  s.write(
    if i.kind == ikGreyscale:
      if rle: tkRleGreyscale.uint8
      else:   tkGreyscale.uint8
    else:
      if rle: tkRleTrueColor.uint8
      else:   tkTrueColor.uint8)

  s.write(0'u16)
  s.write(0'u16)
  s.write(0'u8)

  s.write(0'u16)
  s.write(0'u16)
  s.write(i.width.uint16)
  s.write(i.height.uint16)

  s.write(
    if i.kind == ikGreyscale: 8'u8
    else: 32'u8)
  s.write(0'u8)

  if i.kind == ikGreyscale:
    if rle: s.rleEncode(Color8, i.gPixels, i.width, i.height)
    else:   s.writeData(addr i.gPixels[0], i.gPixels.len)
  else:
    if rle: s.rleEncode(Color32, i.tPixels, i.width, i.height)
    else:   s.writeData(addr i.tPixels[0], i.tPixels.len * Color32.sizeof)