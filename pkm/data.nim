import
  streams, parsecfg, tables, strutils

export
  `[]`



type
  PkmGameData* = tuple
    name: string

    engine: int

    mapHeaders: int
    numBanks: int
    bankMapNums: seq[int]

    mainTSBlocks: int
    mainTSSize: int
    mainTSHeight: int
    localTSBlocks: int
    localTSSize: int
    localTSHeight: int

  PkmDataStore = TableRef[string, PkmGameData]


proc parseArray (s: string): seq[int] =
  let
    parts = s.split (',')

  result = newSeq[int] (parts.len)
  for i, p in parts:
    result[i] = p.parseInt()


proc newPkmDataStore* (path: string): PkmDataStore =
  result = newTable[string, PkmGameData]()
  let
    f = newFileStream (path, fmRead)

  if f == nil:
    raise newException (Exception, "Could not find config file ('" & path & "').")
    
  var
    p: CfgParser
    game = ""
  p.open (f, path)
  while true:
    var
      e = p.next()
    case e.kind
    of cfgEof:
      break

    of cfgSectionStart:
      game = e.section
      var
        g: PkmGameData
      result.add (e.section, g)

    of cfgKeyValuePair:
      case e.key
      of "Name":
        result[game].name = e.value
      of "Engine":
        result[game].engine = e.value.parseInt

      of "MapHeaders":
        result[game].mapHeaders = e.value.parseHexInt
      of "NumBanks":
        result[game].numBanks = e.value.parseHexInt
      of "MapBankSize":
        result[game].bankMapNums = e.value.parseArray()
      
      of "MainTSBlocks":
        result[game].mainTSBlocks = e.value.parseHexInt
      of "MainTSSize":
        result[game].mainTSSize = e.value.parseHexInt
      of "MainTSHeight":
        result[game].mainTSHeight = e.value.parseHexInt
      of "LocalTSBlocks":
        result[game].localTSBlocks = e.value.parseHexInt
      of "LocalTSSize":
        result[game].localTSSize = e.value.parseHexInt
      of "LocalTSHeight":
        result[game].localTSHeight = e.value.parseHexInt
      else:
        discard

    of cfgOption:
      break

    of cfgError:
      echo (e.msg)

  p.close()





let
  dataStore* = newPkmDataStore ("MEH.ini")





#[
import
  tables, gba.rom


type
  PkmGameOffsets = tuple
    name: string

    engine: int

    banks:        int
    numBanks:     int
    bankMapSizes: seq[int]

    mainTSBlocks:  int
    mainTSSize:    int
    mainTSHeight:  int
    localTSBlocks: int
    localTSSize:   int
    localTSHeight: int

const
  PkmOffsets = {
    "BPRE": {
      0: (
        name:         "Pokemon FireRed (E)",

        engine:       1,

        banks:        0x5524C,
        numBanks:     0x21,
        bankMapSizes: @[5, 123, 60, 66, 4, 6, 8, 10, 6, 8, 20, 10, 8, 2, 10, 4, 2, 2, 2, 1, 1, 2, 2, 3, 2, 3, 2, 1, 1, 1, 1, 7, 5, 5, 8, 8, 5, 5, 1, 1, 1, 2, 1],

        mainTSBlocks:  0x280,
        mainTSSize:    0x280,
        mainTSHeight:  0x140,
        localTSBlocks: 0x56,
        localTSSize:   0x140,
        localTSHeight: 0xC0
      )
    }.toTable
  }.toTable



proc offsets* (s: GbaRom): PkmGameOffsets =
  let
    code = s.code
    rev  = s.revision
  if code notin PkmOffsets:
    raise newException (Exception, "Unrecognized game.")
  if rev notin PkmOffsets[code]:
    raise newException (Exception, "Unrecognized game revision.")
  PkmOffsets[code][rev]
]#