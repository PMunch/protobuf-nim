import streams, strutils, sequtils, macros

type
  VarInt = distinct uint64
  SVarInt = distinct int64

when cpuEndian == littleEndian:
  proc hob(x: VarInt): int =
    result = x.int
    result = result or (result shr 1)
    result = result or (result shr 2)
    result = result or (result shr 4)
    result = result or (result shr 8)
    result = result or (result shr 16)
    result = result or (result shr 32)
    result = result - (result shr 1)

  proc write(s: Stream, x: VarInt) =
    var
      bytes = x.hob shr 7
      num = x.int64
    s.write((num and 0x7f or 0x80).uint8)
    while bytes > 0:
      num = num shr 7
      bytes = bytes shr 7
      s.write((num and 0x7f or (if bytes > 0: 0x80 else: 0)).uint8)

  proc readVarInt(s: Stream): VarInt =
    var
      byte = s.readInt8()
      i = 1
    result = (byte and 0x7f).VarInt
    while (byte and 0x80) != 0:
      # TODO: Add error checking for values not fitting 64 bits
      byte = s.readInt8()
      result = (result.uint64 or ((byte.uint64 and 0x7f) shl (7*i))).VarInt
      i += 1

  proc write(s: Stream, x: SVarInt) =
    # TODO: Ensure that this works for all int64 values
    var t = x.int64 * 2
    if x.int64 < 0:
      t = t xor -1
    s.write(t.VarInt)

  proc readSVarInt(s: Stream): SVarInt =
    let y = s.readVarInt().uint64
    return ((y shr 1) xor (if (y and 1) == 1: (-1).uint64 else: 0)).SVarInt

when isMainModule:
  import "../combparser/combparser"
  import lists

  proc ignorefirst[T](first: StringParser[string], catch: StringParser[T]): StringParser[T] =
    (first + catch).map(proc(input: tuple[f1: string, f2: T]): T = input.f2) / catch

  proc ignorelast[T](catch: StringParser[T], last: StringParser[string]): StringParser[T] =
    (catch + last).map(proc(input: tuple[f1: T, f2: string]): T = input.f1) / catch

  proc andor(first, last: StringParser[string]): StringParser[string] =
    (first + last).map(proc(input: tuple[f1, f2: string]): string = input.f1 & input.f2) /
      (first / last)

  proc ws(value: string): StringParser[string] =
    regex(r"\s*" & value & r"\s*")

  proc combine(list: seq[string], sep: string): string =
    result = ""
    for entry in list:
      result = result & entry & sep
    result = result[0..^(sep.len + 1)]

  proc combine(list: seq[string]): string =
    list.combine("")

  proc combine(t: tuple[f1, f2: string]): string = t.f1 & t.f2

  proc combine[T](t: tuple[f1: T, f2: string]): string = t.f1.combine() & t.f2

  proc combine[T](t: tuple[f1: string, f2: T]): string = t.f1 & t.f2.combine()

  proc combine[T, U](t: tuple[f1: T, f2: U]): string = t.f1.combine() & t.f2.combine()

  proc endcomment(): StringParser[string] = regex(r"\s*//.*\s*").repeat(1).map(combine)

  proc inlinecomment(): StringParser[string] = regex(r"\s*/\*.*\*/\s*").repeat(1).map(combine)

  proc comment(): StringParser[string] = andor(endcomment(), inlinecomment()).repeat(1).map(combine)

  proc endstatement(): StringParser[string] =
    ignorefirst(inlinecomment(), ws(";")).ignorelast(comment())

  proc str(): StringParser[string] =
    ignorefirst(inlinecomment(), regex(r"\s*\""[^""]*\""\s*")).map(
      proc(n: string): string =
        n.strip()[1..^2]
    ).ignorelast(comment())

  proc number(): StringParser[string] = regex(r"\s*[0-9]+\s*").map(proc(n: string): string =
    n.strip())

  proc strip(input: string): string =
    input.strip(true, true)

  proc enumname(): StringParser[string] =
    ignorefirst(comment(), regex(r"\s*[A-Z]*\s*")).ignorelast(comment()).map(strip)

  proc token(): StringParser[string] =
    ignorefirst(comment(), regex(r"\s*[a-z][a-zA-Z0-9_]*\s*")).ignorelast(comment()).map(strip)

  proc token(name: string): StringParser[string] =
    ignorefirst(comment(), ws(name)).ignorelast(comment()).map(strip)

  proc class(): StringParser[string] =
    ignorefirst(comment(), regex(r"\s*[A-Z][a-zA-Z0-9_]*\s*")).ignorelast(comment()).map(strip)

  proc typespecifier(): StringParser[string] =
    ignorefirst(comment(), regex(r"\s*[A-Za-z0-9_\.]*\s*")).ignorelast(comment()).map(strip)

  type
    ReservedType = enum
      String, Number, Range
    ProtoField = ref object
      number: int
      kind: string
      name: string
      repeated: bool
    ProtoEnum = ref object
      name: string
      values: seq[ProtoEnumField]
    ProtoEnumField = ref object
      name: string
      number: int
    ProtoReserved = ref object
      reservedValues: seq[ProtoReservedField]
    ProtoReservedField = ref object
      case reservedKind*: ReservedType
      of ReservedType.String:
        strVal: string
      of ReservedType.Number:
        intVal: int
      of ReservedType.Range:
        startVal: int
        endVal: int
    ProtoMessage = ref object
      name: string
      reserved: seq[ProtoReserved]
      definedEnums: seq[ProtoEnum]
      fields: seq[ProtoField]
      nested: seq[ProtoMessage]
    ProtoFile = ref object
      syntax: string
      messages: seq[ProtoMessage]
    ProtoTest = ProtoReserved or ProtoField
    StringParserTest = StringParser[ProtoReserved] or StringParser[ProtoField]
    #ProtoNode = ProtoField or ProtoEnum or ProtoEnumField or ProtoReserved or ProtoReserved or ProtoReservedField or ProtoMessage or ProtoFile

  proc `$`(node: ProtoField): string =
    result = "Field $1 of type $2 with index $3".format(
      node.name,
      node.kind,
      node.number)
    if node.repeated:
      result &= " is repeated"

  proc `$`(node: ProtoEnumField): string =
    result = "Enum field $1 with index $2".format(
      node.name,
      node.number)

  proc `$`(node: ProtoEnum): string =
    result = "Enum $1 has values:\n".format(
      node.name)
    var fields = ""
    for field in node.values:
      fields &= $field & "\n"
    result &= fields[0..^2].indent(1, "  ")

  proc `$`(node: ProtoReservedField): string =
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

  proc `$`(node: ProtoReserved): string =
    result = "Reserved values:\n"
    var reserved = ""
    for value in node.reservedValues:
      reserved &= $value & "\n"
    result &= reserved.indent(1, "  ")

  proc `$`(node: ProtoMessage): string =
    result = "Message $1 with data:".format(
      node.name)
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

  proc `$`(node: ProtoFile): string =
    result = "Protobuf file with syntax $1 and messages:\n".format(
      node.syntax)
    var body = ""
    for message in node.messages:
      body &= $message
      result &= body.indent(1, "  ")
      body = "\n"

  proc syntaxline(): StringParser[string] = (token("syntax") + ws("=") + str() + endstatement()).map(
    proc (stuple: auto): string =
      stuple[0][1]
  )

  proc declaration(): StringParser[ProtoField] = (optional(ws("repeated")) + typespecifier() + token() + ws("=") + number() + endstatement()).map(
    proc (input: auto): ProtoField =
      result = ProtoField(number: parseInt(input[0][1]), name: input[0][0][0][1], kind: input[0][0][0][0][1], repeated: input[0][0][0][0][0] != nil)
  )

  proc reserved(): StringParser[ProtoReserved] =
    (token("reserved") + (((number() + ws("to") + (number() / ws("max"))).ignorelast(ws(",")).map(
      proc (input: auto): ProtoReservedField =
        let
          f = parseInt(input[0][0])
          t = if input[1] == "max": Natural.high else: parseInt(input[1])
        ProtoReservedField(reservedKind: ReservedType.Range, startVal: f, endVal: t)
    ) / (number().ignorelast(ws(","))).map(
      proc (input: auto): ProtoReservedField =
        ProtoReservedField(reservedKind: ReservedType.Number, intVal: parseInt(input))
    )).repeat(1).map(
      proc (input: auto): ProtoReserved =
        result = ProtoReserved(reservedValues: @[])
        for reserved in input:
          result.reservedValues.add reserved
    ) / (str().ignorelast(ws(","))).repeat(1).map(
      proc (input: auto): ProtoReserved =
        result = ProtoReserved(reservedValues: @[])
        for str in input:
          result.reservedValues.add ProtoReservedField(reservedKind: ReservedType.String, strVal: str)
    )) + endstatement()).map(
      proc (input: auto): ProtoReserved =
        input[0][1]
    )

  proc enumvals(): StringParser[ProtoEnumField] = (enumname() + ws("=") + number() + endstatement()).map(
    proc (input: auto): ProtoEnumField =
      result = ProtoEnumField(name: input[0][0][0], number: parseInt(input[0][1]))
  )

  proc enumblock(): StringParser[ProtoEnum] = (token("enum") + class() + ws("{") + enumvals().repeat(1) + ws("}")).map(
    proc (input: auto): ProtoEnum =
      result = ProtoEnum(name: input[0][0][0][1], values: input[0][1])
  )

  proc messageblock(): StringParser[ProtoMessage] = (token("message") + class() + ws("{") + (declaration() / reserved() / enumblock() / token("message").flatMap(
    proc(msg: string): StringParser[ProtoMessage] =
      (proc (rest: string): Maybe[(ProtoMessage, string), string] =
        messageblock()(msg & " " & rest)
      )
    )).repeat(0) + ws("}")).map(
      proc (input: auto): ProtoMessage =
        result = ProtoMessage(name: input[0][0][0][1], reserved: @[], definedEnums: @[], fields: @[], nested: @[])
        for thing in input[0][1]:
          when thing of ProtoReserved:
            result.reserved = result.reserved.concat(thing.resValues)
          when thing of ProtoEnum:
            result.definedEnums.add thing
          when thing of ProtoField:
            result.fields.add thing
          when thing of Message:
            result.nested.add thing
    )

  proc protofile(): StringParser[ProtoNode] = (syntaxline() + messageblock().repeat(1)).map(
    proc (input: auto): ProtoNode =
      result = ProtoNode(kind: File, syntax: input[0], messages: @[])
      for message in input[1]:
        result.messages.add message
  )

  #echo parse(ignorefirst(comment(), s("syntax")) , "syntax = \"This is syntax\";")
  echo parse(optional(ws("hello")) + ws("world"), "hello world")
  echo parse(optional(ws("hello")) + ws("world"), " world")
  echo parse(syntaxline(), "syntax = \"This is syntax\";")
  echo parse(declaration(), "int32 syntax = 5;")
  echo parse(typespecifier(), "This.Is.Atest")
  echo parse(declaration(), "This.Is.Atest name = 5;")
  echo parse(reserved(), "reserved 5;")
  echo parse(reserved(), "reserved 5, 7;")
  echo parse(reserved(), "reserved 5, 7 to max;")
  echo parse(reserved(), "reserved \"foo\";")
  echo parse(reserved(), "reserved \"foo\", \"bar\";")
  echo parse(enumvals(), "TEST = 4;")
  echo parse(enumblock(), """enum Test {
    TEST = 5;
    FOO = 6;
    BAR = 9;
  }
  """")

  var
    protoStr = readFile("proto3.prot")
    protoParsed = parse(protofile(), protoStr)

  type ValidationError = object of Exception

  type
    Test1 = int
    Test2 = string
    Test3 = Test1 | Test2

  proc t(b: Test1) =
    echo "Int: " & $b

  proc s(b: Test2) =
    echo "String: " & b

  proc c(b: Test3) =
    when b is Test1:
      t(b)
    else:
      s(b)

  var
    t1: Test1 = 6
    t2: Test2 = "Hello"

  c(t1)
  c(t2)

  proc ValidationAssert(statement: bool, error: string) =
    if not statement:
      raise newException(ValidationError, error)

  proc getTypes(message: ProtoNode, parent = ""): seq[string] =
    ValidationAssert(message.kind == Message, "ProtoBuf messages field contains something else than messages")
    result = @[]
    let name = (if parent != "": parent & "." else: "") & message.messageName
    for definedEnum in message.definedEnums:
      ValidationAssert(definedEnum.kind == Enum, "Field for defined enums contained something else than a message")
      result.add name & "." & definedEnum.enumName
    for innerMessage in message.nested:
      result = result.concat innerMessage.getTypes(name)
    result.add name

  proc verifyReserved(message: ProtoNode): bool =
    ValidationAssert(message.kind == Message, "ProtoBuf messages field contains something else than messages")
    for field in message.fields:
      ValidationAssert(field.kind == Field, "Field for defined fields contained something else than a field")

  proc valid(proto: ProtoNode): bool =
    ValidationAssert(proto.kind == File, "Validation must take an entire ProtoFile")
    ValidationAssert(proto.syntax == "proto3", "File must follow proto3 syntax")
    var validTypes = @["int32", "int64", "uint32", "uint64", "sint32", "sint64", "fixed32",
      "fixed64", "sfixed32", "sfixed64", "bool", "bytes", "enum", "float", "double", "string"]
    for message in proto.messages:
      validTypes = validTypes.concat message.getTypes()
    echo validTypes


  if protoParsed.valid:
    echo "File is valid!"


when false:#isMainModule:
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

