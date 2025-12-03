{
  inputs.nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;

  outputs = {
    self,
    nixpkgs,
    systems,
  }: let
    forSystems = nixpkgs.lib.genAttrs (import systems);
  in {
    devShells = forSystems (system:
      with nixpkgs.legacyPackages.${system};
      with self.packages.${system}; let
        custom-sdk =
          (androidenv.composeAndroidPackages {
            systemImageTypes = [];
            abiVersions = [];
            includeNDK = true;
            ndkVersions = ["28.2.13676358"];
            buildToolsVersions = ["36.0.0"];
          }).androidsdk;
        custom-gradle = runCommand "local-aapt2-gradle" {nativeBuildInputs = [makeWrapper];} ''
          makeWrapper ${gradle_9}/bin/gradle $out/bin/gradle \
          --add-flag -Dorg.gradle.project.android.aapt2FromMavenOverride=`ls ${ANDROID_HOME}/build-tools/*/aapt2`
        '';
        ANDROID_HOME = "${custom-sdk}/libexec/android-sdk";
        shell = {
          buildInputs = [go jdk custom-gradle custom-sdk];
          inherit ANDROID_HOME;
          shellHook = ''
            build () {
              export RELEASE_KEYSTORE="''${RELEASE_KEYSTORE-$PWD/appkey.jks}"
              export RELEASE_KEYSTORE_PASSPHRASE="''${RELEASE_KEYSTORE_PASSPHRASE-changeit}"
              export RELEASE_KEY_ALIAS="''${RELEASE_KEY_ALIAS-appkey}"
              export RELEASE_KEY_PASSPHRASE="''${RELEASE_KEY_PASSPHRASE-changeit}"

              [[ -e "$RELEASE_KEYSTORE" ]] ||
              keytool -genkey -v \
              -keystore "$RELEASE_KEYSTORE" \
              -keyalg RSA -keysize 2048 \
              -validity 10000 \
              -alias "$RELEASE_KEY_ALIAS" \
              -dname cn=appkey`date +%Y%m%d_%H%M%S` \
              -storepass "$RELEASE_KEYSTORE_PASSPHRASE"

              gradle assembleRelease
            }
          '';
        };
      in {
        # nix develop --impure
        default = mkShell shell;

        # nix develop --impure #build
        build = mkShell (shell
          // {
            shellHook = ''
              ${shell.shellHook}
              build && exit
            '';
          });
      });

    packages = forSystems (system:
      with nixpkgs.legacyPackages.${system}; rec {
        default = throw ''
          This flake only provides a devShell at the moment.
          Try
          |
          | nix develop --impure #build
          |
        '';
        reformat-nix = writeShellApplication {
          name = "reformat-nix";
          runtimeInputs = [alejandra];
          text = "alejandra ./*.nix";
        };
      });
  };
}
