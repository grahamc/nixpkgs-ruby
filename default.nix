let
  pkgs = import <nixpkgs> {
    overlays = [  (import ./ruby-overlay.nix) ];
  };
in { inherit (pkgs) buildRubyGem_1_8_7 ruby_1_8_7 rubygems; }
