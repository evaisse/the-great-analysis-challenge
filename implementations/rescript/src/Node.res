module Process = {
  @val external exit: int => unit = "process.exit"
  @val external stdin: Node.Stream.readable = "process.stdin"
  @val external stdout: Node.Stream.writable = "process.stdout"
}

module Readline = {
  type readlineInterface

  type createInterfaceOptions = {
    input: Node.Stream.readable,
    output: Node.Stream.writable,
    prompt: string,
  }

  @module("readline")
  external createInterface: createInterfaceOptions => readlineInterface = "createInterface"

  module Interface = {
    @send external prompt: readlineInterface => unit = "prompt"
    
    @send external on: (readlineInterface, @string [#line | #close], 'a) => unit = "on"
    
    @send external question: (readlineInterface, string, string => unit) => unit = "question"
    
    @send external close: readlineInterface => unit = "close"
  }
}