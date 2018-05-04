
template getField(obj: untyped, pos: int, field: untyped, name: string): untyped =
  if not obj.fields.contains(pos): raise newException(ValueError, "Field \"" & name & "\" isn't initialized")
  obj.field

{.experimental.}
import macros

template makeDot(kind, fieldArr: untyped): untyped =
  macro `.`(obj: kind, field: untyped): untyped =
    let
      fname = $field
      newField = newIdentNode("private_" & fname)
      idx = fieldArr.find(fname)
    assert idx != -1, "Couldn't find field in object"
    result = nnkStmtList.newTree(
      nnkCall.newTree(
        nnkDotExpr.newTree(
          obj,
          newIdentNode("getField")
        ),
        newLit(idx),
        newField,
        newLit(fname)
      )
    )

  macro `.=`(obj: kind, field: untyped, value: untyped): untyped =
    let
      fname = $field
      newField = newIdentNode("private_" & fname)
      idx = fieldArr.find(fname)
    assert idx != -1, "Couldn't find field in object"
    result = nnkStmtList.newTree(
      nnkCommand.newTree(
        nnkDotExpr.newTree(
          nnkDotExpr.newTree(
            obj,
            newIdentNode("fields")
          ),
          newIdentNode("incl")
        ),
        newLit(idx)
      ),
      nnkAsgn.newTree(
        nnkCall.newTree(
          nnkDotExpr.newTree(
            obj,
            newIdentNode("getField")
          ),
          newLit(idx),
          newField,
          newLit(fname)
        ),
        value
      )
    )

macro createAll(): untyped =
  proc test(): NimNode =
    let optObject = newIdentNode("OptObject")
    result = quote do:
      type
        `optObject` = ref object
          fields: set[range[0..2]]
          private_fieldNull: int
          private_fieldOne: string
          private_fieldTwo: `optObject`
    result = newStmtList(result, getAst(makeDot(`optObject`, ["fieldNull", "fieldOne", "fieldTwo"])))
  return test()

createAll()

proc createOpt(): OptObject =
  result = new OptObject
  result.fieldNull = 50

var y = createOpt()
echo y.fieldNull

var z = new OptObject
z.fieldNull = 42
z.fieldTwo = new OptObject
z.fieldTwo.fieldNull = 30
echo z.fieldNull
echo z.fieldTwo.fieldNull
