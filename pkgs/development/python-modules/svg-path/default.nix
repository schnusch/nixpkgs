{ lib
, buildPythonPackage
, fetchPypi
, pillow
, pytestCheckHook
}:

buildPythonPackage rec {
  pname = "svg.path";
  version = "6.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-X78HaJFzywl3aA4Sl58wHQu2r1NVyjlsww0+ESx5TdU=";
  };

  checkInputs = [
    pillow
    pytestCheckHook
  ];

  disabledTests = [
    # generated image differs from example
    "test_image"
  ];

  pythonImportsCheck = [ "svg.path" ];

  meta = with lib; {
    description = "SVG path objects and parser";
    homepage = "https://github.com/regebro/svg.path";
    license = licenses.mit;
    maintainers = with maintainers; [ goibhniu ];
  };
}
