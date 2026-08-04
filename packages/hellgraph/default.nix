{ lib, stdenvNoCC, nodejs, makeWrapper, hellgraph-src }:

# HellGraph ships a COMMITTED, self-contained `ts/dist` (package.json has ZERO runtime dependencies;
# the dist imports only `node:` builtins + relative paths), so there is no npm build and no
# node_modules — the daemon runs on `node` alone. We install bin/ + ts/ preserving their relative
# layout (bin/*.mjs import ../ts/dist/index.mjs) and wrap the entrypoints that exist on main.
stdenvNoCC.mkDerivation {
  pname = "hellgraph";
  version = "0.1.0";
  src = hellgraph-src;

  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/hellgraph $out/bin
    cp -r bin ts $out/libexec/hellgraph/
    for entry in hellgraph-superpeer hellgraph-agent-ingest; do
      makeWrapper ${nodejs}/bin/node $out/bin/$entry \
        --add-flags $out/libexec/hellgraph/bin/$entry.mjs
    done
    runHook postInstall
  '';

  meta = {
    description = "HellGraph AtomSpace graph engine — always-on local graph service (serves the graph over HTTP; p2p superpeer opt-in via HELLGRAPH_BOOTSTRAP_KEY).";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hellgraph-superpeer";
  };
}
