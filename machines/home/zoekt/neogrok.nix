{ lib, stdenv, fetchFromGitHub, nodejs, yarn-berry_4, makeWrapper }:

let
  yarn-berry = yarn-berry_4;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "neogrok";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "isker";
    repo = "neogrok";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4/HLTyYTsrboEjqmmgFnY9OWCrOJtgfCH5hhMnc3UPI=";
  };

  # the name of the site instead of neogrok, and a search form in the middle of
  # the window before the first search
  patches = [ ./neogrok.patch ];

  # the site has a text title and no icon
  postPatch = ''
    rm static/*.png static/favicon.ico static/site.webmanifest
  '';

  # yarn.lock carries no hash for a package of one platform only
  # (`yarn-berry-fetcher missing-hashes yarn.lock`)
  missingHashes = ./neogrok-missing-hashes.json;
  offlineCache = yarn-berry.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-7P5bAigQIj1RVwcNWc/bjLfyO85nLPi60d/PCEVAvpI=";
  };

  nativeBuildInputs = [
    nodejs
    yarn-berry
    yarn-berry.yarnBerryConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    yarn run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # the server needs the runtime dependencies only. The yarn of the source
    # tree resolves again and goes to the network, the yarn of nixpkgs uses the
    # cache that the hook laid out
    YARN_IGNORE_PATH=1 YARN_ENABLE_NETWORK=0 yarn workspaces focus --production

    mkdir -p $out/lib/neogrok
    cp -r package.json main.js build node_modules $out/lib/neogrok
    makeWrapper ${lib.getExe nodejs} $out/bin/neogrok \
      --add-flags $out/lib/neogrok/main.js

    runHook postInstall
  '';

  meta = {
    description = "Frontend for the zoekt code search engine";
    homepage = "https://github.com/isker/neogrok";
    license = lib.licenses.mit;
    mainProgram = "neogrok";
  };
})
