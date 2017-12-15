self: super:

let
  inherit (super) callPackage;
in

{
  ruby-overlay = rec {
    interpreters.ruby_1_8_7 = rec {
      ruby = callPackage ./ruby-1.8.7/ruby.nix {};
      rubygems = callPackage ./ruby-1.8.7/rubygems.nix { inherit ruby; };
      buildRubyGem = callPackage ./ruby-1.8.7/build-gem.nix { inherit ruby rubygems; };
    };

    packages.ruby_1_8_7 = rec {
      bundler = super.bundler.override {
        inherit (interpreters.ruby_1_8_7) ruby buildRubyGem;
      };
    };
  };

  buildRubyGem_1_8_7 = self.ruby-overlay.interpreters.ruby_1_8_7.buildRubyGem;
  ruby_1_8_7 = self.ruby-overlay.interpreters.ruby_1_8_7.ruby;
  rubygems = self.ruby-overlay.interpreters.ruby_1_8_7.rubygems;
}
