(* This file is about interacting with isla *)

open Logs.Logger (struct
  let str = __MODULE__
end)

(*****************************************************************************)
(*        Aliases                                                            *)
(*****************************************************************************)

(* direct aliases *)

include Isla_lang.AST
module Lexer = Isla_lang.Lexer
module Parser = Isla_lang.Parser

(** {!Bimap.t} test*)
type loc = Lexing.position

type rtrc = lrng trc

type revent = lrng event

type rsmt = lrng smt

type rexp = lrng exp

(*****************************************************************************)
(*        Isla parsing                                                       *)
(*****************************************************************************)

(** Exception that represent an Isla parsing error *)
exception ParseError of loc * string

(* Registering a pretty printer for that exception *)
let _ =
  Printexc.register_printer (function
    | ParseError (l, s) ->
        Some PP.(sprint @@ prefix 2 1 (loc l ^^ !^": ") (!^"ParseError: " ^^ !^s))
    | _ -> None)

(** Exception that represent an Isla lexing error *)
exception LexError of loc * string

(* Registering a pretty printer for that exception *)
let _ =
  Printexc.register_printer (function
    | LexError (l, s) -> Some PP.(sprint @@ prefix 2 1 (loc l ^^ !^": ") (!^"LexError: " ^^ !^s))
    | _ -> None)

type lexer = Lexing.lexbuf -> Parser.token

type 'a parser = lexer -> Lexing.lexbuf -> 'a

(** Parse a single Isla instruction output from a Lexing.lexbuf *)
let parse (parser : 'a parser) ?(filename = "default") (l : Lexing.lexbuf) : 'a =
  l.lex_curr_p <- { pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 };
  try parser Lexer.token @@ l with
  | Parser.Error -> raise (ParseError (l.lex_start_p, "Syntax error"))
  | Lexer.Error _ -> raise (LexError (l.lex_start_p, "Unexpected character"))

(** Parse a single Isla expression from a Lexing.lexbuf *)
let parse_exp : ?filename:string -> Lexing.lexbuf -> rexp = parse Parser.exp_start

(** Parse a single Isla expression from a string *)
let parse_exp_string ?(filename = "default") (s : string) : rexp =
  parse_exp ~filename @@ Lexing.from_string ~with_positions:true s

(** Parse a single Isla expression from a channel *)
let parse_exp_channel ?(filename = "default") (c : in_channel) : rexp =
  parse_exp ~filename @@ Lexing.from_channel ~with_positions:true c

(** Parse an Isla trace from a Lexing.lexbuf *)
let parse_trc : ?filename:string -> Lexing.lexbuf -> rtrc = parse Parser.trc_start

(** Parse an Isla trace from a string *)
let parse_trc_string ?(filename = "default") (s : string) : rtrc =
  let print_around n =
    if has_debug () then
      let lines =
        s |> String.split_on_char '\n'
        |> List.sub ~pos:(max 0 (n - 3)) ~len:5
        |> String.concat "\n  "
      in
      debug "Error at lines:\n  %s" lines
  in

  let lexbuf = Lexing.from_string ~with_positions:true s in
  lexbuf.lex_curr_p <- { pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 };
  try Parser.trc_start Lexer.token lexbuf with
  | Parser.Error ->
      print_around lexbuf.lex_start_p.pos_lnum;
      raise (ParseError (lexbuf.lex_start_p, "Syntax error"))
  | Lexer.Error _ ->
      print_around lexbuf.lex_start_p.pos_lnum;
      raise (LexError (lexbuf.lex_start_p, "Unexpected token"))

(** Parse an Isla trace from a channel *)
let parse_trc_channel ?(filename = "default") (c : in_channel) : rtrc =
  parse_trc ~filename @@ Lexing.from_channel ~with_positions:true c

(*$R
    try
      let exp = parse_exp_string ~filename:"test" "v42" in
      match exp with Var (42, _) -> () | _ -> assert_failure "Wrong expression parsed"
    with
    | exn -> assert_failure (Printf.sprintf "Thrown: %s" (Printexc.to_string exn))
*)

(*$R
    try
      let exp = parse_exp_string ~filename:"test" "(and v1 v2)" in
      match exp with
        | Manyop (And, [Var (1, _); Var (2, _)], _)  -> ()
        | _ -> assert_failure "Wrong expression parsed"
    with
    | exn -> assert_failure (Printf.sprintf "Thrown: %s" (Printexc.to_string exn))
*)

include Isla_lang.PP
