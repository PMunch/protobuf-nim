protobuf
===========
This is a pure Nim implementation of protobuf, meaning that it doesn't rely
on the ``protoc`` compiler. The entire implementation is based on a macro
that takes in either a string or a file containing the proto3 format as
specified at https://developers.google.com/protocol-buffers/docs/proto3. It
then produces procedures to read, write, and calculate the length of a
message, along with types to hold the data in your Nim program. The data
types are intended to be as close as possible to what you would normally use
in Nim, making it feel very natural to use these types in your program in
contrast to some protobuf implementations. The entire read/write structure is
built on top of the Stream interface from the ``streams`` module, meaning it
can be used directly with anything that uses streams.

Example
-------
To wet your appetite the following example shows how this protobuf macro can
be used to generate the required code and read and write protobuf messages.
This example can also be found in the examples folder. Note that it is also
possible to read in the protobuf specification from a file.

.. code-block:: nim

  import "../src/protobuf", streams

  # Define our protobuf specification and generate Nim code to use it
  const protoSpec = """
  syntax = "proto3";

  message ExampleMessage {
    int32 number = 1;
    string text = 2;
    SubMessage nested = 3;
    message SubMessage {
      int32 a_field = 1;
    }
  }
  """
  parseProto(protoSpec)

  # Create our message
  var msg = new ExampleMessage
  msg.number = 10
  msg.text = "Hello world"
  msg.nested = ExampleMessage_SubMessage(aField: 100)

  # Write it to a stream
  var stream = newStringStream()
  stream.write msg

  # Read the message from the stream and echo out the data
  stream.setPosition(0)
  var readMsg = stream.readExampleMessage()
  echo readMsg.number
  echo readMsg.text
  echo readMsg.nested.aField

Generated code
--------------
Since all the code is generated from the macro on compile-time and not stored
anywhere the generated code is made to be deterministic and easy to
understand. If you would like to see the code however you can pass
``-d:echoProtobuf`` switch on compile-time and the macro will output the
generated code.

Messages
^^^^^^^^
The types generated are named after the path of the message, but with dots
replaced by underscores. So if the protobuf specification contains a package
name it starts with that, then the name of the message. If the message is
nested then the parent message is put between the package and the message.
As an example we can look at a protobuf message defined like this:

.. code-block:: protobuf

  syntax = "proto3"; // The only syntax supported
  package = our.package;
  message ExampleMessage {
      int32 simpleField = 1;
  }

The type generated for this message would be named
``our_package_ExampleMessage``. Since Nim is case and underscore insensitive
you can of course write this with any style you desire be it camel-case,
snake-case, or a mix as seen above. For this specific instance the type
would be:

.. code-block:: nim

  type
    our_package_ExampleMessage = object
      simpleField: int32

Messages also generate a reader, writer, and length procedure to read,
write, and get the length of a message on the wire respectively. All write
procs are simply named ``write`` and are only differentiated by their types.
This write procedure takes three arguments, the ``Stream`` to write to, an
instance of the message type to write, and a boolean telling it to prepend
the message with a varint of it's length or not. This boolean is used for
internal purposes, but might also come in handy if you want to stream
multiple messages as described in
https://developers.google.com/protocol-buffers/docs/techniques#streaming.
The read procedure is named similarily to all the ``streams`` module
readers, simply "read" appended with the name of the type. So for the above
message the reader would be named ``read_our_package_ExampleMessage``.
Notice again how you can write it in different styles in Nim if you'd like.
One could of course also create an alias for this name should it prove too
verbose. Analagously to the ``write`` procedure the reader also takes a
maxSize argument of the maximum size to read for the message before
returning. If the size is set to 0 the stream would be read until ``atEnd``
returns true. The ``len`` procedure is slightly simpler, it only takes an
instance of the message type and returns the size this message would take on
the wire, in bytes. This is used internally, but might have some
other applications elsewhere as well. Notice that this size might vary from
one instance of the type to another as varints can have multiple sizes,
repeated fields different amount of elements, and oneofs having different
choices to name a few.

Enums
^^^^^
Enums are named the same was as messages, and are always declared as pure.
So an enum defined like this:

.. code-block:: protobuf

  syntax = "proto3"; // The only syntax supported
  package = our.package;
  enum Langs {
    UNIVERSAL = 0;
    NIM = 1;
    C = 2;
  }

Would end up with a type like this:

.. code-block:: nim

  type
    our_package_Langs {.pure.} = enum
      UNIVERSAL = 0, NIM = 1, C = 2

For internal use enums also generate a reader and writer procedure. These
are basically a wrapper around the reader and writer for a varint, only that
they convert to and from the enum type. Using these by themselves is seldom
useful.

OneOfs
^^^^^^
In order for oneofs to work with Nims type system they generate their own
type. This might change in the future. Oneofs are named the same way as
their parent message, but with the name of the oneof field, and ``_OneOf``
appended. All oneofs contain a field named ``option`` of a ranged integer
from 0 to the number of options. This type is used to create an object
variant for each of the fields in the oneof. So a oneof defined like this:

.. code-block:: protobuf

  syntax = "proto3"; // The only syntax supported
  package our.package;
  message ExampleMessage {
    oneof choice {
      int32 firstField = 1;
      string secondField = 1;
    }
  }

Will generate the following message and oneof type:

.. code-block:: nim

  type
    our_package_ExampleMessage_choice_OneOf = object
      case option: range[0 .. 1]
      of 0: firstField: int32
      of 1: secondField: string
    our_package_ExampleMessage = object
      choice: our_package_ExampleMessage_choice_OneOf

Limitations
-----------
This library is still in an early phase and has some limitations over the
official version of protobuf. Noticably it only supports the "proto3"
syntax, so no optional or required fields. It also doesn't currently support
maps but you can use the official workaround found here:
https://developers.google.com/protocol-buffers/docs/proto3#maps. This is
planned to be added in the future. It also doesn't support options, meaning
you can't set default values for enums and can't control packing options.
That being said it follows the proto3 specification and will pack all scalar
fields. It also doesn't support services.

These limitations apply to the parser as well, so if you are using an
existing protobuf specification you must remove these fields before being
able to parse them with this library.

Rationale
---------
Some might be wondering why I've decided to create this library. After all
the protobuf compiler is extensible and there are some other attempts at
using protobuf within Nim by using this. The reason is three-fold, first off
no-one likes to add an extra step to their compilation process. Running
``protoc`` before compiling isn't a big issue, but it's an extra
compile-time dependency and it's more work. By using a regular Nim macro
this is moved to a simple step in the compilation process. The only
requirement is Nim and this library meaning tools can be automatically
installed through nimble and still use protobuf. It also means that all of
Nims targets are supported, and sending data between code compiled to C and
Javascript should be a breeze and can share the exact same code for
generating the messages. This is not yet tested, but any issues arising
should be easy enough to fix. Secondly the programatic protobuf interface
created for some languages are not the best. Python for example has some
rather awkward and un-natural patterns for their protobuf library. By using
a Nim macro the code can be customised to Nim much better and has the
potential to create really native-feeling code resulting in a very nice
interface. And finally this has been an interesting project in terms of
pushing the macro system to do something most languages would simply be
incapable of doing. It's not only a showcase of how much work the Nim
compiler is able to do for you through it's meta-programming, but has also
been highly entertaining to work on.

This file is automatically generated from the documentation found in
protobuf.nim. Use ``nim doc2 protobuf.nim`` to get the full documentation.
