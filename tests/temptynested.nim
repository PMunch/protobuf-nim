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
"""
parseProto(protoSpec)

var
  a = new Example_ExampleNested
  b = new Example2
  c = new Example
