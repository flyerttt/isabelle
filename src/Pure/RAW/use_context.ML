(*  Title:      Pure/RAW/use_context.ML
    Author:     Makarius

Common context for "use" operations (compiler invocation).
*)

type use_context =
 {name_space: ML_Name_Space.T,
  str_of_pos: int -> string -> string,
  print: string -> unit,
  error: string -> unit};

