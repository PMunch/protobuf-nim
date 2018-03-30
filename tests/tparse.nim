import "../src/protobuf"

# Check to see that everything parses. Should add some more testing to verify
# that it actually creates the correct result
parseProtoFile("parse.prot")
echo "All good!"
