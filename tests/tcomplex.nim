# From bug #35
import "../src/protobuf"
import streams

proc `$`(stream: Stream): string =
  stream.setPosition(0)
  while not stream.atEnd:
    let num = stream.readUint8()
    result.add num.toHex()
  stream.setPosition(0)

const testSpec = """
syntax = "proto3";

message Message {
  string name  = 1;
  string value = 2;
}

message NestedMessage {
  repeated Message content = 1;
}

message DoubleNestedMessage {
  NestedMessage body = 1;
}
"""
parseProto(testSpec)

var msg1 = new Message
msg1.name = "Hello"
msg1.value = "World"
var msg2 = new Message
msg2.name = "Foo"
msg2.value = "Bar"

var nmsg = new NestedMessage
nmsg.content = @[msg1, msg2]

var dnmsg = new DoubleNestedMessage
dnmsg.body = nmsg

var ds = newStringStream()
ds.write dnmsg
ds.setPosition 0

let dss = $ds
if dss != "0A1C0A0E0A0548656C6C6F1205576F726C640A0A0A03466F6F1203426172":
  echo dss
  for i, c in dss:
    if "0A1C0A0E0A0548656C6C6F1205576F726C640A0A0A03466F6F1203426172"[i] != c:
      stdout.write '^'
    else:
      stdout.write ' '
  echo ""
  quit 1

assert $ds == "0A1C0A0E0A0548656C6C6F1205576F726C640A0A0A03466F6F1203426172"
