import "../src/protobuf"

# Check to see that everything parses. Should add some more testing to verify
# that it actually creates the correct result
# Note that when running `nimble test` the starting directory is the root
# directory of the repository for file reads (but not for imports)
parseProtoFile("tests/parse.prot")
echo "All good!"
