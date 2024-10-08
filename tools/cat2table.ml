(****************************************************************************)
(*                           The Diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2024-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)

(** Adapted from miaou *)

let prog =
  if Array.length Sys.argv > 0 then
    Filename.basename Sys.argv.(0)
  else "cat2table7"
  (* TODO: combine with miaou? *)

module Make
    (O:sig
(* Configuration *)
         val verbose : int
         val includes : string list
         val libdir : string
         val expand : bool
         val flatten : bool
(* Definitons *)
         val names : StringSet.t
         val testmode : bool
    end) =
  struct

    (***********)
    (* Parsing *)
    (***********)

    let libfind =
      let module ML =
        MyLib.Make
          (struct
            let includes = O.includes
            let env = Some "HERDLIB"
            let libdir = O.libdir
            let debug = O.verbose > 0
          end) in
      ML.find

    module ParserConfig =
      struct
        let debug = false
        let libfind = libfind
      end

    module P = ParseModel.Make(ParserConfig)

    (*******************)
    (* Normalize names *)
    (*******************)

    open AST

    let tr_id s = s

    (* try to descend and evaluate until reaches [FunApp] or a primitive which
       we don't have information *)
    type extremity =
      | Set of string
      | Domain of string (* of a relation *)
      | Range of string  (* of a relation *)
      | Opaque of string (* primative, function application *)

    type ty =
      | Set of exp
      | Rln of exp
      | KnownRln of exp * exp (* if extremities are explicitly named *)
      | Opaque of exp

    type id_map = ty StringMap.t

    let empty : id_map = StringMap.empty

    let pp_exp fmt (exp : exp) =
      let open Format in
      (* let bracket fmt pp v = Format.fprintf fmt "(%a)" pp v in *)
      match exp with
      | Konst (_, Empty _) -> pp_print_string fmt "{}"
      | Konst (_, Universe _) -> pp_print_string fmt "Universe"
      | _ -> pp_print_string fmt "TODO"
      (* | Tag (_, tag) -> "Tag " ^ tag *)
      (* | Var (_, var) -> "Var " ^ var *)
      (* | Op1 (_, op1, exp) -> "(" ^ pp_exp out_channel exp ^ ")" ^ pp_op1 op1 *)
      (* | Op (_, op2, exps) -> "" *)
      (* | App of  TxtLoc.t * exp * exp *)
      (* | Bind  of  TxtLoc.t * binding list * exp *)
      (* | BindRec  of  TxtLoc.t * binding list * exp *)
      (* | Fun of  TxtLoc.t * pat * exp * *)
      (*       var (* name *) * varset (* free vars *) *)
      (* | ExplicitSet of TxtLoc.t * exp list *)
      (* | Match of TxtLoc.t * exp * clause list * exp option *)
      (* | MatchSet of TxtLoc.t * exp * exp * set_clause *)
      (* | Try of TxtLoc.t * exp * exp *)
      (* | If of TxtLoc.t * cond * exp * exp *)

    let pp_ty fmt =
      let open Format in
      function
      | Set exp -> fprintf fmt "Set(%a)" pp_exp exp
      | Rln exp -> fprintf fmt "Rln(%a)" pp_exp exp
      | KnownRln (e1, e2) -> fprintf fmt "KnownRln(%a, %a)" pp_exp e1 pp_exp e2
      | Opaque exp -> fprintf fmt "Opaque(%a)" pp_exp exp

    let pp_id_map out_channel = StringMap.pp out_channel (fun out_channel id exp ->
      let pp_ty out_channel =
        let fmt = Format.formatter_of_out_channel out_channel in
        pp_ty fmt
      in
      Printf.fprintf out_channel "%s -> %a" id pp_ty exp)

    let rec populate_id_map_ins (id_map : id_map) (ins : ins) : id_map =
      match ins with
      | Let (_, bds)
      | Rec (_, bds, _ (* ignoring app_test, not sure what it does *) ) ->
          List.fold_left populate_id_map_binding id_map bds
      | InsMatch (_, _, _, Some inss) ->
          List.fold_left populate_id_map_ins id_map inss
      | InsMatch (_, _, _, None)
      | Test _ | UnShow _ | Show _ | ShowAs _
      | Include _  (* should already be resolved *)
      | Procedure _ | Call _ | Enum _ | Forall _ | Debug _ | Events _ ->
          id_map
      | WithFrom (_, v, e) ->
          (* assumes [e] must be a set of relation, [v] must be a relation *)
          StringMap.add v (Rln e) id_map
      | IfVariant (_, _, inss1, inss2) ->
          populate_id_map (populate_id_map id_map inss1) inss2
    and populate_id_map id_map inss = List.fold_left populate_id_map_ins id_map inss
    and populate_id_map_binding (id_map : id_map) (_, pat, exp) =
      match pat with
      | Ptuple _ (* only used for formals, shouldn't be visited *)
      | Pvar None -> id_map
      | Pvar (Some v) ->
          match ty_of_exp id_map exp with
          | Some ty -> StringMap.add v ty id_map
          | None -> id_map
    and ty_of_exp id_map exp =
      let ( <|> ) e1 e2 =
        match (e1, e2) with
        | Some e1, _ -> Some e1
        | None, e2 -> e2
      in
      match exp with
      | Tag _ -> None
      | Var (_, v) -> StringMap.find_opt v id_map (* TODO: order *)
      | Op1 (_, _, _) -> Some (Opaque exp)
      | Op (_, _, _) -> Some (Opaque exp)
      | App (_, _, _) -> Some (Opaque exp)
      | Bind (_, _, _) -> failwith "TODO"
      | BindRec (_, _, _) -> failwith "TODO"
      | Fun (_, _, _, _, _) -> failwith "TODO"
      | ExplicitSet (_, _) -> Some (Set exp)
      | Match (_, _, _, _) -> failwith "TODO"
      | MatchSet (_, _, _, _) -> failwith "TODO"
      | Try (_, e1, e2)
      | If (_, _, e1, e2) -> ty_of_exp id_map e1 <|> ty_of_exp id_map e2
      | Konst (_, (Empty SET | Universe SET)) -> Some (Set exp)
      | Konst (_, (Empty RLN | Universe RLN)) -> Some (Rln exp)

    let run fname =
      let (_, _, inss) = P.parse fname in
      let id_map = populate_id_map empty inss in
      pp_id_map stdout id_map
  end

(****************************************)
(* Parse command line arguments proceed *)
(****************************************)

let verbose = ref 0
let libdir = ref (Filename.concat Version.libdir "herd")
let includes = ref []
let names = ref StringSet.empty
let testmode = ref false
let expand = ref true
let flatten = ref true

open Printf

let options =
  [
(* Basic *)
    ("-version", Arg.Unit
     (fun () -> printf "%s, Rev: %s\n" Version.version Version.rev ; exit 0),
   " show version number and exit") ;
    ("-libdir", Arg.Unit (fun () -> print_endline !libdir; exit 0),
    " show installation directory and exit");
    ("-set-libdir", Arg.String (fun s -> libdir := s),
    "<path> set installation directory to <path>");
    ("-v", Arg.Unit (fun _ -> incr verbose),
   "<non-default> show various diagnostics, repeat to increase verbosity");
    ("-q", Arg.Unit (fun _ -> verbose := -1 ),
   "<default> do not show diagnostics");
    ("-I", Arg.String (fun s -> includes := !includes @ [s]),
   "<dir> add <dir> to search path");
    ArgUtils.parse_stringset "-show" names "show those names definitions";
    ArgUtils.parse_bool "-test" testmode "translate as many names as possible";
    ArgUtils.parse_bool "-expand" expand "expand include statements";
    ArgUtils.parse_bool "-flatten" flatten "flatten associative operators";
  ]

(* Parse command line *)
let args = ref []
let get_cmd_arg s = args := s :: !args

let () =
  try
    Arg.parse options
      get_cmd_arg
      (sprintf "Usage %s [options] [files]+, translate cat definition into English." prog)
  with
  | Misc.Fatal msg -> eprintf "%s: %s\n" prog msg ; exit 2

let cats = List.rev !args

let () =
  let module Zyva =
    Make
      (struct
        let verbose = !verbose
        let includes = !includes
        let libdir = !libdir
        let names = !names
        let expand = !expand
        let flatten = !flatten
        let testmode = !testmode
      end) in
  let zyva name =
    try Zyva.run name
    with
    | Misc.Fatal msg ->
       Warn.warn_always "%a: %s" Pos.pp_pos0 name msg ;
       exit 2
    | Misc.UserError msg ->
       Warn.warn_always "%s (User error)" msg ;
       exit 2
    | Misc.Exit -> ()
    | e ->
       Printf.eprintf "\nFatal: %a Adios\n" Pos.pp_pos0 name ;
       raise e in
    List.iter zyva cats
