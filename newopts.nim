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

{.experimental.}
template dotBody(obj, idx, newName, name: untyped): untyped =
  if obj.fields.contains(idx):
    obj.newName
  else:
    raise newException(ValueError, "OptObject has not initialized field " & name)

template dotEqBody(obj, idx, newName, val: untyped): untyped =
  obj.fields.incl idx
  obj.newName = val

template makeDot(kind, fieldArr: untyped): untyped =
  macro `.`(obj: kind, fname: untyped): untyped =
    expectKind(fname, nnkIdent)
    let
      name = $fname
      newName = newIdentNode("private_" & name)
      idx = fieldArr.find(name)
    assert(idx != -1, "No such field in object: " & name)
    result = getAst(dotBody(obj, idx, newName, name))

  macro `.=`(obj: kind, fname: untyped, val: untyped): untyped =
    expectKind(fname, nnkIdent)
    let
      name = $fname
      newName = newIdentNode("private_" & name)
      idx = fieldArr.find(name)
    assert(idx != -1, "No such field in object: " & name)
    result = getAst(dotEqBody(obj, idx, newName, val))

proc genHelpersImpl(typeName: NimNode, fieldNames: openarray[string]): NimNode {.compileTime.} =
  let
    macroName = newIdentNode("init" & $typeName)
    i = genSym(nskForVar)
    x = newIdentNode("field")
    obj = newIdentNode("obj")
    value = newIdentNode("value")
    typeStr = $typeName
    res = newIdentNode("result")
    fieldsSym = genSym(nskVar)
    fieldsLen = fieldNames.len - 1
  var
    initialiserCases = quote do:
      case $`i`[0]:
      else:
        discard
    setterCases = quote do:
      case `x`:
      else:
        discard
    getterCases = quote do:
      case `x`:
      else:
        discard
  var j = 0
  for field in fieldNames:
    let
      newFieldStr = "private_" & field
    initialiserCases.add((quote do:
      case 0:
      of `field`:
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
          newIdentNode(`newFieldStr`),
          `i`[1]
        )
    )[1])
    setterCases.add((quote do:
      case 0:
      of `field`:
        `res`.add(
          nnkCommand.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                `obj`,
                `fieldsSym`
              ),
              newIdentNode("incl")
            ),
            newLit(`j`)
          ),
          nnkAsgn.newTree(
            nnkDotExpr.newTree(
              `obj`,
              newIdentNode(`newFieldStr`)
            ),
            newIdentNode("value")
          )
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
        `initialiserCases`
      `res`.add nnkExprColonExpr.newTree(
        newIdentNode("fields"),
        `fieldsSym`
      )
    makeDot(`typeName`, `fieldNames`)

macro genHelpers(typeName: untyped, fieldNames: static[openarray[string]]): untyped =
  result = newStmtList()
  var x: seq[string] = @[]
  for y in fieldNames:
    x.add y
  result.add genHelpersImpl(typeName, x)
  echo result.repr
#genAccessors(fieldNull, 0, int, OptObject)
#genAccessors(fieldOne, 1, string, OptObject)
#genAccessors(fieldTwo, 2, char, OptObject)
#genAccessors(fieldThree, 3, NestedOpt, OptObject)
#genInitialiser(OptObject, fieldNull, fieldOne, fieldTwo, fieldThree)
#genAccessors(fieldNull, 0, seq[int], NestedOpt)
#genAccessors(fieldOne, 1, string, NestedOpt)
genHelpers(NestedOpt, ["fieldNull", "fieldOne"])
genHelpers(OptObject, ["fieldNull", "fieldOne", "fieldTwo", "fieldThree"])


#makeDot(NestedOpt, ["fieldNull", "fieldOne"])
#makeDot(OptObject, ["fieldNull", "fieldOne", "fieldTwo", "fieldThree"])

var q = initNestedOpt(fieldOne = "string", fieldNull = @[5])
echo q.fieldOne
echo q.fieldNull

var x = initOptObject(fieldNull = 100, fieldOne = "Hello world")
var y = new NestedOpt
y.fieldNull = @[32]
y.fieldNull.add(100)
x.fieldThree = y
x.fieldThree.fieldNull = @[10]
#x.fieldThree = NestedOpt(fieldNull: 10)

echo x.fieldNull
echo x.fieldThree.fieldNull
