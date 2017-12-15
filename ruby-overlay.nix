self: super:

let
  inherit (super) callPackage;
in

{
  ruby-overlay = {
    interpreters.ruby_1_8_7 = rec {
      ruby = callPackage ./ruby-1.8.7/ruby.nix {};
      rubygems = callPackage ./ruby-1.8.7/rubygems.nix { inherit ruby; };
      buildRubyGem = callPackage ./ruby-1.8.7/build-gem.nix { inherit ruby rubygems; };
    };
  };

  buildRubyGem_1_8_7 = self.ruby-overlay.interpreters.ruby_1_8_7.buildRubyGem;
  ruby_1_8_7 = self.ruby-overlay.interpreters.ruby_1_8_7.ruby;
  rubygems = self.ruby-overlay.interpreters.ruby_1_8_7.rubygems;
}
