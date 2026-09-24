(****************************************************************************)
(*                           the diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2026-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)

open Herd_core
module TR = Top_herd.TestResult

let iter_count (i : ('a -> unit) -> 'b) : ('a -> unit) -> int * 'b =
  fun f ->
    let c = ref 0 in
    let b = i (fun x -> f x; c := !c + 1) in
    !c, b

module Make (O : sig
  include RunTest.Config
  include Top_herd.PrinterConfig
  val timeout : float option
  val outputdir : PrettyConf.outputdir_mode
  val output_format : PrettyConf.output_format
  val suffix : string
  val dumpes : bool
end) = struct
  module PC = O.PC

  module JsonChan : sig
    type t
    val make : out_channel -> t
    val write : Json.t -> t -> unit
    val flush : t -> unit
    val close : t -> unit
  end = struct
    type t = out_channel * Json.t list ref

    let make chan = chan, ref []
    let write json (_, items) = items := json :: !items
    let flush (chan, items) =
      Json.pretty_to_channel chan (`List !items);
      output_char chan '\n';
      Stdlib.flush chan;
      items := []
    let close (chan, _) = close_out chan
  end

  type ochan = DotChan of out_channel | JsonChan of JsonChan.t

(* Open an output file channel, or not *)
  let open_ochan test =
    match O.outputdir with
    | PrettyConf.NoOutputdir ->
       begin
         match O.output_format, O.PC.view with
         | PrettyConf.Dot, Some _ ->
          begin try
            let f,chan = Filename.open_temp_file "herd" ".dot" in
            Some (DotChan chan,f)
          with  Sys_error msg ->
            Warn.warn_always "Cannot create temporary file: %s" msg ;
            None
          end
         | _ -> None
       end
    | PrettyConf.StdoutOutput ->
       let fname = Test_herd.basename test in
       begin match O.output_format with
       | PrettyConf.Dot ->
           Printf.fprintf stdout "\nDOTBEGIN %s\n" fname;
           Printf.fprintf stdout "DOTCOM %s\n"
             (let module G = Show.Generator(PC) in G.generator);
           Some (DotChan stdout, fname)
       | PrettyConf.Json ->
           Printf.fprintf stdout "\nJSONBEGIN %s\n" fname;
           Some (JsonChan (JsonChan.make stdout), fname)
       end
    | PrettyConf.Outputdir d ->
        let base = Test_herd.basename test in
        let base = base ^ O.suffix in
        let f, wrap = match O.output_format with
          | PrettyConf.Dot ->
              let f = Filename.concat d base ^ ".dot" in
              f, (fun chan -> DotChan chan)
          | PrettyConf.Json ->
              let f = Filename.concat d base ^ ".json" in
              f, (fun chan -> JsonChan (JsonChan.make chan)) in
        try Some (wrap (open_out f),f) with
        | Sys_error msg ->
            Warn.warn_always "Cannot create %s: %s" f msg ;
            None

  let close_ochan = function
    | None -> ()
    | Some (DotChan chan,fname) ->
       begin match O.outputdir with
       | PrettyConf.NoOutputdir | PrettyConf.Outputdir _ ->
          if O.PC.debug then Printf.eprintf "close %s\n%!" fname ;
          close_out chan
       | PrettyConf.StdoutOutput ->
          Printf.fprintf stdout "\nDOTEND %s\n" fname
       end
    | Some (JsonChan chan,fname) ->
        JsonChan.flush chan;
        begin match O.outputdir with
        | PrettyConf.Outputdir _ ->
            if O.PC.debug then Printf.eprintf "close %s\n%!" fname;
            JsonChan.close chan
        | PrettyConf.StdoutOutput -> Printf.fprintf stdout "\nJSONEND %s\n" fname
        | PrettyConf.NoOutputdir -> ()
        end

  let my_remove name =
    try Sys.remove name
    with e ->
      Warn.warn_always "remove failed: %s" (Printexc.to_string e)

  let erase_ochan ochan =
    match O.PC.debug, O.outputdir, ochan with
    | false, PrettyConf.NoOutputdir, Some (DotChan _,f) -> my_remove f
    | _ -> ()

  let dump_results ~start_time (module R : RunTest.Outcome) =
    let open R in
    let module S = M.S in
    let module A = S.A in
    let module T = Test_herd.Make (S.A) in
    let module PP = Top_herd.Printer (O) (S) in
    let open ConstrGen in
    let event_structures = result.TR.event_structures in

(* Open *)
    let ochan = open_ochan test in
(* So small a race condition... *)
    Handler.push (fun () -> erase_ochan ochan) ;
(* Dump event structures ... *)
    if O.dumpes then begin
      match ochan with
      | None -> ()
      | Some (ochan, fname) ->
          let module PP = Pretty.Make(S) in
          List.iter
            (fun es -> match ochan with
              | DotChan chan -> PP.dump_es chan test es
              | JsonChan chan ->
                  JsonChan.write (PP.Json.es_to_json_view es) chan)
            event_structures ;
          close_ochan (Some (ochan,fname)) ;
          if Misc.is_some S.O.PC.view && O.output_format = PrettyConf.Dot then begin
            let module SH = Show.Make(S.O.PC) in
            SH.show_file fname
          end ;
          erase_ochan (Some (ochan,fname)) ;
          Handler.pop ()
    end else
    let dump_graph =
      match ochan with
        | Some (DotChan chan, _) -> fun exec -> PP.dump_exec_graph M.model test exec chan
        | Some (JsonChan chan, _) -> fun exec ->
            let module Pretty = Pretty.Make(S) in
            let json = Pretty.Json.to_json_view
              (TR.concrete exec) (TR.relations exec) in
            JsonChan.write json chan
        | None -> fun _ -> ()
    in
    let shown, c =
      try iter_count result.TR.exec_iter dump_graph
      with e -> close_ochan ochan; raise e
    in
(* Close *)
    close_ochan ochan ;
    let do_show () =
(* Show if something to show *)
      begin match ochan with
      | Some (DotChan _,fname) when shown > 0 ->
          let module SH = Show.Make(S.O.PC) in
          if O.PC.debug then Printf.eprintf "show %s file\n%!" fname ;
          SH.show_file fname
      | Some _|None -> ()
      end ;
(* Erase *)
      erase_ochan ochan ;
      Handler.pop ()
    in
    let finals = TR.states c in
    let nfinals = A.StateSet.cardinal finals in
    let module TRS = TR.Make (S) in
    match O.restrict with
    | Restrict.Observed when TR.candidates c = 0 -> do_show ()
    | Restrict.NonAmbiguous when TR.candidates c <> nfinals -> do_show ()
    | Restrict.CondOne when TR.positive c <> TRS.count_prop ~byte:O.byte test c ->
        do_show ()
    | _ ->
(* Header *)
      if not O.badexecs && TR.has_bad_execs ~badflag:O.badflag c then ()
      else
(* Stop interval timer *)
        Itimer.stop O.timeout ;
(* Now output *)
        let time = Sys.time () -. start_time in
        Format.printf "%a@." (fun fmt () -> PP.pp_stats ~time test c fmt) ();
        if O.debug.Debug_herd.timers then
          Format.printf "Timers: %a, %a, %a@."
            O.Timer.pp O.Timer.run
            O.Timer.pp O.Timer.semantics
            O.Timer.pp O.Timer.model;
        do_show ();
        begin
          match TR.cutoff c with
          | Some msg ->
              Warn.warn_always
                "%a: unrolling limit exceeded at %s, legal outcomes may be missing."
                Pos.pp_pos0   test.Test_herd.name.Name.file
                msg
          | None -> ()
        end

  let collect_graph_data = match O.outputdir with
    | PrettyConf.StdoutOutput | PrettyConf.Outputdir _ -> true
    | _ -> false

  let from_file f env =
    let module T = ParseTest.Top (struct
      include O
      let collect_graph_data = collect_graph_data
    end) in
(* Interval timer will be stopped just before output, see dump_results *)
    Itimer.start f O.timeout ;
    let start_time = Sys.time () in
    let env, result = T.from_file f env in
    begin match result with
      | Some result -> dump_results ~start_time result
      | None -> ()
    end;
    env
end
