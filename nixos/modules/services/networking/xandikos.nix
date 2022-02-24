{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xandikos;

  enabledInstances = filterAttrs (instance: instanceCfg: instanceCfg.enable) cfg.instances;
in
{
  imports = [
    (mkRemovedOptionModule ["services" "xandikos" "address"] ''
      Use services.xandikos.instances.<instance>.address instead.
    '')
    (mkRemovedOptionModule ["services" "xandikos" "port"] ''
      Use services.xandikos.instances.<instance>.port instead.
    '')
  ];

  options = {
    services.xandikos = {
      enable = mkEnableOption "Xandikos CalDAV and CardDAV server";

      package = mkOption {
        type = types.package;
        default = pkgs.xandikos;
        defaultText = literalExpression "pkgs.xandikos";
        description = "The Xandikos package to use.";
      };

      instances = mkOption {
        description = "Configure an instance.";
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            enable = (mkEnableOption "this Xandikos instance") // {
              default = true;
              example = false;
            };

            address = mkOption {
              type = types.nullOr types.str;
              default = null;
              defaultText = "/run/xandikos/\${instance}/socket";
              description = ''
                The IP address or socket path on which Xandikos will listen.
                By default listens on localhost.
              '';
              example = "localhost";
            };

            port = mkOption {
              type = types.port;
              default = 8080;
              description = "The port of the Xandikos web application";
            };

            routePrefix = mkOption {
              type = types.str;
              default = "/";
              description = ''
                Path to Xandikos.
                Useful when Xandikos is behind a reverse proxy.
              '';
            };

            extraOptions = mkOption {
              default = [];
              type = types.listOf types.str;
              example = literalExpression ''
                [ "--autocreate"
                  "--defaults"
                  "--current-user-principal user"
                  "--dump-dav-xml"
                ]
              '';
              description = ''
                Extra command line arguments to pass to xandikos.
              '';
            };

            nginx = mkOption {
              default = {};
              description = ''
                Configuration for nginx reverse proxy.
              '';

              type = types.submodule {
                options = {
                  enable = mkOption {
                    type = types.bool;
                    default = false;
                    description = ''
                      Configure the nginx reverse proxy settings.
                    '';
                  };

                  hostName = mkOption {
                    type = types.str;
                    description = ''
                      The hostname use to setup the virtualhost configuration
                    '';
                  };
                };
              };
            };
          };
        });
      };

    };

  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.instances != {};
        message = ''
          You need to configure at least one Xandikos instance. E.g. services.xandikos.instances.default.address = "localhost";
        '';
      }
    ];

    meta.maintainers = with lib.maintainers; [ _0x4A6F ];

    systemd.targets.xandikos = {
      description = "A Simple Calendar and Contact Server";
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services = mapAttrs'
      (instance: instanceCfg: nameValuePair
        "xandikos@${instance}"
        {
          description = "A Simple Calendar and Contact Server for ${instance}";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          requiredBy = [ "xandikos.target" ];
          partOf = [ "xandikos.target" ];

          serviceConfig = {
            User = "xandikos";
            Group = "xandikos";
            DynamicUser = "yes";
            StateDirectory = "xandikos";
            StateDirectoryMode = "0700";
            PrivateDevices = true;
            # Sandboxing
            CapabilityBoundingSet = "CAP_NET_RAW CAP_NET_ADMIN";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX AF_PACKET AF_NETLINK";
            RestrictNamespaces = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            ExecStart = ''
              ${cfg.package}/bin/xandikos \
                --directory /var/lib/xandikos \
                --listen-address ${escapeShellArg (
                  if instanceCfg.address == null then
                    "/run/xandikos/${instance}/socket"
                  else
                   instanceCfg.address
                )} \
                --port ${toString instanceCfg.port} \
                --route-prefix ${instanceCfg.routePrefix} \
                ${lib.concatStringsSep " " instanceCfg.extraOptions}
            '';
          } // (optionalAttrs (instanceCfg.address == null) {
            RuntimeDirectory = "xandikos/${instance}";
          });
        })
      enabledInstances;

    services.nginx =
      let
        virtualHosts =
          mapAttrs'
            (_: instanceCfg: nameValuePair
              instanceCfg.nginx.hostName
              {
                locations."/".proxyPass = "http://${
                  if hasInfix "/" cfg.address then
                    "unix:${instanceCfg.address}"
                  else
                    "${instanceCfg.address}:${toString instanceCfg.port}"
                }";
              })
            (filterAttrs (_: { nginx, ... }: nginx.enable) enabledInstances);
      in
        optionalAttrs (virtualHosts != {}) {
          enable = true;
          inherit virtualHosts;
        };
  };
}
