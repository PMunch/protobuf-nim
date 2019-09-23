import "../src/protobuf"
import streams

# Some simple tests of the writing primitives
var stream = newStringStream()
stream.protoWriteInt64 0
assert(stream.getPosition == 1, "Wrote more than 1 byte for the value 0")
stream.setPosition(0)
assert(stream.protoReadInt64() == 0, "Read a different value than 0 for the value 0")
stream.setPosition(0)
stream.protoWriteInt64 128
assert(stream.getPosition == 2, "Wrote more or less than 2 bytes for the value 128")
stream.setPosition(0)
assert(stream.protoReadInt64() == 128, "Read a different value than 128 for the value 128")
stream.setPosition(0)
stream.protoWriteInt64 -128
assert(stream.getPosition == 10, "Wrote more or less than 10 bytes for the value -128")
stream.setPosition(0)
assert(stream.protoReadInt64() == -128, "Read a different value than -128 for the value -128")
stream.setPosition(0)
stream.protoWriteSint64 0
assert(stream.getPosition == 1, "Wrote more or less than 1 bytes for the value 0")
stream.setPosition(0)
assert(stream.protoReadSint64().int64 == 0, "Read a different value than 0 for the value 0")
stream.setPosition(0)
stream.protoWriteSint64 128
assert(stream.getPosition == 2, "Wrote more or less than 2 bytes for the value 128")
stream.setPosition(0)
assert(stream.protoReadSint64().int64 == 128, "Read a different value than 128 for the value 128")
stream.setPosition(0)
stream.protoWriteSint64 (-128)
assert(stream.getPosition == 2, "Wrote more or less than 2 bytes for the value -128")
stream.setPosition(0)
assert(stream.protoReadSint64().int64 == -128, "Read a different value than -128 for the value -128")
echo "All good!"
