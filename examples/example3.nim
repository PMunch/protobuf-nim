import "../src/protobuf", streams
import strutils

const Printable = {' '..'~'}

proc echoDataStream(stream: Stream) =
  stream.setPosition(0)
  var
    pos = 0
    strRepr = "   "
  while not stream.atEnd:
    let num = stream.readUint8()
    stdout.write num.toHex() & " "
    strRepr.add if num.char in Printable: num.char else: '.'
    pos += 1
    if pos == 16:
      pos = 0
      echo strRepr
      strRepr = "   "
  echo "   ".repeat(16-pos) & strRepr
  stream.setPosition(0)

# Define our protobuf specification and generate Nim code to use it
const protoSpec = """
syntax = "proto3";

message ExampleMessage {
  int32 number = 1;
  int32 count = 2;
}
"""
parseProto(protoSpec)

# Create our message
var msg = new ExampleMessage
msg.number = 10
msg.count = 100

msg.reset(count)

var ss = newStringStream()

ss.write(msg, writeSize = true)
ss.echoDataStream

var readMsg = ss.readExampleMessage(maxSize = ss.protoReadInt64())
if readMsg.has(number):
  echo "Number: ", readMsg.number
if readMsg.has(count):
  echo "Count: ", readMsg.count
