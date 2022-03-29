{ lib, stdenv, fetchurl, makeWrapper, jre, which, gawk }:

with lib;

stdenv.mkDerivation rec {
  pname   = "keycloak";
  version = "17.0.1";

  src = fetchzip {
    url    = "https://github.com/keycloak/keycloak/releases/download/${version}/keycloak-${version}.zip";
    sha256 = "sha256:0qky2mc4rs23mv92mkppglxpj68nxq522whp8clgxyha996xylng";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir $out
    cp -r * $out

    rm -rf $out/bin/*.{ps1,bat}

    wrapProgram $out/bin/kc.sh \
            --prefix PATH : "${lib.makeBinPath [ jre which gawk ]}" \
            --set JAVA_HOME "${jre}"
  '';

  #passthru.tests = nixosTests.keycloak;

  meta = with lib; {
    homepage    = "https://www.keycloak.org/";
    description = "Identity and access management for modern applications and services";
    license     = licenses.asl20;
    platforms   = jre.meta.platforms;
    maintainers = with maintainers; [ ngerstle talyz ];
  };
}

