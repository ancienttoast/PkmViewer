import
  gba/image



type
  PkmTilesetKind* = enum
    tkPrimary
    tkLocal


  PkmRenderedTilesetData* = tuple
    bitmap: GbaBitmap
    tiles: seq[Point]

  PkmRenderedTileset* = ref object
    id*: int64
    global*: PkmRenderedTilesetData
    local*: PkmRenderedTilesetData