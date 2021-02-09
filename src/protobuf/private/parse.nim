import combparser, strutils, sequtils, macros
import decldef

when (NimMajor, NimMinor) < (1, 4):
  type AssertionDefect = AssertionError

proc combine(list: seq[string], sep: string): string =
  result = ""
  for entry in list:
    result = result & entry & sep
  result = result[0..^(sep.len + 1)]

proc combine(list: seq[string]): string =
  list.combine("")

proc combine(t: tuple[f1, f2: string]): string =
  if t.f1.len == 0:
    t.f2
  elif t.f2.len == 0:
    t.f1
  else:
    t.f1 & t.f2

proc combine[T](t: tuple[f1: T, f2: string]): string =
  if t.f2.len == 0:
    t.f1.combine()
  else:
    t.f1.combine() & t.f2

proc combine[T](t: tuple[f1: string, f2: T]): string =
  if t.f1.len == 0:
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

proc token(): StringParser[string] =
  ignoresides(comment(),
    (
      ignorefirst(charmatch(Whitespace), charmatch({'a'..'z', 'A'..'Z'})) +
      ignorelast(optional(charmatch({'a'..'z', 'A'..'Z', '0'..'9', '_'})), charmatch(Whitespace))
    ).map(combine)
  , comment())

proc token(name: string): StringParser[string] =
  ignoresides(comment(), ws(name), comment()).map(strip)

proc typespecifier(): StringParser[string] =
  ignoresides(comment(),
    (
      optwhitespace(charmatch({'a'..'z', 'A'..'Z', '0'..'9', '_', '.'}))
    )
  , comment())

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
    result = ProtoNode(kind: Field, number: parseInt(input[0][1]), name: input[0][0][0][1], protoType: input[0][0][0][0][1], repeated: input[0][0][0][0][0] != "")
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

proc enumvals(): StringParser[ProtoNode] = (token() + ws("=") + number() + endstatement()).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: EnumVal, fieldName: input[0][0][0], num: parseInt(input[0][1]))
).onerror("Unable to parse enumval")

proc enumblock(): StringParser[ProtoNode] = (token("enum") + token() + ws("{") + enumvals().repeat(1) + ws("}")).ignorelast(s(";")).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: Enum, enumName: input[0][0][0][1], values: input[0][1])
)

proc oneof(): StringParser[ProtoNode] = (token("oneof") + token() + ws("{") + declaration().repeat(1) + ws("}")).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: Oneof, oneofName: input[0][0][0][1], oneof: input[0][1])
)

proc messageblock(): StringParser[ProtoNode] = (token("message") + token() + ws("{") + (oneof() / declaration() / reserved() / enumblock() / token("message").flatMap(
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

proc protofile*(): StringParser[ProtoNode] = (syntaxline() + optional(package()) + (messageblock() / importstatement() / enumblock()).repeat(1)).map(
  proc (input: auto): ProtoNode =
    result = ProtoNode(kind: ProtoType.File, syntax: input[0][0], imported: @[], package: ProtoNode(kind: Package, packageName: input[0][1], messages: @[], packageEnums: @[]))
    for message in input[1]:
      case message.kind:
        of Message:
          result.package.messages.add message
        of Imported:
          result.imported.add message
        of Enum:
          result.package.packageEnums.add message
        else: raise newException(AssertionDefect, "Unsupported node kind: " & $message.kind)
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

proc parseToDefinition*(spec: string): ProtoNode =
  var protoParseRes = protofile()(spec)
  result = protoParseRes.value[0]
  let shortErr = protoParseRes.getShortError()
  if shortErr.len != 0:
    echo "Errors: \"" & shortErr & "\""

  result.expandToFullDef()
