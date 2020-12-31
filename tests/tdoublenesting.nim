# From bug #23
import "../src/protobuf"
import streams

const protoSpec = """
syntax = "proto3";

message Example2 {
    int32 field1 = 1;
}

message Example {
    message ExampleNested {
        Example2 example2 = 1;
    }
    ExampleNested exampleNested = 1;
}
"""
parseProto(protoSpec)

var msg = new Example
msg.exampleNested = initExample_ExampleNested()
let example2 = initExample2(field1 = 123)
msg.exampleNested.example2 = example2

var strm = newStringStream()
strm.write(msg)
strm.setPosition(0)
assert strm.readAll == "\x0a\x04\x0a\x02\x08\x7b"
