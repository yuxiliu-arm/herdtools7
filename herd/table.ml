module Config = struct
  type fmt = Markdown (* TODO: latex, xlsx, etc. *)

  let fmt_of_string = function
    | "markdown" | "Markdown" | "md" -> Some Markdown
    | _ -> None

  let fmt_to_string = function
    | Markdown -> "markdown"

  let all = [ Markdown ]

  let parse_fmt s =
    match fmt_of_string s with
    | None ->
        let msg =
          let open Format in
          asprintf "Unknown format to -dumptableall, exepcting one of %a, got: %s"
          (pp_print_list pp_print_string) (List.map fmt_to_string all)
          s
        in
        failwith msg
    | Some fmt -> fmt
end

  let dumptable (env : )

