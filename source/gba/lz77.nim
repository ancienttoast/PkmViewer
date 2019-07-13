import
  streams


proc decompressLZ77*(input: Stream): seq[uint8] =
  # Based on:
  #   https://github.com/Barubary/dsdecmp/blob/master/CSharp/DSDecmp/Program.cs
  #
  # Data header (32bit)
  #   Bit 0-3   Reserved
  #   Bit 4-7   Compressed type (must be 1 for LZ77)
  #   Bit 8-31  Size of decompressed data
  # Repeat below. Each Flag Byte followed by eight Blocks.
  # Flag data (8bit)
  #   Bit 0-7   Type Flags for next 8 Blocks, MSB first
  # Block Type 0 - Uncompressed - Copy 1 Byte from Source to Dest
  #   Bit 0-7   One data byte to be copied to dest
  # Block Type 1 - Compressed - Copy N+3 Bytes from Dest-Disp-1 to Dest
  #   Bit 0-3   Disp MSBs
  #   Bit 4-7   Number of bytes to copy (minus 3)
  #   Bit 8-15  Disp LSBs
  const
    MaxOutSize = 0xA00000

    LZ10Tag = 0x10
    LZ10BlockSize = 8

  var
    decomp_size = 0

  if input.readInt8() != LZ10Tag:
    raise newException(Exception, "Data is not a valid LZ-0x10 chunk.")

  for i in 0 ..< 3:
    decomp_size += input.readUint8().int shl (i * 8)

  if decomp_size > MaxOutSize:
    raise newException(Exception, "Data will be larger than " & $MaxOutSize & " (" & $decomp_size & ") and will not be decompressed.")
  elif decomp_size == 0:
    for i in 0 ..< 4:
      decomp_size += input.readInt8() shl (i * 8)
    
    if decomp_size > MaxOutSize shl 8:
      raise newException(Exception, "Data will be larger than " & $MaxOutSize & " (" & $decomp_size & ") and will not be decompressed.")

  var
    curr_size = 0
  result.newSeq(decomp_size)

  while curr_size < decomp_size:
    let
      flags = input.readInt8()
    for i in 0 ..< LZ10BlockSize:
      let
        flag = (flags and (0x80 shr i)) > 0
      if flag:
        let
          b = input.readUint8()
          n = 3 + (b shr 4).int

          disp = ((b.int and 0x0F) shl 8) or input.readUint8().int
          cdest = curr_size

        if disp > curr_size:
          raise newException(Exception, "Cannot go back more than already written")
        for j in 0 ..< n:
          result[curr_size] = result[cdest - disp - 1 + j]
          curr_size += 1

      else:
        result[curr_size] = input.readUint8()
        curr_size += 1

      if curr_size >= decomp_size:
        break