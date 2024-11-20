{
  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        tex = pkgs.texlive.combine
          {

            inherit (pkgs.texlive)
              scheme-medium
              enumitem
              adjustbox
              mathpartir
              comment
              relsize
              currfile
              make4ht

              # pandoc deps
              amsfonts
              amsmath lm
              unicode-math
              iftex
              listings
              fancyvrb
              # longtable
              booktabs
              multirow
              # graphicx
              bookmark
              xcolor
              soul
              geometry
              setspace
              babel
              natbib
              biblatex
              bibtex
              biber
              upquote
              microtype
              parskip
              xurl
              footnotehyper
              # footnote
              ;
          };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs;
            [
              gmp
              pkg-config
              graphviz
              ghostscript
              tex
            ] ++
            pkgs.lib.optionals pkgs.stdenv.isDarwin
              [ pkgs.darwin.apple_sdk.frameworks.CoreServices ];
          shellHook =
            ''
              PKG_CONFIG_PATH="${pkgs.gmp}:$PKG_CONFIG_PATH"
            '';
        };
      }
    );
}
