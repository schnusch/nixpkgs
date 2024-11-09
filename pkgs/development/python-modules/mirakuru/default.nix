{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonOlder,
  pytestCheckHook,
  setuptools,
  psutil,
  netcat,
  ps,
  python-daemon,
}:

buildPythonPackage rec {
  pname = "mirakuru";
  version = "2.5.3";
  format = "pyproject";

  disabled = pythonOlder "3.9";

  src = fetchFromGitHub {
    owner = "ClearcodeHQ";
    repo = "mirakuru";
    rev = "refs/tags/v${version}";
    hash = "sha256-blk4Oclb3+Cj3RH7BhzacfoPFDBIP/zgv4Ct7fawGnQ=";
  };

  patches = [
    # https://github.com/ClearcodeHQ/mirakuru/pull/810
    ./tmpdir.patch
  ];

  nativeBuildInputs = [ setuptools ];

  propagatedBuildInputs = [ psutil ];

  nativeCheckInputs = [
    netcat.nc
    ps
    python-daemon
    pytestCheckHook
  ];
  pythonImportsCheck = [ "mirakuru" ];

  meta = with lib; {
    homepage = "https://pypi.org/project/mirakuru";
    description = "Process orchestration tool designed for functional and integration tests";
    changelog = "https://github.com/ClearcodeHQ/mirakuru/blob/v${version}/CHANGES.rst";
    license = licenses.lgpl3Plus;
    maintainers = with maintainers; [ bcdarwin ];
  };
}
