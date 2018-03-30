## This is a pure Nim implementation of protobuf, meaning that it doesn't rely
## on the ``protoc`` compiler. The entire implementation is based on a macro
## that takes in either a string or a file containing the proto3 format as
## specified at https://developers.google.com/protocol-buffers/docs/proto3. It
## then produces procedures to read, write, and calculate the length of a
## message, along with types to hold the data in your Nim program. The data
## types are intended to be as close as possible to what you would normally use
## in Nim, making it feel very natural to use these types in your program in
## contrast to some protobuf implementations. The entire read/write structure is
## built on top of the Stream interface from the ``streams`` module, meaning it
## can be used directly with anything that uses streams.
##
## Example
## -------
## To wet your appetite the following example shows how this protobuf macro can
## be used to generate the required code and read and write protobuf messages.
## This example can also be found in the examples folder. Note that it is also
## possible to read in the protobuf specification from a file.
##
## .. code-block:: nim
##
##   import protobuf, streams
##
##   # Define our protobuf specification and generate Nim code to use it
##   const protoSpec = """
##   syntax = "proto3";
##
##   message ExampleMessage {
##     int32 number = 1;
##     string text = 2;
##     SubMessage nested = 3;
##     message SubMessage {
##       int32 a_field = 1;
##     }
##   }
##   """
##   parseProto(protoSpec)
##
##   # Create our message
##   var msg: ExampleMessage
##   msg.number = 10
##   msg.text = "Hello world"
##   msg.nested = ExampleMessage_SubMessage(aField: 100)
##
##   # Write it to a stream
##   var stream = newStringStream()
##   stream.write msg
##
##   # Read the message from the stream and echo out the data
##   stream.setPosition(0)
##   var readMsg = stream.readExampleMessage()
##   echo readMsg.number
##   echo readMsg.text
##   echo readMsg.nested.aField
##
## Generated code
## --------------
## Since all the code is generated from the macro on compile-time and not stored
## anywhere the generated code is made to be deterministic and easy to
## understand. If you would like to see the code however you can pass
## ``-d:echoProtobuf`` switch on compile-time and the macro will output the
## generated code.
##
## Messages
## ^^^^^^^^
## The types generated are named after the path of the message, but with dots
## replaced by underscores. So if the protobuf specification contains a package
## name it starts with that, then the name of the message. If the message is
## nested then the parent message is put between the package and the message.
## As an example we can look at a protobuf message defined like this:
##
## .. code-block:: protobuf
##
##   syntax = "proto3"; // The only syntax supported
##   package = our.package;
##   message ExampleMessage {
##       int32 simpleField = 1;
##   }
##
## The type generated for this message would be named
## ``our_package_ExampleMessage``. Since Nim is case and underscore insensitive
## you can of course write this with any style you desire be it camel-case,
## snake-case, or a mix as seen above. For this specific instance the type
## would be:
##
## .. code-block:: nim
##
##   type
##     our_package_ExampleMessage = object
##       simpleField: int32
##
## Messages also generate a reader, writer, and length procedure to read,
## write, and get the length of a message on the wire respectively. All write
## procs are simply named ``write`` and are only differentiated by their types.
## This write procedure takes three arguments, the ``Stream`` to write to, an
## instance of the message type to write, and a boolean telling it to prepend
## the message with a varint of it's length or not. This boolean is used for
## internal purposes, but might also come in handy if you want to stream
## multiple messages as described in
## https://developers.google.com/protocol-buffers/docs/techniques#streaming.
## The read procedure is named similarily to all the ``streams`` module
## readers, simply "read" appended with the name of the type. So for the above
## message the reader would be named ``read_our_package_ExampleMessage``.
## Notice again how you can write it in different styles in Nim if you'd like.
## One could of course also create an alias for this name should it prove too
## verbose. Analagously to the ``write`` procedure the reader also takes a
## maxSize argument of the maximum size to read for the message before
## returning. If the size is set to 0 the stream would be read until ``atEnd``
## returns true. The ``len`` procedure is slightly simpler, it only takes an
## instance of the message type and returns the size this message would take on
## the wire, in bytes. This is used internally, but might have some
## other applications elsewhere as well. Notice that this size might vary from
## one instance of the type to another as varints can have multiple sizes,
## repeated fields different amount of elements, and oneofs having different
## choices to name a few.
##
## Enums
## ^^^^^
## Enums are named the same was as messages, and are always declared as pure.
## So an enum defined like this:
##
## .. code-block:: protobuf
##
##   syntax = "proto3"; // The only syntax supported
##   package = our.package;
##   enum Langs {
##     UNIVERSAL = 0;
##     NIM = 1;
##     C = 2;
##   }
##
## Would end up with a type like this:
##
## .. code-block:: nim
##
##   type
##     our_package_Langs {.pure.} = enum
##       UNIVERSAL = 0, NIM = 1, C = 2
##
## For internal use enums also generate a reader and writer procedure. These
## are basically a wrapper around the reader and writer for a varint, only that
## they convert to and from the enum type. Using these by themselves is seldom
## useful.
##
## OneOfs
## ^^^^^^
## In order for oneofs to work with Nims type system they generate their own
## type. This might change in the future. Oneofs are named the same way as
## their parent message, but with the name of the oneof field, and ``_OneOf``
## appended. All oneofs contain a field named ``option`` of a ranged integer
## from 0 to the number of options. This type is used to create an object
## variant for each of the fields in the oneof. So a oneof defined like this:
##
## .. code-block:: protobuf
##
##   syntax = "proto3"; // The only syntax supported
##   package our.package;
##   message ExampleMessage {
##     oneof choice {
##       int32 firstField = 1;
##       string secondField = 1;
##     }
##   }
##
## Will generate the following message and oneof type:
##
## .. code-block:: nim
##
##   type
##     our_package_ExampleMessage_choice_OneOf = object
##       case option: range[0 .. 1]
##       of 0: firstField: int32
##       of 1: secondField: string
##     our_package_ExampleMessage = object
##       choice: our_package_ExampleMessage_choice_OneOf
##
## Limitations
## -----------
## This library is still in an early phase and has some limitations over the
## official version of protobuf. Noticably it only supports the "proto3"
## syntax, so no optional or required fields. It also doesn't currently support
## maps but you can use the official workaround found here:
## https://developers.google.com/protocol-buffers/docs/proto3#maps. This is
## planned to be added in the future. It also doesn't support options, meaning
## you can't set default values for enums and can't control packing options.
## That being said it follows the proto3 specification and will pack all scalar
## fields. It also doesn't support services.
##
## These limitations apply to the parser as well, so if you are using an
## existing protobuf specification you must remove these fields before being
## able to parse them with this library.
##
## Rationale
## ---------
## Some might be wondering why I've decided to create this library. After all
## the protobuf compiler is extensible and there are some other attempts at
## using protobuf within Nim by using this. The reason is three-fold, first off
## no-one likes to add an extra step to their compilation process. Running
## ``protoc`` before compiling isn't a big issue, but it's an extra
## compile-time dependency and it's more work. By using a regular Nim macro
## this is moved to a simple step in the compilation process. The only
## requirement is Nim and this library meaning tools can be automatically
## installed through nimble and still use protobuf. It also means that all of
## Nims targets are supported, and sending data between code compiled to C and
## Javascript should be a breeze and can share the exact same code for
## generating the messages. This is not yet tested, but any issues arising
## should be easy enough to fix. Secondly the programatic protobuf interface
## created for some languages are not the best. Python for example has some
## rather awkward and un-natural patterns for their protobuf library. By using
## a Nim macro the code can be customised to Nim much better and has the
## potential to create really native-feeling code resulting in a very nice
## interface. And finally this has been an interesting project in terms of
## pushing the macro system to do something most languages would simply be
## incapable of doing. It's not only a showcase of how much work the Nim
## compiler is able to do for you through it's meta-programming, but has also
## been highly entertaining to work on.

import streams, strutils, sequtils, macros, tables


when cpuEndian == littleEndian:
  proc hob(x: int64): int =
    result = x.int
    result = result or (result shr 1)
    result = result or (result shr 2)
    result = result or (result shr 4)
    result = result or (result shr 8)
    result = result or (result shr 16)
    result = result or (result shr 32)
    result = result - (result shr 1)

  proc getVarIntLen*(num: int | int64 | int32): int =
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
    s.write((num and 0x7f or (if bytes > 0: 0x80 else: 0)).uint8)
    while bytes > 0:
      num = num shr 7
      bytes = bytes shr 7
      s.write((num and 0x7f or (if bytes > 0: 0x80 else: 0)).uint8)

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

import combparser

proc combine(list: seq[string], sep: string): string =
  result = ""
  for entry in list:
    result = result & entry & sep
  result = result[0..^(sep.len + 1)]

proc combine(list: seq[string]): string =
  list.combine("")

proc combine(t: tuple[f1, f2: string]): string =
  if t.f1 == nil:
    t.f2
  elif t.f2 == nil:
    t.f1
  else:
    t.f1 & t.f2

proc combine[T](t: tuple[f1: T, f2: string]): string =
  if t.f2 == nil:
    t.f1.combine()
  else:
    t.f1.combine() & t.f2

proc combine[T](t: tuple[f1: string, f2: T]): string =
  if t.f1 == nil:
    t.f2.combine()
  else:
    t.f1 & t.f2.combine()

proc combine[T, U](t: tuple[f1: T, f2: U]): string = t.f1.combine() & t.f2.combine()

proc combine[T, U](t: tuple[f1: T, f2: StringParser[U]]): string = t.f1.combine() & t.f2.map(combine)

proc combine[T, U](t: tuple[f1: StringParser[T], f2: StringParser[U]]): string = t.f1.map(combine) & t.f2.map(combine)

proc combine[T](list: seq[T]): string =
  result = ""
  for entry in list:
    result = result & entry.combine()

proc optwhitespace[T](parser: StringParser[T]): StringParser[T] =
  ignoresides(charmatch(Whitespace), parser, charmatch(Whitespace))

proc ws(value: string): StringParser[string] =
  optwhitespace(s(value))

proc endcomment(): StringParser[string] =
  ignorefirst(charmatch(Whitespace), s("//") + allbut("\n") + s("\n")).repeat(1).map(combine)

proc inlinecomment(): StringParser[string] =
  ignorefirst(charmatch(Whitespace), s("/*") + allbut("*/") + s("*/")).repeat(1).map(combine)

proc comment(): StringParser[string] = andor(endcomment(), inlinecomment()).repeat(1).map(combine)

proc endstatement(): StringParser[string] =
  ignoresides(inlinecomment(), ws(";"), comment())

proc str(): StringParser[string] =
  ignorefirst(inlinecomment(), optwhitespace(s("\"") + allbut("\"") + s("\""))).map(
    proc(n: auto): string =
      n[0][1]
  ).ignorelast(comment())

proc number(): StringParser[string] =
  optwhitespace(charmatch(Digits)).onerror("Number doesn't match!")

proc strip(input: string): string =
  input.strip(true, true)

proc enumname(): StringParser[string] =
  ignoresides(comment(),
    optwhitespace(charmatch({'A'..'Z'}))
  , comment())

proc token(): StringParser[string] =
  ignoresides(comment(),
    (
      ignorefirst(charmatch(Whitespace), charmatch({'a'..'z'})) +
      ignorelast(optional(charmatch({'a'..'z', 'A'..'Z', '0'..'9', '_'})), charmatch(Whitespace))
    ).map(combine)
  , comment())

proc token(name: string): StringParser[string] =
  ignoresides(comment(), ws(name), comment()).map(strip)

proc class(): StringParser[string] =
  ignoresides(comment(),
    (
      ignorefirst(charmatch(Whitespace), charmatch({'A'..'Z'})) +
      ignorelast(optional(charmatch({'a'..'z', 'A'..'Z', '0'..'9', '_'})), charmatch(Whitespace))
    ).map(combine)
  , comment())

proc typespecifier(): StringParser[string] =
  ignoresides(comment(),
    (
      optwhitespace(charmatch({'a'..'z', 'A'..'Z', '0'..'9', '_', '.'}))
    )
  , comment())

type
  ReservedType = enum
    String, Number, Range
  ProtoType = enum
    Field, Enum, EnumVal, ReservedBlock, Reserved, Message, File, Imported, Oneof, Package, ProtoDef
  ProtoNode = ref object
    case kind*: ProtoType
    of Field:
      number: int
      protoType: string
      name: string
      repeated: bool
    of Oneof:
      oneofName: string
      oneof: seq[ProtoNode]
    of Enum:
      enumName: string
      values: seq[ProtoNode]
    of EnumVal:
      fieldName: string
      num: int
    of ReservedBlock:
      resValues: seq[ProtoNode]
    of Reserved:
      case reservedKind*: ReservedType
      of ReservedType.String:
        strVal: string
      of ReservedType.Number:
        intVal: int
      of ReservedType.Range:
        startVal: int
        endVal: int
    of Message:
      messageName: string
      reserved: seq[ProtoNode]
      definedEnums: seq[ProtoNode]
      fields: seq[ProtoNode]
      nested: seq[ProtoNode]
    of Package:
      packageName: string
      messages: seq[ProtoNode]
      packageEnums: seq[ProtoNode]
    of File:
      syntax: string
      imported: seq[ProtoNode]
      package: ProtoNode
    of ProtoDef:
      packages: seq[ProtoNode]
    of Imported:
      filename: string


proc `$`(node: ProtoNode): string =
  case node.kind:
    of Field:
      result = "Field $1 of type $2 with index $3".format(
        node.name,
        node.protoType,
        node.number)
      if node.repeated:
        result &= " is repeated"
    of Oneof:
      result = "One-of named $1, with one of these fields:\n".format(
        node.oneofName)
      var fields = ""
      for field in node.oneof:
        fields &= $field & "\n"
      result &= fields[0..^2].indent(1, "  ")
    of Enum:
      result = "Enum $1 has values:\n".format(
        node.enumName)
      var fields = ""
      for field in node.values:
        fields &= $field & "\n"
      result &= fields[0..^2].indent(1, "  ")
    of EnumVal:
      result = "Enum field $1 with index $2".format(
        node.fieldName,
        node.num)
    of ReservedBlock:
      result = "Reserved values:\n"
      var reserved = ""
      for value in node.resValues:
        reserved &= $value & "\n"
      result &= reserved.indent(1, "  ")
    of Reserved:
      result = case node.reservedKind:
        of ReservedType.String:
          "Reserved field name $1".format(
            node.strVal)
        of ReservedType.Number:
          "Reserved field index $1".format(
            node.intVal)
        of ReservedType.Range:
          "Reserved field index from $1 to $2".format(
            node.startVal, node.endVal)
    of Message:
      result = "Message $1 with data:".format(
        node.messageName)
      var data = ""
      if node.reserved.len != 0:
        data &= "\nReserved fields:"
        var reserved = "\n"
        for res in node.reserved:
          reserved &= $res & "\n"
        data &= reserved[0..^2].indent(1, "  ")
      if node.definedEnums.len != 0:
        data &= "\nEnumerable definitions:"
        var enums = "\n"
        for definedEnum in node.definedEnums:
          enums &= $definedEnum & "\n"
        data &= enums[0..^2].indent(1, "  ")
      if node.fields.len != 0:
        data &= "\nDefined fields:"
        var fields = "\n"
        for field in node.fields:
          fields &= $field & "\n"
        data &= fields[0..^2].indent(1, "  ")
      if node.nested.len != 0:
        data &= "\nAnd nested messages:"
        var messages = "\n"
        for message in node.nested:
          messages &= $message & "\n"
        data &= messages[0..^2].indent(1, "  ")
      result &= data.indent(1, "  ")
    of File:
      result = "Protobuf file with syntax $1\n".format(
        node.syntax)
      if node.imported.len != 0:
        var body = "Imported:\n"
        for imp in node.imported:
          body &= ($imp).indent(1, "  ")
          result &= body.indent(1, "  ") & "\n"
          body = "\n"
      if node.package != nil:
        result &= $node.package
      else:
        result &= "Without own package"
    of Package:
      result = "Package$1:\n".format(if node.packageName != nil: " with name " & node.packageName else: "")
      for message in node.messages:
        result &= ($message).indent(1, "  ") & "\n"
      for enumeration in node.packageEnums:
        result &= ($enumeration).indent(1, "  ")
    of ProtoDef:
      result = ""
      for package in node.packages:
        result &= $package
    of Imported:
      result = "Imported file " & node.filename

proc syntaxline(): StringParser[string] = (token("syntax") + ws("=") + str() + endstatement()).map(
  proc (stuple: auto): string =
    stuple[0][1]
)

proc importstatement(): StringParser[ProtoNode] = (token("import") + str() + endstatement()).map(
  proc (stuple: auto): ProtoNode =
    ProtoNode(kind: Imported, filename: stuple[0][1])
)

proc package(): StringParser[string] = (token("package") + typespecifier() + endstatement()).map(
  proc (stuple: auto): string =
    stuple[0][1]
)

proc declaration(): StringParser[ProtoNode] = (optional(ws("repeated")) + typespecifier() + token() + ws("=") + number() + endstatement()).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: Field, number: parseInt(input[0][1]), name: input[0][0][0][1], protoType: input[0][0][0][0][1], repeated: input[0][0][0][0][0] != nil)
)

proc reserved(): StringParser[ProtoNode] =
  (token("reserved") + (((number() + ws("to") + (number() / ws("max"))).ignorelast(ws(",")).map(
    proc (input: auto): ProtoNode =
      let
        f = parseInt(input[0][0])
        t = if input[1] == "max": Natural.high else: parseInt(input[1])
      ProtoNode(kind: Reserved, reservedKind: ReservedType.Range, startVal: f, endVal: t)
  ) / (number().ignorelast(ws(","))).map(
    proc (input: auto): ProtoNode =
      ProtoNode(kind: Reserved, reservedKind: ReservedType.Number, intVal: parseInt(input))
  )).repeat(1).map(
    proc (input: auto): ProtoNode =
      result = ProtoNode(kind: ReservedBlock, resValues: @[])
      for reserved in input:
        result.resValues.add reserved
  ) / (str().ignorelast(ws(","))).repeat(1).map(
    proc (input: auto): ProtoNode =
      result = ProtoNode(kind: ReservedBlock, resValues: @[])
      for str in input:
        result.resValues.add ProtoNode(kind: Reserved, reservedKind: ReservedType.String, strVal: str)
  )) + endstatement()).map(
    proc (input: auto): ProtoNode =
      input[0][1]
  )

proc enumvals(): StringParser[ProtoNode] = (enumname() + ws("=") + number() + endstatement()).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: EnumVal, fieldName: input[0][0][0], num: parseInt(input[0][1]))
).onerror("Unable to parse enumval")

proc enumblock(): StringParser[ProtoNode] = (token("enum") + class() + ws("{") + enumvals().repeat(1) + ws("}")).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: Enum, enumName: input[0][0][0][1], values: input[0][1])
)

proc oneof(): StringParser[ProtoNode] = (token("oneof") + token() + ws("{") + declaration().repeat(1) + ws("}")).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: Oneof, oneofName: input[0][0][0][1], oneof: input[0][1])
)

proc messageblock(): StringParser[ProtoNode] = (token("message") + class() + ws("{") + (oneof() / declaration() / reserved() / enumblock() / token("message").flatMap(
  proc(msg: string): StringParser[ProtoNode] =
    # Strange hack to get recursive parsers to work properly
    (proc (rest: string): Maybe[(ProtoNode, string), string] =
      messageblock()(msg & " " & rest)
    )
  )).repeat(0) + ws("}")).map(
    proc (input: auto): ProtoNode =
      result = ProtoNode(kind: Message, messageName: input[0][0][0][1], reserved: @[], definedEnums: @[], fields: @[], nested: @[])
      for thing in input[0][1]:
        case thing.kind:
        of ReservedBlock:
          result.reserved = result.reserved.concat(thing.resValues)
        of Enum:
          result.definedEnums.add thing
        of Field:
          result.fields.add thing
        of Oneof:
          result.fields.add thing
        of Message:
          result.nested.add thing
        else:
          continue
  )

proc protofile(): StringParser[ProtoNode] = (syntaxline() + optional(package()) + (messageblock() / importstatement() / enumblock()).repeat(1)).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: File, syntax: input[0][0], imported: @[], package: ProtoNode(kind: Package, packageName: input[0][1], messages: @[], packageEnums: @[]))
    for message in input[1]:
      case message.kind:
        of Message:
          result.package.messages.add message
        of Imported:
          result.imported.add message
        of Enum:
          result.package.packageEnums.add message
        else: raise newException(AssertionError, "Unsupported node kind: " & $message.kind)
)

macro expandToFullDef(protoParsed: var ProtoNode, stringGetter: untyped): untyped =
  result = quote do:
    var imports = `protoParsed`.imported
    `protoParsed` = ProtoNode(kind: ProtoDef, packages: @[`protoParsed`.package])
    while imports.len != 0:
      let imported = parse(protofile(), `stringGetter`(imports[0].filename))
      `protoParsed`.packages.add imported.package
      imports = imports[1..imports.high]
      imports.insert imported.imported

proc expandToFullDef(protoParsed: var ProtoNode) =
  expandToFullDef(protoParsed, readFile)

#let parsed = (number()).onerror("Unable to match numbers")("12-3;")
#echo parsed.value
#echo parsed.errors == nil
#echo parsed
#echo parse(ignorefirst(comment(), s("syntax")) , "syntax = \"This is syntax\";")
#echo parse(optional(ws("hello")) + ws("world"), "hello world")
#echo parse(optional(ws("hello")) + ws("world"), " world")
#echo parse(syntaxline(), "syntax = \"This is syntax\";")
#echo parse(importstatement(), "import \"This is syntax\";")
#echo parse(declaration(), "int32 syntax = 5;")
#echo parse(typespecifier(), "This.Is.Atest")
#echo parse(declaration(), "This.Is.Atest name = 5;")
#echo parse(reserved(), "reserved 5;")
#echo parse(reserved(), "reserved 5, 7;")
#echo parse(reserved(), "reserved 5, 7 to max;")
#echo parse(reserved(), "reserved \"foo\";")
#echo parse(reserved(), "reserved \"foo\", \"bar\";")
#echo parse(enumvals(), "TEST = 12a;")
#echo parse(enumblock(), """enum Test {
#  TEST = 5;
#  FOO = 6;
#  BAR = 9;
#}
#"""")

type ValidationError = object of Exception

template ValidationAssert(statement: bool, error: string) =
  if not statement:
    raise newException(ValidationError, error)

proc getTypes(message: ProtoNode, parent = ""): seq[string] =
  result = @[]
  case message.kind:
    of ProtoDef:
      for package in message.packages:
        result = result.concat package.getTypes(parent)
    of Package:
      let name = (if parent != "": parent & "." else: "") & (if message.packageName == nil: "" else: message.packageName)
      for definedEnum in message.packageEnums:
        ValidationAssert(definedEnum.kind == Enum, "Field for defined enums contained something else than a message")
        result.add name & "." & definedEnum.enumName
      for innerMessage in message.messages:
        result = result.concat innerMessage.getTypes(name)
    of Message:
      let name = (if parent != "": parent & "." else: "") & message.messageName
      for definedEnum in message.definedEnums:
        ValidationAssert(definedEnum.kind == Enum, "Field for defined enums contained something else than a message")
        result.add name & "." & definedEnum.enumName
      for innerMessage in message.nested:
        result = result.concat innerMessage.getTypes(name)
      result.add name
    else: ValidationAssert(false, "Unknown kind: " & $message.kind)

proc verifyAndExpandTypes(node: ProtoNode, validTypes: seq[string], parent: seq[string] = @[]) =
  case node.kind:
    of Field:
      block fieldBlock:
        #node.name = parent.join(".") & "." & node.name
        if node.protoType notin ["int32", "int64", "uint32", "uint64", "sint32", "sint64", "fixed32",
          "fixed64", "sfixed32", "sfixed64", "bool", "bytes", "enum", "float", "double", "string"]:
          if node.protoType[0] != '.':
            var depth = parent.len
            while depth > 0:
              if parent[0 ..< depth].join(".") & "." & node.protoType in validTypes:
                node.protoType = parent[0 ..< depth].join(".") & "." & node.protoType
                break fieldBlock
              depth -= 1
          else:
            if node.protoType[1 .. ^1] in validTypes:
              node.protoType = node.protoType[1 .. ^1]
              break fieldBlock
            var depth = 0
            while depth < parent.len:
              if parent[depth .. ^1].join(".") & "." & node.protoType[1 .. ^1] in validTypes:
                node.protoType = parent[depth .. ^1].join(".") & "." & node.protoType[1 .. ^1]
                break fieldBlock
              depth += 1
          ValidationAssert(false, "Type not recognized: " & parent.join(".") & "." & node.protoType)
    of Enum:
      node.enumName = (if parent.len != 0: parent.join(".") & "." else: "") & node.enumName
    of Oneof:
      for field in node.oneof:
        verifyAndExpandTypes(field, validTypes, parent)
      node.oneofName = parent.join(".") & "." & node.oneofName
    of Message:
      var name = parent & node.messageName
      for field in node.fields:
        verifyAndExpandTypes(field, validTypes, name)
      for definedEnum in node.definedEnums:
        verifyAndExpandTypes(definedEnum, validTypes, name)
      for subMessage in node.nested:
        verifyAndExpandTypes(subMessage, validTypes, name)
      node.messageName = name.join(".")
    of ProtoDef:
      for node in node.packages:
        var name = parent.concat(if node.packageName == nil: @[] else: node.packageName.split("."))
        for enu in node.packageEnums:
          verifyAndExpandTypes(enu, validTypes, name)
        for message in node.messages:
          verifyAndExpandTypes(message, validTypes, name)

    else: ValidationAssert(false, "Unknown kind: " & $node.kind)

proc verifyReservedAndUnique(message: ProtoNode) =
  ValidationAssert(message.kind == Message, "ProtoBuf messages field contains something else than messages")
  var
    usedNames: seq[string] = @[]
    usedIndices: seq[int] = @[]
  for field in message.fields:
    ValidationAssert(field.kind == Field or field.kind == Oneof, "Field for defined fields contained something else than a field")
    for field in (if field.kind == Field: @[field] else: field.oneof):
      ValidationAssert(field.name notin usedNames, "Field name already used")
      ValidationAssert(field.number notin usedIndices, "Field number already used")
      usedNames.add field.name
      usedIndices.add field.number
      for value in message.reserved:
        ValidationAssert(value.kind == Reserved, "Field for reserved values contained something else than a reserved value")
        case value.reservedKind:
          of String:
            ValidationAssert(value.strVal != field.name, "Field name in list of reserved names")
          of Number:
            ValidationAssert(value.intVal != field.number, "Field index in list of reserved indices")
          of Range:
            ValidationAssert(not(field.number >= value.startVal and field.number <= value.endVal), "Field index in list of reserved indices")
  for m in message.nested:
    verifyReservedAndUnique(m)

proc registerEnums(typeMapping: var Table[string, tuple[kind, write, read: NimNode, wire: int]], node: ProtoNode) =
  case node.kind:
  of Enum:
    typeMapping[node.enumName] = (kind: newIdentNode(node.enumName.replace(".", "_")), write: newIdentNode("write"), read: newIdentNode("read" & node.enumName.replace(".", "_")), wire: 0)
  of Message:
    for message in node.nested:
      registerEnums(typeMapping, message)
    for enu in node.definedEnums:
      registerEnums(typeMapping, enu)
  of ProtoDef:
    for node in node.packages:
      for message in node.messages:
        registerEnums(typeMapping, message)
      for enu in node.packageEnums:
        registerEnums(typeMapping, enu)
  else:
    discard

proc valid(proto: ProtoNode) =
  ValidationAssert(proto.kind == File, "Validation must take an entire ProtoFile")
  ValidationAssert(proto.syntax == "proto3", "File must follow proto3 syntax")
  var validTypes: seq[string]
  for message in proto.messages:
    verifyReservedAndUnique(message)
    validTypes = validTypes.concat message.getTypes()
  for message in proto.messages:
    verifyAndExpandTypes(message, validTypes)

proc generateCode(typeMapping: Table[string, tuple[kind, write, read: NimNode, wire: int]], proto: ProtoNode): NimNode {.compileTime.} =
  proc generateTypes(node: ProtoNode, parent: var NimNode) =
    case node.kind:
    of Field:
      if node.repeated:
        parent.add(nnkIdentDefs.newTree(
          newIdentNode(node.name),
          nnkBracketExpr.newTree(
            newIdentNode("seq"),
            newIdentNode(node.protoType.replace(".", "_"))
          ),
          newEmptyNode()
        ))
      else:
        parent.add(nnkIdentDefs.newTree(
          newIdentNode(node.name),
          newIdentNode(node.protoType.replace(".", "_")),
          newEmptyNode()
        ))
    of EnumVal:
      parent.add(
        nnkEnumFieldDef.newTree(
          newIdentNode(node.fieldName),
          newIntLitNode(node.num)
        )
      )
    of Enum:
      var currentEnum = nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
          newIdentNode(node.enumName.replace(".", "_")),
          nnkPragma.newTree(newIdentNode("pure"))
        ),
        newEmptyNode()
      )
      var enumBlock = nnkEnumTy.newTree(newEmptyNode())
      for enumVal in node.values:
        generateTypes(enumVal, enumBlock)
      currentEnum.add(enumBlock)
      parent.add(currentEnum)
    of OneOf:
      var cases = nnkRecCase.newTree(
          nnkIdentDefs.newTree(
            newIdentNode("option"),
            nnkBracketExpr.newTree(
              newIdentNode("range"),
              nnkInfix.newTree(
                newIdentNode(".."),
                newLit(0),
                newLit(node.oneof.len - 1)
              )
            ),
            newEmptyNode()
          )
        )
      var curCase = 0
      for field in node.oneof:
        var caseBody = newNimNode(nnkRecList)
        generateTypes(field, caseBody)
        cases.add(
          nnkOfBranch.newTree(
            newLit(curCase),
            caseBody
          )
        )
        curCase += 1
      parent.add(
        nnkTypeDef.newTree(
          newIdentNode(node.oneofName.replace(".", "_") & "_OneOf"),
          newEmptyNode(),
          nnkObjectTy.newTree(
            newEmptyNode(),
            newEmptyNode(),
            nnkRecList.newTree(
              cases
            )
          )
        )
      )
    of Message:
      var currentMessage = nnkTypeDef.newTree(
        newIdentNode(node.messageName.replace(".", "_")),
        newEmptyNode()
      )
      var messageBlock = nnkRecList.newNimNode()
      for field in node.fields:
        if field.kind == Field:
          generateTypes(field, messageBlock)
        else:
          generateTypes(field, parent)
          messageBlock.add(nnkIdentDefs.newTree(
            newIdentNode(field.oneofName.rsplit({'.'}, 1)[1]),
            newIdentNode(field.oneofName.replace(".", "_") & "_OneOf"),
            newEmptyNode()
          ))
      currentMessage.add(nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), messageBlock))
      parent.add(currentMessage)
      for definedEnum in node.definedEnums:
        generateTypes(definedEnum, parent)
      for subMessage in node.nested:
        generateTypes(subMessage, parent)
    of ProtoDef:
      for node in node.packages:
        for message in node.messages:
          generateTypes(message, parent)
        for enu in node.packageEnums:
          generateTypes(enu, parent)
    else:
      echo "Unsupported kind: " & $node.kind
      discard
  proc generateFieldLen(typeMapping: Table[string, tuple[kind, write, read: NimNode, wire: int]], node: ProtoNode, field: NimNode): NimNode =
    result = newStmtList()
    let fieldDesc = newLit(getVarIntLen(node.number shl 3 or (if not node.repeated and typeMapping.hasKey(node.protoType): typeMapping[node.protoType].wire else: 2)))
    let res = newIdentNode("result")
    result.add(quote do:
      `res` += `fieldDesc`
    )
    if typeMapping.hasKey(node.protoType):
      case typeMapping[node.protoType].wire:
      of 1:
        if node.repeated:
          result.add(quote do:
            `res` += 8*`field`.len
          )
        else:
          result.add(quote do:
            `res` += 8
          )
      of 5:
        if node.repeated:
          result.add(quote do:
            `res` += 4*`field`.len
          )
        else:
          result.add(quote do:
            `res` += 4
          )
      of 2:
        if node.repeated:
          result.add(quote do:
            for i in `field`:
              `res` += i.len
              `res` += getVarIntLen(i.len.int64)
            `res` += `fieldDesc`*(`field`.len-1)
          )
        else:
          result.add(quote do:
            `res` += getVarIntLen(`field`.len.int64)
            `res` += `field`.len
          )
      of 0:
        let
          iVar = nskForVar.genSym()
          varInt = if node.repeated: nnkBracketExpr.newTree(field, iVar) else: field
          getVarIntLen = newIdentNode("getVarIntLen")
          innerBody = quote do:
            `res` += `getVarIntLen`(`varInt`)
          outerBody = if node.repeated: (quote do:
            for `iVar` in 0..`field`.high:
              `innerBody`
          ) else: innerBody
        result.add(outerBody)
      else:
        echo "Unable to create code"
        #raise newException(AssertionError, "Unable to generate code, wire type '" & $typeMapping[field.protoType].wire & "' not supported")
    else:
      if node.repeated:
        result.add(quote do:
          for i in `field`:
            `res` += i.len
        )
      else:
        result.add(quote do:
          `res` += `field`.len
        )
  proc generateFieldRead(typeMapping: Table[string, tuple[kind, write, read: NimNode, wire: int]], node: ProtoNode, stream, field: NimNode): NimNode =
    result = newStmtList()
    if node.repeated:
      if typeMapping.hasKey(node.protoType) and node.protoType != "string" and node.protoType != "bytes":
        let
          sizeSym = genSym(nskVar)
          protoRead = typeMapping[node.protoType].read
        result.add(quote do:
          var `sizeSym` = `stream`.protoReadInt64()
          `field` = @[]
          let endPos = `stream`.getPosition() + `sizeSym`
          while `stream`.getPosition() < endPos:
            `field`.add(`stream`.`protoRead`())
        )
      else:
        let
          protoRead = if typeMapping.hasKey(node.protoType): typeMapping[node.protoType].read else: newIdentNode("read" & node.protoType.replace(".", "_"))
          readStmt = if typeMapping.hasKey(node.protoType): quote do: `stream`.`protoRead`()
            else: quote do: `stream`.`protoRead`(`stream`.protoReadInt64()) #TODO: This is not implemented on the writer level
        result.add(quote do:
          if `field` == nil:
            `field` = @[]
          `field`.add(`readStmt`)
        )
    else:
      let
        protoRead = if typeMapping.hasKey(node.protoType):
          typeMapping[node.protoType].read
        else:
          newIdentNode("read" & node.protoType.replace(".", "_"))
        readStmt = if typeMapping.hasKey(node.protoType):
          quote do: `stream`.`protoRead`()
        else:
          quote do:
            when compiles(`stream`.`protoRead`(`stream`.protoReadInt64())):
              `stream`.`protoRead`(`stream`.protoReadInt64())
            else:
              `stream`.`protoRead`()

      result.add(quote do:
        `field` = `readStmt`
      )

  proc generateFieldWrite(typeMapping: Table[string, tuple[kind, write, read: NimNode, wire: int]], node: ProtoNode, stream, field: NimNode): NimNode =
    # Write field number and wire type
    result = newStmtList()
    let fieldWrite = nnkCall.newTree(
        newIdentNode("protoWriteInt64"),
        stream,
        newLit(node.number shl 3 or (if not node.repeated and typeMapping.hasKey(node.protoType): typeMapping[node.protoType].wire else: 2))
      )
    # If the field is repeated or has a repeated wire type, write it's length
    if typeMapping.hasKey(node.protoType) and node.protoType != "string" and node.protoType != "bytes":
      result.add(fieldWrite)
      if node.repeated:
        case typeMapping[node.protoType].wire:
        of 1:
          # Write 64bit * len
          result.add(quote do:
            `stream`.protoWriteInt64(8*`field`.len)
          )
        of 5:
          # Write 32bit * len
          result.add(quote do:
            `stream`.protoWriteInt64(4*`field`.len)
          )
        of 2:
          # Write len
          result.add(quote do:
            var bytes = 0
            for i in 0..`field`.high:
              bytes += `field`[i].len
            `stream`.protoWriteInt64(bytes)
          )
        of 0:
          # Sum varint lengths and write them
          result.add(quote do:
            var bytes = 0
            for i in 0..`field`.high:
              bytes += getVarIntLen(`field`[i])
            `stream`.protoWriteInt64(bytes)
          )
        else:
          echo "Unable to create code"
      let
        iVar = nskForVar.genSym()
        varInt = if node.repeated: nnkBracketExpr.newTree(field, iVar) else: field
        innerBody = nnkCall.newTree(
          typeMapping[node.protoType].write,
          stream,
          varInt
        )
        outerBody = if node.repeated: (quote do:
          for `iVar` in 0..`field`.high:
            `innerBody`
        ) else: innerBody
      result.add(outerBody)
    else:
      let
        iVar = nskForVar.genSym()
        varInt = if node.repeated: nnkBracketExpr.newTree(field, iVar) else: field
        protoWrite = if typeMapping.hasKey(node.protoType): typeMapping[node.protoType].write else: newEmptyNode()
        innerBody = if typeMapping.hasKey(node.protoType):
          quote do:
            `fieldWrite`
            `stream`.`protoWrite`(`varInt`)
        else:
          quote do:
            `fieldWrite`
            when compiles(`stream`.write(`varInt`, true)):
              `stream`.write(`varInt`, true)
            else:
              `stream`.write(`varInt`)
        outerBody = if node.repeated: (quote do:
          for `iVar` in 0..`field`.high:
            `innerBody`
        ) else: innerBody
      result.add(outerBody)

  proc generateProcs(typeMapping: Table[string, tuple[kind, write, read: NimNode, wire: int]], node: ProtoNode, decls: var NimNode, impls: var NimNode) =
    case node.kind:
      of Message:
        let
          readName = newIdentNode("read" & node.messageName.replace(".", "_"))
          messageType = newIdentNode(node.messageName.replace(".", "_"))
          readNameStr = "read" & node.messageName.replace(".", "_")
        var procDecls = quote do:
          proc `readName`(s: Stream, maxSize: int64 = 0): `messageType`
          proc write(s: Stream, o: `messageType`, writeSize = false)
          proc len(o: `messageType`): int
        var procImpls = quote do:
          proc `readName`(s: Stream, maxSize: int64 = 0): `messageType` =
            let startPos = s.getPosition()
            while not s.atEnd and (maxSize == 0 or s.getPosition() < startPos + maxSize):
              let
                fieldSpec = s.protoReadInt64().uint64
                wireType = fieldSpec and 0b111
                fieldNumber = fieldSpec shr 3
              case fieldNumber.int64:
          proc write(s: Stream, o: `messageType`, writeSize = false) =
            if writeSize:
              s.protoWriteInt64(o.len)
          proc len(o: `messageType`): int
        procImpls[2][6] = newStmtList()
        for field in node.fields:
          generateProcs(typeMapping, field, procDecls, procImpls)
        # TODO: Add generic reader for unknown types based on wire type
        procImpls[0][6][1][1][1].add(nnkElse.newTree(nnkStmtList.newTree(nnkDiscardStmt.newTree(newEmptyNode()))))
        for enumType in node.definedEnums:
          generateProcs(typeMapping, enumType, procDecls, procImpls)
        for message in node.nested:
          generateProcs(typeMapping, message, decls, impls)
        decls.add procDecls
        impls.add procImpls
      of OneOf:
        let
          oneofName = newIdentNode(node.oneofname.rsplit({'.'}, 1)[1])
          oneofType = newIdentNode(node.oneofname.replace(".", "_") & "_Oneof")
        for i in 0..node.oneof.high:
          let oneof = node.oneof[i]
          impls[0][6][1][1][1].add(nnkOfBranch.newTree(newLit(oneof.number),
            nnkStmtList.newTree(
              nnkAsgn.newTree(nnkDotExpr.newTree(newIdentNode("result"), oneofName),
                quote do: `oneofType`(option: `i`)
              ),
              generateFieldRead(typeMapping, oneof, impls[1][3][1][0], nnkDotExpr.newTree(nnkDotExpr.newTree(newIdentNode("result"), oneofName), newIdentNode(oneof.name)))
            )
          ))
        var
          oneofWriteBlock = nnkCaseStmt.newTree(
              nnkDotExpr.newTree(nnkDotExpr.newTree(impls[1][3][2][0], oneofName), newIdentNode("option"))
            )
          oneofLenBlock = nnkCaseStmt.newTree(
              nnkDotExpr.newTree(nnkDotExpr.newTree(impls[2][3][1][0], oneofName), newIdentNode("option"))
            )
        for i in 0..node.oneof.high:
          oneofWriteBlock.add(nnkOfBranch.newTree(
              newLit(i),
              generateFieldWrite(typeMapping, node.oneof[i], impls[1][3][1][0],
                nnkDotExpr.newTree(nnkDotExpr.newTree(impls[1][3][2][0], oneofName), newIdentNode(node.oneof[i].name))
              )
            )
          )
        impls[1][6].add oneofWriteBlock
        for i in 0..node.oneof.high:
          oneofLenBlock.add(nnkOfBranch.newTree(
              newLit(i),
              generateFieldLen(typeMapping, node.oneof[i],
                nnkDotExpr.newTree(nnkDotExpr.newTree(impls[2][3][1][0], oneofName), newIdentNode(node.oneof[i].name))
              )
            )
          )
        impls[2][6].add oneofLenBlock
      of Field:
        impls[0][6][1][1][1].add(nnkOfBranch.newTree(newLit(node.number),
          generateFieldRead(typeMapping, node, impls[0][3][1][0], nnkDotExpr.newTree(newIdentNode("result"), newIdentNode(node.name)))
        ))
        impls[1][6].add(generateFieldWrite(typeMapping, node, impls[1][3][1][0], nnkDotExpr.newTree(impls[1][3][2][0], newIdentNode(node.name))))
        impls[2][6].add(generateFieldLen(typeMapping, node, nnkDotExpr.newTree(impls[2][3][1][0], newIdentNode(node.name))))
      of Enum:
        let
          readName = newIdentNode("read" & node.enumName.replace(".", "_"))
          enumType = newIdentNode(node.enumName.replace(".", "_"))
        decls.add quote do:
          proc `readName`(s: Stream): `enumType`
          proc write(s: Stream, o: `enumType`)
          proc getVarIntLen(e: `enumType`): int
        impls.add quote do:
          proc `readName`(s: Stream): `enumType` =
              s.protoReadInt64().`enumType`
          proc write(s: Stream, o: `enumType`) =
            s.protoWriteInt64(o.int64)
          proc getVarIntLen(e: `enumType`): int =
            getVarIntLen(e.int64)
      of ProtoDef:
        for node in node.packages:
          for message in node.messages:
            generateProcs(typeMapping, message, decls, impls)
          for packageEnum in node.packageEnums:
            generateProcs(typeMapping, packageEnum, decls, impls)
      else:
        echo "Unsupported kind: " & $node.kind
        discard

  var
    typeBlock = newNimNode(nnkTypeSection)

  proto.generateTypes(typeBlock)
  var
    forwardDeclarations = newStmtList()
    implementations = newStmtList()
  generateProcs(typeMapping, proto, forwardDeclarations, implementations)
  return quote do:
    `typeBlock`
    `forwardDeclarations`
    `implementations`

proc parseImpl(spec: string): NimNode {.compileTime.} =
  var
    protoParseRes = protofile()(spec)
    protoParsed = protoParseRes.value[0]
  let shortErr = protoParseRes.getShortError()
  if shortErr.len != 0:
    echo "Errors: \"" & shortErr & "\""

  protoParsed.expandToFullDef()

  var validTypes = protoParsed.getTypes()
  protoParsed.verifyAndExpandTypes(validTypes)

  var typeMapping = {
    "int32": (kind: newIdentNode("int32"), write: newIdentNode("protoWriteint32"), read: newIdentNode("protoReadint32"), wire: 0),
    "int64": (kind: newIdentNode("int64"), write: newIdentNode("protoWriteint64"), read: newIdentNode("protoReadint64"), wire: 0),
    "sint32": (kind: newIdentNode("int32"), write: newIdentNode("protoWritesint32"), read: newIdentNode("protoReadsint32"), wire: 0),
    "sint64": (kind: newIdentNode("int64"), write: newIdentNode("protoWritesint64"), read: newIdentNode("protoReadsint64"), wire: 0),
    "fixed32": (kind: newIdentNode("uint32"), write: newIdentNode("protoWritefixed32"), read: newIdentNode("protoReadfixed32"), wire: 5),
    "fixed64": (kind: newIdentNode("uint64"), write: newIdentNode("protoWritefixed64"), read: newIdentNode("protoReadfixed64"), wire: 1),
    "sfixed32": (kind: newIdentNode("int32"), write: newIdentNode("protoWritesfixed32"), read: newIdentNode("protoReadsfixed32"), wire: 5),
    "sfixed64": (kind: newIdentNode("int64"), write: newIdentNode("protoWritesfixed64"), read: newIdentNode("protoReadsfixed64"), wire: 1),
    "float": (kind: newIdentNode("float32"), write: newIdentNode("protoWritefloat"), read: newIdentNode("protoReadfloat"), wire: 5),
    "double": (kind: newIdentNode("float64"), write: newIdentNode("protoWritedouble"), read: newIdentNode("protoReaddouble"), wire: 1),
    "string": (kind: newIdentNode("string"), write: newIdentNode("protoWritestring"), read: newIdentNode("protoReadstring"), wire: 2),
    "bytes": (kind: parseExpr("seq[uint8]"), write: newIdentNode("protoWritebytes"), read: newIdentNode("protoReadbytes"), wire: 2)
  }.toTable

  typeMapping.registerEnums(protoParsed)
  result = generateCode(typeMapping, protoParsed)
  when defined(echoProtobuf):
    echo result.toStrLit

macro parseProto*(spec: static[string]): untyped =
  ## Parses the protobuf specification contained in the ``spec`` argument. This
  ## generates the code to use the messages specified within. See the
  ## introduction to this documentation for how this code is generated. NOTE:
  ## Currently the implementation will always use ``readFile`` to get the
  ## specification for any imported files. This will change in the future.
  parseImpl(spec)

macro parseProtoFile*(file: static[string]): untyped =
  ## Parses the protobuf specification contained in the file found at the path
  ## argument ``file``. This generates the code to use the messages specified
  ## within. See the introduction to this documentation for how this code is
  ## generated.
  var protoStr = readFile(file).string
  parseImpl(protoStr)
