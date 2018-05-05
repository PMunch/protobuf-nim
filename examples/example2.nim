import "../src/protobuf", streams

# Define our protobuf specification and generate Nim code to use it
const protoSpec = """
syntax = "proto3";

message ExampleMessage {
  int32 number = 1;
  string text = 2;
  SubMessage nested = 3;
  message SubMessage {
    int32 a_field = 1;
  }
}
"""
parseProto(protoSpec)

# Create our message
var msg = new ExampleMessage
msg.number = 10
msg.text = "Hello world"
msg.nested = initExampleMessage_SubMessage(aField = 100)

# Write it to a stream
var stream = newStringStream()
stream.write msg

# Read the message from the stream and output the data if it's all present
stream.setPosition(0)
var readMsg = stream.readExampleMessage()
if readMsg.has(number, text, nested) and readMsg.nested.has(aField):
  echo readMsg.number
  echo readMsg.text
  echo readMsg.nested.aField
