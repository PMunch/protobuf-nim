import streams, strutils, sequtils, macros, tables

static:
  let typeMapping = {
    "int32": (kind: parseExpr("int32"), write: parseExpr("protoWriteint32"), read: parseExpr("protoReadint32"), wire: 0),
    "int64": (kind: parseExpr("int64"), write: parseExpr("protoWriteint64"), read: parseExpr("protoReadint64"), wire: 0),
    "sint32": (kind: parseExpr("int32"), write: parseExpr("protoWritesint32"), read: parseExpr("protoReadsint32"), wire: 0),
    "sint64": (kind: parseExpr("int64"), write: parseExpr("protoWritesint64"), read: parseExpr("protoReadsint64"), wire: 0),
    "fixed32": (kind: parseExpr("uint32"), write: parseExpr("protoWritefixed32"), read: parseExpr("protoReadfixed32"), wire: 5),
    "fixed64": (kind: parseExpr("uint64"), write: parseExpr("protoWritefixed64"), read: parseExpr("protoReadfixed64"), wire: 1),
    "sfixed32": (kind: parseExpr("int32"), write: parseExpr("protoWritesfixed32"), read: parseExpr("protoReadsfixed32"), wire: 5),
    "sfixed64": (kind: parseExpr("int64"), write: parseExpr("protoWritesfixed64"), read: parseExpr("protoReadsfixed64"), wire: 1),
    "float": (kind: parseExpr("float32"), write: parseExpr("protoWritefloat"), read: parseExpr("protoReadfloat"), wire: 5),
    "double": (kind: parseExpr("float64"), write: parseExpr("protoWritedouble"), read: parseExpr("protoReaddouble"), wire: 1),
    "string": (kind: parseExpr("string"), write: parseExpr("protoWritestring"), read: parseExpr("protoReadstring"), wire: 2),
    "bytes": (kind: parseExpr("seq[uint8]"), write: parseExpr("protoWritebytes"), read: parseExpr("protoReadbytes"), wire: 2)
  }.toTable

#[
type
  sint32* = distinct int32
  sint64* = distinct int64
  fixed64* = distinct uint64
  sfixed64* = distinct int64
  fixed32* = distinct uint32
  sfixed32* = distinct int32
  double* = distinct float64
  bytes* = seq[uint8]

converter sint32ToInt32(x: sint32): int32 = x.int32
converter sint64ToInt64(x: sint64): int64 = x.int64
converter int32ToSint32(x: int32): sint32 = x.sint32
converter int64ToSint64(x: int64): sint64 = x.sint64

converter fixed32ToUint32(x: fixed32): uint32 = x.uint32
converter fixed64ToUint64(x: fixed64): uint64 = x.uint64
converter uint32ToFixed32(x: uint32): fixed32 = x.fixed32
converter uint64ToFixed64(x: uint64): fixed64 = x.fixed64

converter sfixed32ToInt32(x: sfixed32): int32 = x.int32
converter sfixed64ToInt64(x: sfixed64): int64 = x.int64
converter int32ToSfixed32(x: int32): sfixed32 = x.sfixed32
converter int64ToSfixed64(x: int64): sfixed64 = x.sfixed64

converter doubleToFloat(x: double): float = x.float
converter floatToDouble(x: float64): double = x.double
]#

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

  proc protoWriteInt64(s: Stream, x: int64) =
    var
      bytes = x.hob shr 7
      num = x
    s.write((num and 0x7f or (if bytes > 0: 0x80 else: 0)).uint8)
    while bytes > 0:
      num = num shr 7
      bytes = bytes shr 7
      s.write((num and 0x7f or (if bytes > 0: 0x80 else: 0)).uint8)

  proc protoReadInt64(s: Stream): int64 =
    var
      byte: int64 = s.readInt8()
      i = 1
    result = byte and 0x7f
    while (byte and 0x80) != 0:
      # TODO: Add error checking for values not fitting 64 bits
      byte = s.readInt8()
      result = result or ((byte and 0x7f) shl (7*i))
      i += 1

  proc protoWriteSint64(s: Stream, x: int64) =
    # TODO: Ensure that this works for all int64 values
    var t = x * 2
    if x < 0:
      t = t xor -1
    s.protoWriteInt64(t)

  proc protoReadSint64(s: Stream): int64 =
    let y = s.protoReadInt64()
    return ((y shr 1) xor (if (y and 1) == 1: -1 else: 0))

  proc protoWriteSint32(s: Stream, x: int32) =
    s.protoWriteSint64(x.int64)

  proc protoReadSint32(s: Stream): int32 =
    s.protoReadSint64().int32

  proc protoWriteFixed64(s: Stream, x: uint64) =
    s.write(x)

  proc protoReadFixed64(s: Stream): uint64 =
    s.readUint64()

  proc protoWriteFixed32(s: Stream, x: uint32) =
    s.write(x)

  proc protoReadFixed32(s: Stream): uint32 =
    s.readUInt32()

  proc protoWriteSfixed64(s: Stream, x: int64) =
    s.write(x)

  proc protoReadSfixed64(s: Stream): int64 =
    s.readInt64()

  proc protoWriteSfixed64(s: Stream, x: int32) =
    s.write(x)

  proc protoReadSfixed32(s: Stream): int32 =
    s.readInt32()

  proc protoWriteString(s: Stream, x: string) =
    s.protoWriteInt64(x.len)
    for c in x:
      s.write(c)

  proc protoReadString(s: Stream): string =
    result = newString(s.protoReadInt64())
    for i in 0..<result.len:
      result[i] = s.readChar()

  proc protoWriteBytes(s: Stream, x: seq[uint8]) =
    s.protoWriteInt64(x.len)
    for c in x:
      s.write(c)

  proc protoReadBytes(s: Stream): seq[uint8] =
    result = newSeq[uint8](s.protoReadInt64())
    for i in 0..<result.len:
      result[i] = s.readUint8()

  proc protoWriteFloat(s: Stream, x: float32) =
    s.write(x)

  proc protoReadFloat(s: Stream): float32 =
    s.readFloat32()

  proc protoWriteDouble(s: Stream, x: float64) =
    s.write(x)

  proc protoReadDouble(s: Stream): float64 =
    s.readFloat64()


when isMainModule:
  import "../combparser/combparser"
  import lists

  proc ignorefirst[T](first: StringParser[string], catch: StringParser[T]): StringParser[T] =
    (first + catch).map(proc(input: tuple[f1: string, f2: T]): T = input.f2) / catch

  proc ignorelast[T](catch: StringParser[T], last: StringParser[string]): StringParser[T] =
    (catch + last).map(proc(input: tuple[f1: T, f2: string]): T = input.f1) / catch

  template ignoresides(first, catch, last: typed): untyped =
    ignorefirst(first, catch).ignorelast(last)

  proc andor(first, last: StringParser[string]): StringParser[string] =
    (first + last).map(proc(input: tuple[f1, f2: string]): string = input.f1 & input.f2) /
      (first / last)

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
      echo "This is a good mapping"
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

  let parsed = (number()).onerror("Unable to match numbers")("12-3;")
  echo parsed.value
  echo parsed.errors == nil
  echo parsed
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
          result.add name & definedEnum.enumName
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
      #of EnumVal:
      #  node.fieldName = parent.join(".") & "." & node.fieldName
      of Enum:
        #var name = parent & node.enumName
        #for enumVal in node.values:
        #  verifyAndExpandTypes(enumVal, validTypes, name)
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
          for message in node.messages:
            verifyAndExpandTypes(message, validTypes, name)
          for enu in node.packageEnums:
            verifyAndExpandTypes(enu, validTypes, name)

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

  proc valid(proto: ProtoNode) =
    ValidationAssert(proto.kind == File, "Validation must take an entire ProtoFile")
    ValidationAssert(proto.syntax == "proto3", "File must follow proto3 syntax")
    ValidationAssert(proto.package == nil, "Package support not implemented yet")
    var validTypes: seq[string]
    for message in proto.messages:
      verifyReservedAndUnique(message)
      validTypes = validTypes.concat message.getTypes()
    for message in proto.messages:
      verifyAndExpandTypes(message, validTypes)
    echo validTypes

  proc generateCode(proto: ProtoNode): NimNode {.compileTime.} =
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
            newIdentNode(node.oneofName.replace(".", "_") & "_Type"),
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
              newIdentNode(field.oneofName.replace(".", "_")),
              newIdentNode(field.oneofName.replace(".", "_") & "_Type"),
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
    proc generateProcs(node: ProtoNode, parent: var NimNode, defs: var NimNode) =
      case node.kind:
        of Message:
          let
            readName = newIdentNode("read" & node.messageName.replace(".", "_"))
            messageType = newIdentNode(node.messageName.replace(".", "_"))
          let procs = quote do:
            proc `readName`(s: Stream): `messageType`
            proc write(s: Stream, o: `messageType`)
          defs.add(procs)
          var procDefs = quote do:
            proc `readName`(s: Stream): `messageType`
            proc write(s: Stream, o: `messageType`)
          # Add a body to our procedures where we can put our statements
          procDefs[0][6] = newStmtList()
          procDefs[1][6] = newStmtList()
          for field in node.fields:
            if field.kind == Field:
              procDefs[0][6].add(
                nnkAsgn.newTree(
                  nnkDotExpr.newTree(
                    newIdentNode("result"),
                    newIdentNode(field.name)
                  ),
                  nnkCall.newTree(
                    if typeMapping.hasKey(field.protoType): typeMapping[field.protoType].read else: newIdentNode("read" & field.protoType.replace(".", "_")),
                    procDefs[0][3][1][0]
                  )
                )
              )
              procDefs[1][6].add(
                nnkCall.newTree(
                  newIdentNode("protoWriteInt64"),
                  procDefs[1][3][1][0],
                  newLit(field.number shl 3 or (if not field.repeated and typeMapping.hasKey(field.protoType): typeMapping[field.protoType].wire else: 2))
                )
              )
              if field.repeated or (typeMapping.hasKey(field.protoType) and typeMapping[field.protoType].wire == 2) or not typeMapping.hasKey(field.protoType)):
                procDefs[1][6].add(
                  nnkCall.newTree(
                    newIdentNode("protoWriteInt64"),
                    procDefs[1][3][1][0],
                    # TODO: Write the proper number here. For repeated fields, the sequences len. For other fields their corresponding length.
                    newLit(if field.repeated: else: and typeMapping.hasKey(field.protoType): typeMapping[field.protoType].wire else: 2)
                  )
                )
              procDefs[1][6].add(
                nnkCall.newTree(
                  if typeMapping.hasKey(field.protoType): typeMapping[field.protoType].write else: newIdentNode("write"),
                  procDefs[1][3][1][0],
                  nnkDotExpr.newTree(
                    procDefs[1][3][2][0], # The type argument from the declaration
                    newIdentNode(field.name)
                  )
                )
              )
          echo procs.toStrLit
          echo procDefs.toStrLit
        of ProtoDef:
          for node in node.packages:
            for message in node.messages:
              generateProcs(message, parent, defs)
        else:
          echo "Unsupported kind: " & $node.kind
          discard

    var
      typeBlock = newNimNode(nnkTypeSection)

    proto.generateTypes(typeBlock)
    var
      forwardDeclaratinons = newStmtList()
      implementations = newStmtList()
    proto.generateProcs(implementations, forwardDeclaratinons)
    echo typeBlock.toStrLit
    return typeBlock

  macro protoTest(file: static[string]): untyped =
  #block test:
  #when false:
    var
      protoStr = readFile("proto3.prot")
      protoParseRes = protofile()(protoStr)
      protoParsed = protoParseRes.value[0]
    echo "Errors: \"" & protoParseRes.getShortError() & "\""

    protoParsed.expandToFullDef()

    echo protoParsed
    var validTypes = protoParsed.getTypes()
    echo validTypes
    protoParsed.verifyAndExpandTypes(validTypes)
    echo protoParsed
    return generateCode(protoParsed)

    #if protoParsed.valid:
    #  echo "File is valid!"

  protoTest("proto3.prot")

when false:
  import strutils

  var
    stream = newStringStream()
  stream.protoWrite 0.int64
  assert(stream.getPosition == 1, "Wrote more than 1 byte for the value 0")
  stream.setPosition(0)
  assert(stream.protoReadInt64() == 0, "Read a different value than 0 for the value 0")
  stream.setPosition(0)
  stream.protoWrite 128.int64
  assert(stream.getPosition == 2, "Wrote more or less than 2 bytes for the value 128")
  stream.setPosition(0)
  assert(stream.protoReadInt64() == 128, "Read a different value than 128 for the value 128")
  stream.setPosition(0)
  stream.protoWrite -128.int64
  assert(stream.getPosition == 10, "Wrote more or less than 10 bytes for the value -128")
  stream.setPosition(0)
  assert(stream.protoReadInt64() == -128, "Read a different value than -128 for the value -128")
  stream.setPosition(0)
  stream.protoWrite 0.sint64
  assert(stream.getPosition == 1, "Wrote more or less than 1 bytes for the value 0")
  stream.setPosition(0)
  assert(stream.protoReadSint64().int64 == 0, "Read a different value than 0 for the value 0")
  stream.setPosition(0)
  stream.protoWrite 128.sint64
  assert(stream.getPosition == 2, "Wrote more or less than 2 bytes for the value 128")
  stream.setPosition(0)
  assert(stream.protoReadSint64().int64 == 128, "Read a different value than 128 for the value 128")
  stream.setPosition(0)
  stream.protoWrite (-128).sint64
  assert(stream.getPosition == 2, "Wrote more or less than 2 bytes for the value -128")
  stream.setPosition(0)
  assert(stream.protoReadSint64().int64 == -128, "Read a different value than -128 for the value -128")

when false:
  var
    ss = newStringStream()
    num = (0x99_e1).VarInt
  ss.write(num)
  ss.setPosition(0)
  let vi = ss.readVarInt()
  echo vi.toHex
  echo vi.uint64
  echo "--"

  var
    x = 1000
    y = -1000
  echo(((x shl 1) xor (x shr 31)).uint32)
  echo(((y shl 1) xor (y shr 31)).uint32)
  let
    num2 = (-2147483648).SVarInt
    pos = ss.getPosition()
  ss.write(num2)
  ss.setPosition(pos)
  let svi = ss.readSVarInt()
  echo "---"
  echo $svi.int64
  echo "----"

  ss.setPosition(0)
  for c in ss.readAll():
    echo c.toHex
  for i in countup(0, 1000, 255):
    echo $i & ":\t" & $(i.VarInt.hob)

  import strutils, pegs
  # Read in the protobuf specification
  var proto = readFile("proto3.prot")
  # Remove the comments
  proto = proto.replacef(peg"'/*' @ '*/' / '//' @ \n / \n", "")
  type
    ProtoSymbol = enum
      Undefined
      Syntax = "syntax", Proto2 = "proto2", Proto3 = "proto3"
      Int32 = "int32", Int64 = "int64", Uint32 = "uint32"
      Uint64 = "uint64", Sint32 = "sint32", Sint64 = "sint64"
      Bool = "bool", Enum = "enum", Fixed64 = "fixed64", Sfixed64 = "sfixed64"
      Fixed32 = "fixed32", Sfixed32 = "sfixed32", Bytes = "bytes"
      Double = "double", Float = "float", String = "string"
      Message = "message", Reserved = "reserved", Repeated = "repeated"
      Option = "option", Import = "import", OneOf = "oneof", Map = "map"
      Package = "package", Service = "service", RPC = "rpc", Returns = "returns"

    FieldNode = ref object
      name: string
      kind: ProtoSymbol
      num: int

    MessageNode = ref object
      name: string
      fields: seq[FieldNode]

  const
    ProtoTypes = {Int32, Int64, Uint32, Uint64, Sint32, Sint64, Fixed32, Fixed64,
      Sfixed32, Sfixed64, Bool, Bytes, Enum, Float, Double, String}
    Unimplemented = {Option, Import, OneOf, Map, Package, Service, RPC, Returns, Proto2, Reserved, Repeated}
    FirstToken = {Syntax, Message, Service, Package, Import}
    SyntaxSpecifier = {Proto2, Proto3}

  proc contains(x: set[ProtoSymbol], y: string): bool =
    for s in x:
      if y == $s:
        return true
    return false

  proc startsWith(x: string, y: set[ProtoSymbol]): bool =
    for s in y:
      if x.startsWith($s):
        return true
    return false

  var
    syntax: ProtoSymbol
    currentMessage: MessageNode
    blockLevel = 0
  # Tokenize
  for t in proto.tokenize({'{', '}', ';'}):
    if t.token.isSpaceAscii:
      continue
    let
      token = t.token.strip
      isSep = t.isSep
    if syntax == Undefined:
      let s = token.split('=')
      assert(s.len == 2, "First non-empty, non-comment statement must be a syntax specifier.")
      assert(s[0].strip == $Syntax, "First non-empty, non-comment statement must be a syntax specifier.")
      var specifier = s[1].strip
      assert(specifier[0] == '"' and specifier[^1] == '"', "Unknown syntax " & $specifier)
      specifier = specifier[1..^2]
      assert(specifier in SyntaxSpecifier, "Unknown syntax " & $specifier)
      assert(specifier notin Unimplemented, "This parser does not support syntax " & $specifier)
      syntax = parseEnum[ProtoSymbol](specifier)
    else:
      if isSep:
        for c in token:
          if c == '{':
            blockLevel += 1
          if c == '}':
            blockLevel -= 1
      else:
        if blockLevel == 0:
          if token.startsWith(Unimplemented):
            stderr.write("Unimplemented feature: " & token & "\n")
            continue
          assert(token.startsWith(FirstToken), "Misplaced token \"" & token & "\"")
          if token.startsWith($Message):
            assert(currentMessage == nil, "Recursive message not allowed: " & token)
            currentMessage = new MessageNode
            let s = token.split()
            assert(s.len == 2, "Unknown message syntax, only \"message <identifier>\" is allowed: " & token)
            currentMessage.name = s[1]
            currentMessage.fields = @[]
          continue
        else:
          echo $blockLevel & " token: " & $token
          if token.startsWith(Unimplemented):
            stderr.write("Unimplemented feature: " & token & "\n")
            continue
          if currentMessage == nil:
            continue
          if not token.startsWith(ProtoTypes):
            stderr.write("Unknown type in message, currently only basic types are allowed: " & token & "\n")
            continue
          let s = token.split()
          if token.startsWith($Enum):
            stderr.write("Enums not implemented yet: " & $token & "\n")
            continue
          assert(s.len == 4, "Unknown definition of basic type: " & $token)
          assert(s[2] == "=", "Basic type needs field number: " & $token)
          var field = new FieldNode
          field.name = s[1]
          field.kind = parseEnum[ProtoSymbol](s[0])
          assert(field.kind in ProtoTypes, "Unknown type: " & token)
          field.num = parseInt(s[3])
          currentMessage.fields.add field



  echo syntax
  if currentMessage != nil:
    echo currentMessage.name
    for field in currentMessage.fields:
      echo field.name

