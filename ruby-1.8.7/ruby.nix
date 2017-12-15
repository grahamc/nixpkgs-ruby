{ stdenv, fetchurl, fetchpatch, fetchFromGitHub
, zlib, openssl, gdbm, ncurses, readline, groff, libyaml, libffi, autoreconfHook, bison
, autoconf, darwin ? null
, buildEnv
} @ args:

let
  patchSet = fetchFromGitHub {
    owner  = "skaes";
    repo   = "rvm-patchsets";
    rev    = "92ab0e16ddc9fc05760a0171fbd9f240b5318ff8";
    sha256 = "0z8mahahgm9x4gnjyk2q97x2c6j61q7zmxgyq7gr42jn78v1m21b";
  };

  baseruby = self.override { useRailsExpress = false; };

  self = stdenv.lib.makeOverridable (
    { stdenv, fetchurl, fetchpatch, fetchFromGitHub
    , useRailsExpress ? true
    , zlib, zlibSupport ? true
    , openssl, opensslSupport ? true
    , gdbm, gdbmSupport ? true
    , ncurses, readline, cursesSupport ? true
    , groff, docSupport ? false
    , libyaml, yamlSupport ? true
    , libffi, fiddleSupport ? true
    , autoreconfHook, bison, autoconf
    , darwin ? null
    , buildEnv
    }:
    stdenv.mkDerivation rec {
      name = "ruby-${version}";
      version = "1.8.7-p374";
      shortVersion = "1.8";

      src = if useRailsExpress then fetchFromGitHub {
          owner  = "ruby";
          repo   = "ruby";
          rev    = builtins.replaceStrings ["." "-p"] ["_" "_"] "v${version}";
          sha256 = "1xddhxr0j26hpxfixvhqdscwk2ri846w2129fcfwfjzvy19igswx";
      } else fetchurl {
        url = "http://cache.ruby-lang.org/pub/ruby/1.8/ruby-${version}.tar.gz";
        sha256 = "0v17cmm95f3xwa4kvza8xwbnfvfqcrym8cvqfvscn45bxsmfwvl7";
      };

      # Have `configure' avoid `/usr/bin/nroff' in non-chroot builds.
      NROFF = "${groff}/bin/nroff";

      nativeBuildInputs = stdenv.lib.optionals useRailsExpress [ autoreconfHook bison ];
      buildInputs = [ autoconf ]
        ++ stdenv.lib.optional fiddleSupport libffi
        ++ stdenv.lib.optionals cursesSupport [ ncurses readline ]
        ++ stdenv.lib.optional docSupport groff
        ++ stdenv.lib.optional zlibSupport zlib
        ++ stdenv.lib.optional opensslSupport openssl
        ++ stdenv.lib.optional gdbmSupport gdbm
        ++ stdenv.lib.optional yamlSupport libyaml
        # Looks like ruby fails to build on darwin without readline even if curses
        # support is not enabled, so add readline to the build inputs if curses
        # support is disabled (if it's enabled, we already have it) and we're
        # running on darwin
        ++ stdenv.lib.optional (!cursesSupport && stdenv.isDarwin) readline
        ++ stdenv.lib.optionals stdenv.isDarwin (with darwin; [ libiconv libobjc libunwind ]);

      enableParallelBuilding = true;

      patches = [
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/01-ignore-generated-files.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/02-fix-tests-for-osx.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/03-sigvtalrm-fix.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/04-railsbench-gc-patch.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/05-display-full-stack-trace.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/06-better-source-file-tracing.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/07-heap-dump-support.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/08-fork-support-for-gc-logging.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/09-track-malloc-size.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/10-track-object-allocation.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/11-expose-heap-slots.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/12-fix-heap-size-growth-logic.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/13-heap-slot-size.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/14-add-trace-stats-enabled-methods.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/15-track-live-dataset-size.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/16-add-object-size-information-to-heap-dump.patch"
        "${patchSet}/patches/ruby/1.8.7/p374/railsexpress/17-caller-for-all-threads.patch"
      ];

      configureFlags = [ "--enable-shared" "--enable-pthread" ]
        ++ stdenv.lib.optional useRailsExpress "--with-baseruby=${baseruby}/bin/ruby"
        ++ stdenv.lib.optional (!docSupport) "--disable-install-doc"
        ++ stdenv.lib.optionals stdenv.isDarwin [
          "--without-tcl" "--without-tk"
          # on darwin, we have /usr/include/tk.h -- so the configure script detects
          # that tk is installed
          "--with-out-ext=tk"
          # on yosemite, "generating encdb.h" will hang for a very long time without this flag
          "--with-setjmp-type=setjmp"
        ];

      installFlags = stdenv.lib.optionalString docSupport "install-doc";

      postInstall = ''

        # Remove unnecessary groff reference from runtime closure, since it's big
        sed -i '/NROFF/d' $out/lib/ruby/*/*/rbconfig.rb

        # Bundler tries to create this directory
        mkdir -pv $out/${passthru.gemPath}
        mkdir -p $out/nix-support
        cat > $out/nix-support/setup-hook <<EOF
        addGemPath() {
          addToSearchPath GEM_PATH \$1/${passthru.gemPath}
        }

        envHooks+=(addGemPath)
        EOF
      '' + stdenv.lib.optionalString useRailsExpress ''
        rbConfig=$(find $out/lib/ruby -name rbconfig.rb)

        # Prevent the baseruby from being included in the closure.
        sed -i '/^  CONFIG\["BASERUBY"\]/d' $rbConfig
        sed -i "s|'--with-baseruby=${baseruby}/bin/ruby'||" $rbConfig
      '';

      meta = with stdenv.lib; {
        description = "The Ruby language";
        homepage = http://www.ruby-lang.org/en/;
        license = licenses.ruby;
        platforms = platforms.all;
      };

      passthru = rec {
        baseRuby = baseruby;
        libPath = "lib/ruby/1.8";
        gemPath = "lib/ruby/gems/1.8";
      };
    }
  ) args;

in self
