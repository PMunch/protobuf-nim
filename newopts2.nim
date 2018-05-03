type
  MyObj = ref object
    private_fieldA: int
    private_hasFieldA: bool
    private_fieldB: MyObj
  OptObject = ref object
    fields: set[range[0..3]]
    private_fieldNull: int
    private_fieldOne: string
    private_fieldTwo: char

template getField(obj: MyObj, field: static[string]): untyped =
  when field == "fieldB":
    obj.private_fieldB
  elif field == "fieldA":
    assert obj.private_hasFieldA, "Doesn't have field A"
    obj.private_fieldA
  else:
    obj.private_hasFieldA

template getField(obj: OptObject, field: static[string]): untyped =
  when field == "fieldNull":
    assert obj.fields.contains(0), "Doesn't have fieldNull"
    obj.private_fieldNull
  elif field == "fieldOne":
    assert obj.fields.contains(1), "Doesn't have fieldOne"
    obj.private_fieldOne
  elif field == "fieldTwo":
    assert obj.fields.contains(2), "Doesn't have fieldTwo"
    obj.private_fieldTwo

{.experimental.}
import macros
macro `.`(obj: MyObj, field: untyped): untyped =
  let fname = $field
  quote do:
    `obj`.getField(`fname`)

macro `.`(obj: OptObject, field: untyped): untyped =
  let fname = $field
  quote do:
    `obj`.getField(`fname`)

macro `.=`(obj: MyObj, field: untyped, value: untyped): untyped =
  let fname = $field
  if fname != "fieldA":
    quote do:
      `obj`.getField(`fname`) = `value`
  else:
    quote do:
      `obj`.private_hasFieldA = true
      `obj`.getField(`fname`) = `value`

macro `.=`(obj: OptObject, field: untyped, value: untyped): untyped =
  let
    fname = $field
    idx = ["fieldNull", "fieldOne", "fieldTwo"].find(fname)
  assert idx != -1, "Couldn't find field in object"
  quote do:
    `obj`.fields.incl `idx`
    `obj`.getField(`fname`) = `value`

var x = new MyObj
x.fieldB = new MyObj
x.fieldB.fieldA = 10

var y = new MyObj
y.getField("fieldB") = new MyObj
y.getField("fieldB").getField("hasFieldA") = true
y.getField("fieldB").getField("fieldA") = 10

echo x.fieldB.fieldA
echo y.getField("fieldB").getField("fieldA")
echo y.fieldB.fieldA

var z = new OptObject
z.fieldNull = 42
echo z.fieldNull
