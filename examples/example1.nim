import "../src/protobuf"
import streams
import strutils

const Printable = {' '..'~'}

proc echoDataStream(stream: Stream) =
  stream.setPosition(0)
  var
    pos = 0
    strRepr = "   "
  while not stream.atEnd:
    let num = stream.readUint8()
    stdout.write num.toHex() & " "
    strRepr.add if num.char in Printable: num.char else: '.'
    pos += 1
    if pos == 16:
      pos = 0
      echo strRepr
      strRepr = "   "
  echo "   ".repeat(16-pos) & strRepr
  stream.setPosition(0)

parseProtoFile("example1.prot")
var stream: StringStream

echo "Simple:"
# Create a new string stream, and an instance of our generated type
stream = newStringStream()
var simple = new example_Simple
# Set the number field of our instance
simple.number = 150
# Write our message
stream.write(simple)
# Print out a nice representation of what's written to the stream
echoDataStream(stream)
# Read the message back in to our program
var readSimple = stream.read_example_simple()
# Print out the number field we set earlier
echo readSimple.number

echo "--------------------------------------------------------------------"

echo "Complex:"
# Create a new string stream, and an instance of our generated type
stream = newStringStream()
var complexObj = new example_Complex
# Set the data fields of our instance
complexObj.url = "peterme.net"
complexObj.title = "Welcome to my DevLog"
complexObj.snippets = @["This is a snippet", "So is this", "Even this is a snippet"]
# Write our message
stream.write complexObj
# Print out a nice representation of what's written to the stream
echoDataStream(stream)
# Read the message back in to our program
var readComplex = stream.read_example_complex()
# Print out the fields we set earlier
echo readComplex.url
echo readComplex.title
echo readComplex.snippets

echo "--------------------------------------------------------------------"

echo "Combined:"
# Create a new string stream, and an instance of our generated type
stream = newStringStream()
var combined = new example_Combined
# Set the data fields of our instance
combined.simples = @[]
combined.simples.add(initexample_Simple(number = 100))
combined.simples.add(initexample_Simple(number = 200))
combined.simples.add(initexample_Simple(number = 500))
combined.simples.add(initexample_Simple(number = 9380))
combined.complex = new example_Complex
combined.complex.url = "Hello world"
combined.complex.title = "Another string"
combined.complex.snippets = @["snippet1", "snippet2", "snippet3"]
combined.language = example_Langs.NIM
#combined.choice = example_Combined_choice_OneOf(option: 0, text: "A query")
combined.choice = example_Combined_choice_OneOf(option: 1)
combined.choice.number = 123
# Write our message
stream.write(combined)
# Print out a nice representation of what's written to the stream
echoDataStream(stream)
# Read the message back in to our program
var readCombined = stream.read_example_combined()
# Print out the fields we set earlier
for simple in readCombined.simples:
  echo simple.number
echo readCombined.complex.url
echo readCombined.complex.title
echo readCombined.complex.snippets
echo readCombined.language
if readCombined.has(choice):
  echo readCombined.choice.option
  case readCombined.choice.option:
  of 0:
    echo readCombined.choice.text
  of 1:
    echo readCombined.choice.number
