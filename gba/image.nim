import
  strutils, gba.rom



type
  Point* = array[2, int]

  GbaColor* = array[3, uint8]
  GbaPalette* = array[16, GbaColor]

  GbaImage* = seq[uint8]


const
  GbaTileSize* = 8

  GreayscalePalette* = [
    [0'u8,   0,   0],
    [16'u8,  16,  16],
    [32'u8,  32,  32],
    [48'u8,  48,  48],
    [64'u8,  64,  64],
    [80'u8,  80,  80],
    [96'u8,  96,  96],
    [112'u8, 112, 112],
    [128'u8, 128, 128],
    [144'u8, 144, 144],
    [160'u8, 160, 160],
    [176'u8, 176, 176],
    [192'u8, 192, 192],
    [208'u8, 208, 208],
    [224'u8, 224, 224],
    [240'u8, 240, 240]
  ]



proc `$`*(s: GbaColor): string =
  "#" & s[0].int.toHex(2) & s[1].int.toHex(2) & s[2].int.toHex(2)
  #"(" & $s[0] & ", " & $s[1] & ", " & $s[2] & ")"

proc `$`*(s: GbaPalette): string =
 result = "["
 for i in 0 .. 14:
  result &= $s[i] & ", "
 result &= $s[15] & "]"



##########################################################################################
#
#  Color conversion
#
##########################################################################################
proc rgbToGba*(c: GbaColor): uint16 =
  ## Converts rgb colors to the gba format (15-bit RGB).
  ##
  ## Based on:
  ##   http://www.pokecommunity.com/showpost.php?p=8892189&postcount=4
  ((((c[0] shr 3) and 31) or
    (((c[1] shr 3) and 31) shl 5) or
    (((c[2] shr 3) and 31) shl 10))).uint16

proc gbaToRgb*(c: uint16): GbaColor =
  ## Converts gba formatted (15-bit RGB) colors to 8bpp rgb .
  ##
  ## Based on:
  ##   http://www.pokecommunity.com/showpost.php?p=8892189&postcount=4
  [
    ((c and 31) shl 3).uint8,
    (((c shr 5) and 31) shl 3).uint8,
    (((c shr 10) and 31) shl 3).uint8
  ]



##########################################################################################
#
#  Reading procs
#
##########################################################################################
proc readGbaPalette*(s: GBARom, compressed = true): GbaPalette =
  let
    buffer =
      if compressed: s.decompressLZ77()
      else:          s.read(32, uint8)
  if buffer.len != 32:
    raise newException(Exception, "Invalid size for palette.")

  for i in 0 ..< 16:
    result[i] = gbaToRgb(buffer[i*2].uint16 + (buffer[i*2 + 1].uint16 shl 8))


proc readGbaImage*(s: GBARom): GbaImage =
  s.decompressLZ77()

proc readGbaImage*(s: GBARom, size: int): GbaImage =
  s.read(size, uint8)





type
  GbaBitmap* = object
    width*:  int
    height*: int
    pixels*: seq[GbaColor]


proc initGbaBitmap*(width, height: int): GbaBitmap =
  GbaBitmap(
    width: width,
    height: height,
    pixels: newSeq[GbaColor](width*GbaTileSize * height*GbaTileSize)
  )


template widthInPixels*(s: GbaBitmap): int =
  s.width * GbaTileSize

template heightInPixels*(s: GbaBitmap): int =
  s.height * GbaTileSize


template pixelCoords*(s: GbaBitmap, offset: int): array[2, int] =
  let
    w = s.widthInPixels
    y = offset div w
  [offset - y*w, y]


proc copyTile*(s: var GbaBitmap, x, y: int, image: GbaImage, tile: int, palette: GbaPalette, flipX = false, flipY = false, transparency = true) =
  proc flip(x, y: int, w, h: int, flipX, flipY: bool): array[2, int] =
    [if flipX: w - 2 - x else: x, if flipY: h - 1 - y else: y]

  let
    pixelWidth = s.widthInPixels
    pixelHeight = s.heightInPixels

    pixelX = x * GbaTileSize
    pixelY = y * GbaTileSize

  var
    i = tile * (GbaTileSize*GbaTileSize div 2)
  for nY in 0 ..< GbaTileSize:
    for j in 0 ..< GbaTileSize div 2:
      if i > image.high:
        continue
        #TODO: FR 3.7:
        # raise newException (Exception, "Requesting pixel #" & $i & " from image with " & $image.len & " pixels.")
      let
        p =
          if flipX: [(image[i].int and 0xf0) shr 4, (image[i].int and 0x0f).int]
          else:     [(image[i].int and 0x0f).int, (image[i].int and 0xf0) shr 4]

        pos = flip(j*2, nY, GbaTileSize, GbaTileSize, flipX, flipY)
        offset = (pixelY + pos[1])*pixelWidth + pixelX + pos[0]

      if offset + 1 > s.pixels.len:
        i += 1
        raise newException(Exception, "Trying to set pixel #" & $(offset + 1) & " of bitmap with " & $s.pixels.len & " pixels.")
      if not transparency or p[0] != 0:
        s.pixels[offset + 0] = palette[p[0]]
      if not transparency or p[1] != 0:
        s.pixels[offset + 1] = palette[p[1]]

      i += 1