import streams

when cpuEndian == littleEndian:
  proc hob(x: int64): uint =
    result = x.uint
    result = result or (result shr 1)
    result = result or (result shr 2)
    result = result or (result shr 4)
    result = result or (result shr 8)
    result = result or (result shr 16)
    result = result or (result shr 32)
    result = result - (result shr 1)

  proc getVarIntLen*(num: int | int64 | int32 | uint64 | uint32 | bool | enum): int =
    ## Get's the length a number would take when written with the protobuf
    ## VarInt encoding.
    result = 1
    var bits = num.uint64
    while bits > 0b0111_1111.uint64:
      result += 1
      bits = bits shr 7

  proc protoWriteInt64*(s: Stream, x: int64) =
    ## Writes the number ``x`` to a stream using the protobuf VarInt encoding
    var
      bytes = x.hob shr 7
      num = x
    s.write((num and 0x7f or (if bytes != 0: 0x80 else: 0)).uint8)
    while bytes != 0:
      num = num shr 7
      bytes = bytes shr 7
      s.write((num and 0x7f or (if bytes != 0: 0x80 else: 0)).uint8)

  proc protoReadInt64*(s: Stream): int64 =
    ## Reads a number from the stream using the protobuf VarInt encoding
    var
      byte: int64 = s.readInt8()
      i = 1
    result = byte and 0x7f
    while (byte and 0x80) != 0:
      # TODO: Add error checking for values not fitting 64 bits
      byte = s.readInt8()
      result = result or ((byte and 0x7f) shl (7*i))
      i += 1

  proc protoReadInt32*(s: Stream): int32 =
    ## Similar to the ``protoReadInt64`` procedure, but returns a 32-bit
    ## integer instead.
    s.protoReadInt64().int32

  proc protoWriteInt32*(s: Stream, x: int32) =
    ## Similar to the ``protoWriteInt64`` procedure, but takes a 32-bit
    ## integer instead.
    s.protoWriteInt64(x.int64)

  proc protoReadUint64*(s: Stream): uint64 =
    ## Similar to the ``protoReadInt64`` procedure, but returns a 64-bit
    ## unsigned integer instead.
    s.protoReadInt64().uint64

  proc protoWriteUint64*(s: Stream, x: uint64) =
    ## Similar to the ``protoWriteInt64`` procedure, but takes a 64-bit
    ## unsigned integer instead.
    s.protoWriteInt64(x.int64)

  proc protoReadUint32*(s: Stream): uint32 =
    ## Similar to the ``protoReadInt32`` procedure, but returns a 32-bit
    ## unsigned integer instead.
    s.protoReadInt64().uint32

  proc protoWriteUint32*(s: Stream, x: uint32) =
    ## Similar to the ``protoWriteInt32`` procedure, but takes a 32-bit
    ## unsigned integer instead.
    s.protoWriteInt64(x.int64)

  proc protoReadBool*(s: Stream): bool =
    ## Similar to the ``protoReadInt64`` procedure, but returns a 32-bit
    ## integer instead.
    s.protoReadInt64().bool

  proc protoWriteBool*(s: Stream, x: bool) =
    ## Similar to the ``protoWriteInt64`` procedure, but takes a 32-bit
    ## integer instead.
    s.protoWriteInt64(x.int64)

  proc protoWriteSint64*(s: Stream, x: int64) =
    ## Writes an integer using the protobuf ZigZag and VarInt encoding. Use
    ## this for signed numbers, the regular ``protoWriteInt64`` will always use
    ## 10 bytes when writing a negative number.
    # TODO: Ensure that this works for all int64 values
    var t = x * 2
    if x < 0:
      t = t xor -1
    s.protoWriteInt64(t)

  proc protoReadSint64*(s: Stream): int64 =
    ## Reads an integer using the protobuf ZigZag and VarInt encoding.
    let y = s.protoReadInt64()
    return ((y shr 1) xor (if (y and 1) == 1: -1 else: 0))

  proc protoWriteSint32*(s: Stream, x: int32) =
    ## Similar to the ``protoWriteSint64`` procedure, but takes a 32-bit
    ## integer instead.
    s.protoWriteSint64(x.int64)

  proc protoReadSint32*(s: Stream): int32 =
    ## Similar to the ``protoReadSint64`` procedure, but returns a 32-bit
    ## integer instead.
    s.protoReadSint64().int32

  proc protoWriteFixed64*(s: Stream, x: uint64) =
    ## A simple wrapper for writing 64-bit unsigned integers to a stream
    s.write(x)

  proc protoReadFixed64*(s: Stream): uint64 =
    ## A simple wrapper for reading 64-bit unsigned integers from a stream
    s.readUint64()

  proc protoWriteFixed32*(s: Stream, x: uint32) =
    ## A simple wrapper for writing 32-bit unsigned integers to a stream
    s.write(x)

  proc protoReadFixed32*(s: Stream): uint32 =
    ## A simple wrapper for reading 32-bit unsigned integers from a stream
    s.readUInt32()

  proc protoWriteSfixed64*(s: Stream, x: int64) =
    ## A simple wrapper for writing 64-bit signed integers to a stream
    s.write(x)

  proc protoReadSfixed64*(s: Stream): int64 =
    ## A simple wrapper for reading 64-bit signed integers from a stream
    s.readInt64()

  proc protoWriteSfixed32*(s: Stream, x: int32) =
    ## A simple wrapper for writing 32-bit signed integers to a stream
    s.write(x)

  proc protoReadSfixed32*(s: Stream): int32 =
    ## A simple wrapper for reading 32-bit signed integers from a stream
    s.readInt32()

  proc protoWriteString*(s: Stream, x: string) =
    ## Writes a string according to the protobuf specification. First the
    ## length of the string is written with VarInt encoding, then the string
    ## follow.
    s.protoWriteInt64(x.len)
    for c in x:
      s.write(c)

  proc protoReadString*(s: Stream): string =
    ## Reads a string according to the protobuf specification. See
    ## ``protoWriteString``
    result = newString(s.protoReadInt64())
    for i in 0..<result.len:
      result[i] = s.readChar()

  proc protoWriteBytes*(s: Stream, x: seq[uint8]) =
    ## Writes a string according to the protobuf specification. First the
    ## length of the byte sequence is written with VarInt encoding, then the
    ## bytes follow.
    s.protoWriteInt64(x.len)
    for c in x:
      s.write(c)

  proc protoReadBytes*(s: Stream): seq[uint8] =
    ## Reads a byte sequence according to the protobuf specification. See
    ## ``protoWriteBytes``
    result = newSeq[uint8](s.protoReadInt64())
    for i in 0..<result.len:
      result[i] = s.readUint8()

  proc protoWriteFloat*(s: Stream, x: float32) =
    ## A simple wrapper for writing 32-bit floats
    s.write(x)

  proc protoReadFloat*(s: Stream): float32 =
    ## A simple wrapper for reading 32-bit floats
    s.readFloat32()

  proc protoWriteDouble*(s: Stream, x: float64) =
    ## A simple wrapper for writing 64-bit floats
    s.write(x)

  proc protoReadDouble*(s: Stream): float64 =
    ## A simple wrapper for reading 64-bit floats
    s.readFloat64()
