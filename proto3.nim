type
  OneOf[T] = ref object
    options: T
    option: range[0..1]
  SearchRequest_Corpus {.pure.} = enum
    UNIVERSAL = 0, WEB = 1, IMAGES = 2, LOCAL = 3,
    NEWS = 4, PRODUCTS = 5, VIDEO = 6
  SearchRequest = ref object
    testOneOf: OneOf[tuple[query: string, page_number: int32]]
    result_per_page: seq[int32]
    corpus: SearchRequest_Corpus
  SearchRequest_SubMessage = ref object
    query: string
    query_count: int32
  SearchRequest_SubMessage_Langs {.pure.} = enum
    UNIVERSAL = 0, NIM = 1, C = 2,
    CPP = 3, PYTHON = 4
  Second = ref object
    test: SearchRequest_SubMessage_Langs
