(******************************************************************************)
(*                                ASLRef                                      *)
(******************************************************************************)
(*
 * SPDX-FileCopyrightText: Copyright 2022-2023 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: BSD-3-Clause
 *)
(******************************************************************************)
(* Disclaimer:                                                                *)
(* This material covers both ASLv0 (viz, the existing ASL pseudocode language *)
(* which appears in the Arm Architecture Reference Manual) and ASLv1, a new,  *)
(* experimental, and as yet unreleased version of ASL.                        *)
(* This material is work in progress, more precisely at pre-Alpha quality as  *)
(* per Arm’s quality standards.                                               *)
(* In particular, this means that it would be premature to base any           *)
(* production tool development on this material.                              *)
(* However, any feedback, question, query and feature request would be most   *)
(* welcome; those can be sent to Arm’s Architecture Formal Team Lead          *)
(* Jade Alglave <jade.alglave@arm.com>, or by raising issues or PRs to the    *)
(* herdtools7 github repository.                                              *)
(******************************************************************************)

(*
  Menhir to BNFC Grammar converter
*)

type args = {
  cmly_file : string;
  cf_file : string;
  order_file : string option;
  no_ast : bool;
}
(** Command line arguments structure *)

let parse_args () =
  let files = ref [] in
  let no_ast = ref false in
  let order_file = ref "" in
  let speclist =
    [
      ( "--no-ast",
        Arg.Set no_ast,
        " Output in a simplified A := B | C format excluding AST information."
      );
      ( "--order",
        Arg.Set_string order_file,
        " A file describing the desired order of bnfc names. Represented as a \
         newline separated list of bnfc names." );
    ]
  in
  let prog =
    if Array.length Sys.argv > 0 then Filename.basename Sys.argv.(0)
    else "menhir2bnfc"
  in
  let anon_fun f = files := f :: !files in
  let usage_msg =
    Printf.sprintf
      "Menhir parser (.cmly) and ocamllex (.ml) to bnfc (.cf) grammar \
       converter.\n\n\
       USAGE:\n\
       \t%s [OPTIONS] [CMLY_FILE] [OUTPUT_FILE]\n"
      prog
  in
  let () = Arg.parse speclist anon_fun usage_msg in
  let args =
    let order_file = match !order_file with "" -> None | f -> Some f in
    match List.rev !files with
    | [ cmly; cf ] ->
        { cmly_file = cmly; cf_file = cf; no_ast = !no_ast; order_file }
    | _ ->
        let () = Printf.eprintf "%s invalid arguments!\n%s" prog usage_msg in
        exit 1
  in
  let () =
    let ensure_exists s =
      if Sys.file_exists s then ()
      else
        let () = Printf.eprintf "%s cannot find file %S\n%!" prog s in
        exit 1
    in
    ensure_exists args.cmly_file;
    if Option.is_some args.order_file then
      ensure_exists (Option.get args.order_file)
  in
  args

(* I/O utility functions *)
let with_open_in_bin file fn =
  let chan = open_in_bin file in
  let res = fn chan in
  close_in chan;
  res

let with_open_out_bin file fn =
  let chan = open_out_bin file in
  fn chan;
  close_out chan

let translate_to_str args =
  let open BNFC in
  let bnfc =
    let module BnfcData = CvtGrammar.Convert (MenhirSdk.Cmly_read.Read (struct
      let filename = args.cmly_file
    end)) in
    let initial : BNFC.t =
      { entrypoints = BnfcData.entrypoints; decls = BnfcData.decls }
    in
    match args.order_file with
    | None -> initial
    | Some ord_file ->
        let parse_order chan =
          let data = really_input_string chan (in_channel_length chan) in
          String.trim data |> String.split_on_char '\n' |> List.map String.trim
        in
        let order = with_open_in_bin ord_file parse_order in
        sort_bnfc initial order
  in
  if args.no_ast then simplified_bnfc bnfc else string_of_bnfc bnfc

let () =
  let args = parse_args () in
  let cf_content = translate_to_str args in
  with_open_out_bin args.cf_file (fun oc -> Printf.fprintf oc "%s\n" cf_content)
