module Stream = {
  type readable
  type writable
}

module Process = {
  @val external exit: int => unit = "process.exit"
  @val external stdin: Stream.readable = "process.stdin"
  @val external stdout: Stream.writable = "process.stdout"
}

module Readline = {
  type readlineInterface

  type createInterfaceOptions = {
    input: Stream.readable,
    output: Stream.writable,
    prompt: string,
  }

  @module("readline")
  external createInterface: createInterfaceOptions => readlineInterface = "createInterface"

  module Interface = {
    @send external prompt: readlineInterface => unit = "prompt"
    
    @send external on: (readlineInterface, [#line | #close], 'a) => unit = "on"
    
    @send external question: (readlineInterface, string, string => unit) => unit = "question"
    
    @send external close: readlineInterface => unit = "close"
  }
}
