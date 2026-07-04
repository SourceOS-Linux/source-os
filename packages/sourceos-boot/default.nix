{ lib, python3Packages, sourceos-boot-src }:

python3Packages.buildPythonApplication {
  pname = "sourceos-boot";
  version = "0.1.0";
  src = sourceos-boot-src;

  pyproject = true;
  build-system = with python3Packages; [
    setuptools
  ];

  # No third-party runtime dependencies — stdlib only.
  propagatedBuildInputs = [];

  # Tests require a writable home directory and running system paths absent in
  # the Nix sandbox. They run in sourceos-boot's own repo CI.
  doCheck = false;

  pythonImportsCheck = [
    "sourceos_boot.cli"
    "sourceos_boot.asahi_boot_chain"
    "sourceos_boot.rollback_executor"
  ];

  meta = {
    description = "SourceOS boot chain model: Asahi rollback planning and execution for Apple Silicon.";
    license = lib.licenses.mit;
    mainProgram = "sourceos-boot";
    platforms = lib.platforms.linux;
  };
}
