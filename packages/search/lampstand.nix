{ lib, python3Packages, lampstand-src }:

python3Packages.buildPythonApplication {
  pname = "lampstand";
  version = "0.0.0";
  src = lampstand-src;

  pyproject = true;
  build-system = with python3Packages; [
    setuptools
    wheel
  ];

  pythonImportsCheck = [
    "lampstand.cli"
    "lampstand.lampstandd"
  ];

  doCheck = false;

  meta = {
    description = "SourceOS desktop file indexing and search service";
    license = lib.licenses.mit;
    mainProgram = "lampstand";
  };
}
