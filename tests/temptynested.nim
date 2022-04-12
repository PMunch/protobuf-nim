# From bug #23
import "../src/protobuf"
import streams
import strutils

const protoSpec = """
syntax = "proto3";

message Example2 {}

message Example {
    message ExampleNested {}
}

message Example3{
  int32 aField = 1;
  message Child{}
}

"""
parseProto(protoSpec)

var
  a = new Example_ExampleNested
  b = new Example2
  c = new Example
  d = new Example3
  e = new Example3_Child
