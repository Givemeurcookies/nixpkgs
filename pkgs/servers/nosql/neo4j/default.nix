{ lib, stdenv, fetchurl, makeWrapper, jre, which, gawk }:

with lib;

stdenv.mkDerivation rec {
  pname = "neo4j";
  version = "4.4.4";

  src = fetchurl {
    url = "https://neo4j.com/artifact.php?name=neo4j-community-${version}-unix.tar.gz";
    sha256 = "46ea100f162c86284c352fa56606565d6d87ffe5fc9369945914d08728eff2be";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p "$out/share/neo4j"
    cp -R * "$out/share/neo4j"

    mkdir -p "$out/bin"
    for NEO4J_SCRIPT in neo4j neo4j-admin neo4j-import cypher-shell
    do
        makeWrapper "$out/share/neo4j/bin/$NEO4J_SCRIPT" \
            "$out/bin/$NEO4J_SCRIPT" \
            --prefix PATH : "${lib.makeBinPath [ jre which gawk ]}" \
            --set JAVA_HOME "${jre}"
    done
  '';

  meta = with lib; {
    description = "A highly scalable, robust (fully ACID) native graph database";
    homepage = "http://www.neo4j.org/";
    license = licenses.gpl3;

    maintainers = [ maintainers.offline ];
    platforms = lib.platforms.unix;
  };
}
