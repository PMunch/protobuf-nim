type
  NestedOpt = ref object
    fields: set[range[0..1]]
    private_fieldNull: seq[int]
    private_fieldOne: string
  OptObject = ref object
    fields: set[range[0..3]]
    private_fieldNull: int
    private_fieldOne: string
    private_fieldTwo: char
    private_fieldThree: NestedOpt

import macros
template genAccessors(name: untyped, index: untyped, fieldType, objType: typedesc): untyped =
  # Access
  proc name*(obj: objType): fieldType {.noSideEffect, inline, noInit.} =
    if obj.fields.contains(index):
      return obj.`private name`
    else:
      raise newException(ValueError, "OptObject has not initialized field")

  # Assignement
  proc `name=`*(obj: var objType, value: fieldType) {.noSideEffect, inline.} =
    obj.fields.incl index
    obj.`private name` = value

  # Mutable
  proc name*(obj: var objType): var fieldType {.noSideEffect, inline.} =
    if obj.fields.contains(index):
      return obj.`private name`
    else:
      raise newException(ValueError, "OptObject has not initialized field")

macro genInitialiser(typeName: untyped, fieldNames: varargs[untyped]): untyped =
  let
    macroName = newIdentNode("init" & $typeName)
    i = genSym(nskForVar)
    typeStr = $typeName
    res = newIdentNode("result")
    fieldsSym = genSym(nskVar)
    fieldsLen = fieldNames.len - 1
  var caseStmt = quote do:
    case $`i`[0]:
    else:
      discard
  var j = 0
  for field in fieldNames:
    let fieldStr = $field
    caseStmt.add((quote do:
      case 0:
      of `fieldStr`:
        `fieldsSym`.add nnkCall.newTree(
            nnkBracketExpr.newTree(
              newIdentNode("range"),
              nnkInfix.newTree(
                newIdentNode(".."),
                newLit(0),
                newLit(`fieldsLen`)
              )
            ),
            newLit(`j`)
          )
        `res`.add nnkExprColonExpr.newTree(
          newIdentNode("private_" & `fieldStr`),
          `i`[1]
        )
    )[1])
    j += 1

  result = quote do:
    macro `macroName`(x: varargs[untyped]): untyped =
      `res` = nnkObjConstr.newTree(
        newIdentNode(`typeStr`)
      )
      var `fieldsSym` = newNimNode(nnkCurly)
      for `i` in x:
        `i`.expectKind(nnkExprEqExpr)
        `i`[0].expectKind(nnkIdent)
        `caseStmt`
      `res`.add nnkExprColonExpr.newTree(
        newIdentNode("fields"),
        `fieldsSym`
      )

genAccessors(fieldNull, 0, int, OptObject)
genAccessors(fieldOne, 1, string, OptObject)
genAccessors(fieldTwo, 2, char, OptObject)
genAccessors(fieldThree, 3, NestedOpt, OptObject)
genInitialiser(OptObject, fieldNull, fieldOne, fieldTwo, fieldThree)
#genAccessors(fieldNull, 0, seq[int], NestedOpt)
#genAccessors(fieldOne, 1, string, NestedOpt)
genInitialiser(NestedOpt, fieldNull, fieldOne)

{.experimental.}
#template `.`(obj: NestedOpt, fname: string): string =
#  echo fname
#  "Hello world"
macro `.`(obj: NestedOpt, fname: untyped): untyped =
  expectKind(fname, nnkIdent)
  let
    name = $fname
    newName = newIdentNode("private_" & name)
    idx = ["fieldNull", "fieldOne"].find(name)
  assert(idx != -1, "No such field in NestedOpt: " & name)
  result = quote do:
    if `obj`.fields.contains(`idx`):
      `obj`.`newName`
    else:
      raise newException(ValueError, "OptObject has not initialized field " & `name`)

macro `.=`(obj: NestedOpt, fname: untyped, val: untyped): untyped =
  expectKind(fname, nnkIdent)
  let
    name = $fname
    newName = newIdentNode("private_" & name)
    idx = ["fieldNull", "fieldOne"].find(name)
  assert(idx != -1, "No such field in NestedOpt: " & name)
  result = quote do:
    `obj`.fields.incl `idx`
    `obj`.`newName` = `val`

var q = initNestedOpt(fieldOne = "string", fieldNull = @[5])
echo q.fieldOne
echo q.fieldNull

var x = initOptObject(fieldNull = 100, fieldOne = "Hello world")
var y = new NestedOpt
y.fieldNull = @[32]
x.fieldThree = y
x.fieldThree.fieldNull = @[10]
#x.fieldThree = NestedOpt(fieldNull: 10)

echo x.fieldNull
echo x.fieldThree.fieldNull
