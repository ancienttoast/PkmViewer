import
  streams, sequtils, tables, math,
  gba.lz77, gba.image, pkm.text,
  pkm.data, pkm.tileset, pkm.cart, pkm.render, pkm.types, pkm.world, pkm.link



import
  strutils, tga



proc toColor32(c: GbaColor): Color32 =
  (255.uint32 shl 24) + (c[0].uint32 shl 16) + (c[1].uint32 shl 8) + c[2].uint32

proc writeTga(s: Stream, bitmap: GbaBitmap) =
  var
    width  = bitmap.width * GbaTileSize
    height = bitmap.height * GbaTileSize
    image = Image(width: width, height: height,
      kind: ikTruecolor, tPixels: newSeq[Color32](width * height))

  # flip the image on the y axis
  var
    x = 0
    y = height - 1
  for c in bitmap.pixels:
    image.tPixels[y*width + x] = c.toColor32

    x += 1
    if x >= width:
      x = 0
      y -= 1

  s.writeTga (image)





#[

Local tileset positions:

  3.0 (0x00350618): 0x002A28C8 - 0x002A2E58 (89 db)
  3.3: 0x002A3D54 - 0x002A45B4 (134 db)


  551a8: 34ebfc -> 71bd5c
  55260: 352718 -> 71af4c

  71B23C
  71B648

]#

const
  numberOfBanks = 42


import
  os



var
  Bank = 3
  Map  = 10

let
  args = commandLineParams()

if args.len >= 1:
  Bank = parseInt(args[0].split('.')[0])
  Map  = parseInt(args[0].split('.')[1])

let
  file = "Pokemon - Fire Red Version (U) (V1.0).gba"
  r = loadPkmRom(newFileStream(file))

echo r.title, " - ", r.code, " rev", r.revision
echo ""



let
  #world = r.readPkmWorld()

  bankPointer   = r.seek(r.gameData.mapHeaders).read(GBAPointer)
  bankPointers  = r.seek(bankPointer).read(r.gameData.numBanks, GBAPointer)
  b3MapPointers = r.seek(bankPointers[Bank].int).read(r.gameData.bankMapNums[Bank], GBAPointer)

  b3 = r.seek(bankPointers[Bank]).readPkmBank(r.gameData.bankMapNums[Bank])

  b3m0 = b3[0]
  b3m19 = b3[19]





import
  sdl2



type
  SdlTile = tuple
    texture: TexturePtr
    rect: sdl2.Rect

  SdlTilemap = object
    surfaces: array[PkmTilesetKind, sdl2.SurfacePtr]
    textures: array[PkmTilesetKind, sdl2.TexturePtr]

    tiles: seq[SdlTile]


proc toSdlSurface(s: GbaBitmap): sdl2.SurfacePtr =
  let
    pixelWidth = s.widthInPixels
  sdl2.createRGBSurfaceFrom(unsafeAddr s.pixels[0], pixelWidth.cint, s.heightInPixels.cint, 24,
    (pixelWidth * 3).cint, 0x000000ff'u32, 0x0000ff00'u32, 0x00ff0000'u32, 0x00000000'u32)

proc initSdlTilemap(s: PkmRenderedTileset, rend: sdl2.RendererPtr): SdlTilemap =
  result = SdlTilemap()

  result.surfaces[tkPrimary] = s.global.bitmap.toSdlSurface()
  result.surfaces[tkLocal]   = s.local.bitmap.toSdlSurface()

  result.textures[tkPrimary] = rend.createTextureFromSurface(result.surfaces[tkPrimary])
  result.textures[tkLocal]   = rend.createTextureFromSurface(result.surfaces[tkLocal])

  result.tiles.newSeq(s.global.tiles.len + s.local.tiles.len)
  var
    i = 0
  for t in s.global.tiles:
    result.tiles[i] = (
      texture: result.textures[tkPrimary],
      rect: (x: t[0].cint, y: t[1].cint, w: PkmBlockSize.cint, h: PkmBlockSize.cint)
    )
    i += 1

  for t in s.local.tiles:
    result.tiles[i] = (
      texture: result.textures[tkLocal],
      rect: (x: t[0].cint, y: t[1].cint, w: PkmBlockSize.cint, h: PkmBlockSize.cint)
    )
    i += 1


proc tile*(s: PkmMap, ts: SdlTilemap, x, y: int): SdlTile =
  var
    t = s.tiles[y*s.size[0].int + x].num
  if t > ts.tiles.high:
    ts.tiles[0]
  else:
    ts.tiles[t]


proc draw(rend: sdl2.RendererPtr, map: PkmMap, ts: SdlTilemap, xPos, yPos, scale: float) =
  for y in 0 ..< map.size[1].int:
    for x in 0 ..< map.size[0].int:
      var
        t = map.tile(ts, x, y)
        dst = (
          x: ((-xPos * scale) + x.float * PkmBlockSize * scale).floor.cint,
          y: ((-yPos * scale) + y.float * PkmBlockSize * scale).floor.cint,
          w: (PkmBlockSize * scale).floor.cint,
          h: (PkmBlockSize * scale).floor.cint
        )
      rend.copy(t.texture, addr t.rect, addr dst)


var
  done = newSeq[int]()
proc draw (rend: sdl2.RendererPtr, ts: TableRef[int64, SdlTilemap], map: int, world: PkmMapBank, xPos, yPos, scale: float) =
  let
    current = world[map]
  rend.draw(current, ts[current.tileset.id], xPos, yPos, scale)

  for link in current.links:
    if link.bank != 3:
      continue

    if link.map in done:
      continue

    #if link.direction == ldLeft or link.direction == ldRight:
    #  continue

    done.add(link.map)
    let
      x =
        case link.direction
        of ldLeft:  xPos + world[link.map].size[0].float*16
        of ldRight: xPos - current.size[0].float*16
        else:       xPos - link.offset.float*16
      y =
        case link.direction
        of ldDown: yPos - current.size[1].float*16
        of ldUp:   yPos + world[link.map].size[1].float*16
        else:      yPos - link.offset.float*16
    rend.draw(ts, link.map, world, x, y, scale)





sdl2.init(INIT_VIDEO)

let
  window = sdl2.createWindow("Pkm", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1280, 720, SDL_WINDOW_SHOWN)
  rend   = sdl2.createRenderer(window, -1, RENDERER_ACCELERATED or RENDERER_PRESENTVSYNC)

  sdlTilemaps = newTable[int64, SdlTilemap]()

for id, ts in r.tilesetCache.pairs:
  sdlTilemaps[id] = ts.initSdlTilemap(rend)

const
  ScrollSpeed = 11
var
  xPos  = 0.0
  yPos  = 0.0
  scale = 1.0

  running = true
  event   = defaultEvent
while running:
  while sdl2.pollEvent(event):
    case event.kind
    of QuitEvent:
      running = false

    of MouseMotion:
      let
        m = cast[MouseMotionEventPtr](addr event)
        state = sdl2.getMouseState(nil, nil)
      if (state and SDL_BUTTON(BUTTON_RIGHT)).int > 0:
        if m.xrel < 100:
          xPos -= m.xrel.float / scale
          yPos -= m.yrel.float / scale

    of KeyDown:
      let
        e = cast[KeyboardEventPtr](addr event)
      case e.keysym.scancode
      of SDL_SCANCODE_ESCAPE:
        running = false

      of SDL_SCANCODE_KP_PLUS:
        scale += 0.2
      of SDL_SCANCODE_KP_MINUS:
        scale -= 0.2

      of SDL_SCANCODE_UP:
        yPos += ScrollSpeed
      of SDL_SCANCODE_DOWN:
        yPos -= ScrollSpeed
      of SDL_SCANCODE_LEFT:
        xPos += ScrollSpeed
      of SDL_SCANCODE_RIGHT:
        xPos -= ScrollSpeed

      else:
        discard

    else:
      discard

  rend.setDrawColor(52, 52, 52)
  rend.clear()

  rend.draw(sdlTilemaps, 0, b3, xPos, yPos, scale)
  done = newSeq[int]()
  

  rend.present()