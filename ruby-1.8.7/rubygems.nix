{ stdenv, fetchurl, makeWrapper, ruby }:

stdenv.mkDerivation rec {
  name = "rubygems-${version}";
  version = "2.4.1";

  src = fetchurl {
    url = "http://production.cf.rubygems.org/rubygems/${name}.tgz";
    sha256 = "0cpr6cx3h74ykpb0cp4p4xg7a8j0bhz3sk271jq69l4mm4zy4h4f";
  };

  patches = [ ./rubygems-hook.patch ];

  buildInputs = [ ruby makeWrapper ];

  installPhase = ''
    ruby setup.rb --prefix=$out/
    wrapProgram $out/bin/gem --prefix RUBYLIB : $out/lib

    mkdir -pv $out/nix-support
    cat > $out/nix-support/setup-hook <<EOF
    export RUBYOPT=rubygems
    addToSearchPath RUBYLIB $out/lib
    EOF
  '';

  meta = with stdenv.lib; {
    description = "Ruby gems package collection";
    longDescription = ''
      Nix can create nix packages from gems.
      To use it by installing gem-nix package.
    '';
    platforms = platforms.all;
  };
}
