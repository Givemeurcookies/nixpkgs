{ config, options, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.neo4j;
  opt = options.services.neo4j;
  isDefaultPathOption = opt: isOption opt && opt.type == types.path && opt.highestPrio >= 1500;

  serverConfig = pkgs.writeText "neo4j.conf" ''
  
    # General
    dbms.allow_upgrade=${boolToString cfg.allowUpgrade}
    dbms.default_listen_address=${cfg.defaultListenAddress}
    dbms.read_only=${boolToString cfg.readOnly}
    ${optionalString (cfg.workerCount > 0) ''
      dbms.threads.worker_count=${toString cfg.workerCount}
    ''}

    # Directories
    dbms.directories.data=${cfg.directories.data}
    dbms.directories.logs=${cfg.directories.home}/logs
    dbms.directories.run=${cfg.directories.home}/run
    dbms.directories.plugins=${cfg.directories.plugins}
    ${optionalString (cfg.constrainLoadCsv) ''
      dbms.directories.import=${cfg.directories.imports}
    ''}

    # HTTP Connector
    ${optionalString (cfg.http.enable) ''
      dbms.connector.http.enabled=${boolToString cfg.http.enable}
      dbms.connector.http.listen_address=${cfg.http.listenAddress}
    ''}
    
    ${optionalString (!cfg.http.enable) ''
      # It is not possible to disable the HTTP connector. To fully prevent
      # clients from connecting to HTTP, block the HTTP port (7474 by default)
      # via firewall. listen_address is set to the loopback interface to
      # prevent remote clients from connecting.
      dbms.connector.http.listen_address=127.0.0.1
    ''}

    # HTTPS Connector
    dbms.connector.https.enabled=${boolToString cfg.https.enable}
    dbms.connector.https.listen_address=${cfg.https.listenAddress}
    
    # BOLT Connector
    dbms.connector.bolt.enabled=${boolToString cfg.bolt.enable}
    dbms.connector.bolt.listen_address=${cfg.bolt.listenAddress}

    # Default retention policy from neo4j.conf
    dbms.tx_log.rotation.retention_policy=1 days

    # Default JVM parameters from neo4j.conf
    dbms.jvm.additional=-XX:+UseG1GC
    dbms.jvm.additional=-XX:-OmitStackTraceInFastThrow
    dbms.jvm.additional=-XX:+AlwaysPreTouch
    dbms.jvm.additional=-XX:+UnlockExperimentalVMOptions
    dbms.jvm.additional=-XX:+TrustFinalNonStaticFields
    dbms.jvm.additional=-XX:+DisableExplicitGC
    #Increase maximum number of nested calls that can be inlined from 9 (default) to 15
    dbms.jvm.additional=-XX:MaxInlineLevel=15
    # Disable biased locking
    dbms.jvm.additional=-XX:-UseBiasedLocking
    # Restrict size of cached JDK buffers to 256 KB
    dbms.jvm.additional=-Djdk.nio.maxCachedBufferSize=262144
    # More efficient buffer allocation in Netty by allowing direct no cleaner buffers.
    dbms.jvm.additional=-Dio.netty.tryReflectionSetAccessible=true
    # Expand Diffie Hellman (DH) key size from default 1024 to 2048 for DH-RSA cipher suites used in server TLS handshakes.
    # This is to protect the server from any potential passive eavesdropping.
    dbms.jvm.additional=-Djdk.tls.ephemeralDHKeySize=2048
    # This mitigates a DDoS vector.
    dbms.jvm.additional=-Djdk.tls.rejectClientInitiatedRenegotiation=true 
    # Increase the default flight recorder stack sampling depth from 64 to 256, to avoid truncating frames when profiling.
    dbms.jvm.additional=-XX:FlightRecorderOptions=stackdepth=256
    
    # Allow profilers to sample between safepoints. Without this, sampling profilers may produce less accurate results.
    dbms.jvm.additional=-XX:+UnlockDiagnosticVMOptions
    dbms.jvm.additional=-XX:+DebugNonSafepoints
    # Is this required?
    # dbms.jvm.additional=-Dunsupported.dbms.udc.source=tarball
    # Disable logging JMX endpoint.
    dbms.jvm.additional=-Dlog4j2.disable.jmx=true
    
    # Name of the service
    dbms.windows_service_name=neo4j
    # Extra Configuration
    ${cfg.extraServerConfig}
  '';

in {

  imports = [
    (mkRenamedOptionModule [ "services" "neo4j" "host" ] [ "services" "neo4j" "defaultListenAddress" ])
    (mkRenamedOptionModule [ "services" "neo4j" "listenAddress" ] [ "services" "neo4j" "defaultListenAddress" ])
    (mkRenamedOptionModule [ "services" "neo4j" "enableBolt" ] [ "services" "neo4j" "bolt" "enable" ])
    (mkRenamedOptionModule [ "services" "neo4j" "enableHttps" ] [ "services" "neo4j" "https" "enable" ])
    (mkRenamedOptionModule [ "services" "neo4j" "dataDir" ] [ "services" "neo4j" "directories" "home" ])
    (mkRemovedOptionModule [ "services" "neo4j" "port" ] "Use services.neo4j.http.listenAddress instead.")
    (mkRemovedOptionModule [ "services" "neo4j" "boltPort" ] "Use services.neo4j.bolt.listenAddress instead.")
    (mkRemovedOptionModule [ "services" "neo4j" "httpsPort" ] "Use services.neo4j.https.listenAddress instead.")
  ];

  ###### interface

  options.services.neo4j = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable Neo4j Community Edition.
      '';
    };

    allowUpgrade = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Allow upgrade of Neo4j database files from an older version.
      '';
    };

    constrainLoadCsv = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Sets the root directory for file URLs used with the Cypher
        <literal>LOAD CSV</literal> clause to be that defined by
        <option>directories.imports</option>. It restricts
        access to only those files within that directory and its
        subdirectories.
        </para>
        <para>
        Setting this option to <literal>false</literal> introduces
        possible security problems.
      '';
    };

    defaultListenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Default network interface to listen for incoming connections. To
        listen for connections on all interfaces, use "0.0.0.0".
        </para>
        <para>
        Specifies the default IP address and address part of connector
        specific <option>listenAddress</option> options. To bind specific
        connectors to a specific network interfaces, specify the entire
        <option>listenAddress</option> option for that connector.
      '';
    };

    extraServerConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra configuration for Neo4j Community server. Refer to the
        <link xlink:href="https://neo4j.com/docs/operations-manual/current/reference/configuration-settings/">complete reference</link>
        of Neo4j configuration settings.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.neo4j;
      defaultText = literalExpression "pkgs.neo4j";
      description = ''
        Neo4j package to use.
      '';
    };

    readOnly = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Only allow read operations from this Neo4j instance.
      '';
    };

    workerCount = mkOption {
      type = types.ints.between 0 44738;
      default = 0;
      description = ''
        Number of Neo4j worker threads, where the default of
        <literal>0</literal> indicates a worker count equal to the number of
        available processors.
      '';
    };

    bolt = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable the BOLT connector for Neo4j. Setting this option to
          <literal>false</literal> will stop Neo4j from listening for incoming
          connections on the BOLT port (7687 by default).
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = ":7687";
        description = ''
          Neo4j listen address for BOLT traffic. The listen address is
          expressed in the format <literal>&lt;ip-address&gt;:&lt;port-number&gt;</literal>.
        '';
      };

    };

    directories = {

      data = mkOption {
        type = types.path;
        default = "${cfg.directories.home}/data";
        defaultText = literalExpression ''"''${config.${opt.directories.home}}/data"'';
        description = ''
          Path of the data directory. You must not configure more than one
          Neo4j installation to use the same data directory.
          </para>
          <para>
          When setting this directory to something other than its default,
          ensure the directory's existence, and that read/write permissions are
          given to the Neo4j daemon user <literal>neo4j</literal>.
        '';
      };

      home = mkOption {
        type = types.path;
        default = "/var/lib/neo4j";
        description = ''
          Path of the Neo4j home directory. Other default directories are
          subdirectories of this path. This directory will be created if
          non-existent, and its ownership will be <command>chown</command> to
          the Neo4j daemon user <literal>neo4j</literal>.
        '';
      };

      imports = mkOption {
        type = types.path;
        default = "${cfg.directories.home}/import";
        defaultText = literalExpression ''"''${config.${opt.directories.home}}/import"'';
        description = ''
          The root directory for file URLs used with the Cypher
          <literal>LOAD CSV</literal> clause. Only meaningful when
          <option>constrainLoadCvs</option> is set to
          <literal>true</literal>.
          </para>
          <para>
          When setting this directory to something other than its default,
          ensure the directory's existence, and that read permission is
          given to the Neo4j daemon user <literal>neo4j</literal>.
        '';
      };

      plugins = mkOption {
        type = types.path;
        default = "${cfg.directories.home}/plugins";
        defaultText = literalExpression ''"''${config.${opt.directories.home}}/plugins"'';
        description = ''
          Path of the database plugin directory. Compiled Java JAR files that
          contain database procedures will be loaded if they are placed in
          this directory.
          </para>
          <para>
          When setting this directory to something other than its default,
          ensure the directory's existence, and that read permission is
          given to the Neo4j daemon user <literal>neo4j</literal>.
        '';
      };
    };

    http = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          The HTTP connector is required for Neo4j, and cannot be disabled.
          Setting this option to <literal>false</literal> will force the HTTP
          connector's <option>listenAddress</option> to the loopback
          interface to prevent connection of remote clients. To prevent all
          clients from connecting, block the HTTP port (7474 by default) by
          firewall.
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = ":7474";
        description = ''
          Neo4j listen address for HTTP traffic. The listen address is
          expressed in the format <literal>&lt;ip-address&gt;:&lt;port-number&gt;</literal>.
        '';
      };
    };

    https = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the HTTPS connector for Neo4j. Setting this option to
          <literal>false</literal> will stop Neo4j from listening for incoming
          connections on the HTTPS port (7473 by default).
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = ":7473";
        description = ''
          Neo4j listen address for HTTPS traffic. The listen address is
          expressed in the format <literal>&lt;ip-address&gt;:&lt;port-number&gt;</literal>.
        '';
      };
    };
  };

  ###### implementation

  config =
    let

      # Capture various directories left at their default so they can be created.
      defaultDirectoriesToCreate = map (opt: opt.value) (filter isDefaultPathOption (attrValues options.services.neo4j.directories));
    in

    mkIf cfg.enable {
      systemd.services.neo4j = {
        description = "Neo4j Daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          NEO4J_HOME = "${cfg.package}/share/neo4j";
          NEO4J_CONF = "${cfg.directories.home}/conf";
        };
        serviceConfig = {
          ExecStart = "${cfg.package}/bin/neo4j console";
          User = "neo4j";
          PermissionsStartOnly = true;
          LimitNOFILE = 40000;
        };

        preStart = ''
          # Directories Setup
          #   Always ensure home exists with nested conf, logs directories.
          mkdir -m 0700 -p ${cfg.directories.home}/{conf,logs}

          #   Create other sub-directories and policy directories that have been left at their default.
          ${concatMapStringsSep "\n" (
            dir: ''
              mkdir -m 0700 -p ${dir}
          '') (defaultDirectoriesToCreate)}

          # Place the configuration where Neo4j can find it.
          ln -fs ${serverConfig} ${cfg.directories.home}/conf/neo4j.conf

          # Ensure neo4j user ownership
          chown -R neo4j ${cfg.directories.home}
        '';
      };

      environment.systemPackages = [ cfg.package ];

      users.users.neo4j = {
        isSystemUser = true;
        group = "neo4j";
        description = "Neo4j daemon user";
        home = cfg.directories.home;
      };
      users.groups.neo4j = {};
    };

  meta = {
    maintainers = with lib.maintainers; [ patternspandemic ];
  };
}
