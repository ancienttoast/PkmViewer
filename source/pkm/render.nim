import
  math, streams,
  gba/image,
  pkm/[cart, data, tileset, types]



proc maxBy[T; U](values: openarray[T], f: proc (x: T): U): U =
  result = f(values[0])
  for v in values:
    let
      a = f(v)
    if a > result:
      result = a

proc renderTileset*(s: PkmRom, global, local: PkmTileset, kind: PkmTilesetKind, width = 8): PkmRenderedTilesetData =
  let
    ts = if kind == tkPrimary: global else: local

  result = (
    bitmap: initGbaBitmap(width*2, (ts.blocks.len / width).ceil.int * 2),
    tiles: newSeq[Point](ts.blocks.len)
  )

  var
    x = 0
    y = 0
  for i, b in ts.blocks:
    for t in b:
      let
        # TODO: Seems to work but why?
        palette = if t.palette > 7: local.palettes[t.palette] else: global.palettes[t.palette]

      if t.num > s.gameData.mainTSSize:
        result.bitmap.copyTile(x*2 + t.x, y*2 + t.y, ts.image, t.num - s.gameData.mainTSSize, palette, t.xFlip, t.yFlip)
      else:
        result.bitmap.copyTile(x*2 + t.x, y*2 + t.y, global.image, t.num, palette, t.xFlip, t.yFlip)
    result.tiles[i] = [(x*2) * GbaTileSize, (y*2) * GbaTileSize]

    x += 1
    if x == result.bitmap.width div 2:
      x = 0
      y += 1

proc renderTileset*(s: PkmRom, global, local: PkmTileset, width = 8): PkmRenderedTileset =
  PkmRenderedTileset(
    id: (global.offset.int64 shl 32) + local.offset.int64,
    global: s.renderTileset(global, local, tkPrimary, width),
    local: s.renderTileset(global, local, tkLocal, width)
  )