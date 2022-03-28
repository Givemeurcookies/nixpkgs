{ stdenv, lib, fetchzip, makeWrapper, jre, writeText, nixosTests
, postgresql_jdbc ? null, mysql_jdbc ? null
}:

let
  mkModuleXml = name: jarFile: writeText "module.xml" ''
    <?xml version="1.0" ?>
    <module xmlns="urn:jboss:module:1.3" name="${name}">
        <resources>
            <resource-root path="${jarFile}"/>
        </resources>
        <dependencies>
            <module name="javax.api"/>
            <module name="javax.transaction.api"/>
        </dependencies>
    </module>
  '';
in
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

    wrapProgram $out/bin/kc.sh --set JAVA_HOME ${jre}
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
