{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    certs = {
      url = "github:Fluepke/emudrahahahahaha";
      flake = false;
    };
  };
  outputs = { certs, ... }: {
    nixosModules.default = ({ config, lib, pkgs, ... }: let
      domains = [
        "quasar.yandex.net"
        "quasar.yandex.ru"
        "scbh.yandex.net"
        "quasar.yasmina.yango.com"
        "scbh.yasmina.yango.com"
        "quasar.yasmina.funtechservices.com"
        "scbh.yasmina.funtechservices.com"
      ];
      cfg = config.services.quasar-unlock;
      package = pkgs.stdenv.mkDerivation (finalAttrs: let
        pnpm = pkgs.pnpm_12;
        node = pkgs.nodejs-slim_26;
      in {
        pname = "quasar-unlock";
        version = "0";
        src = ./.;
        nativeBuildInputs = [
          pnpm
          node
          pkgs.pnpmConfigHook
          pkgs.makeBinaryWrapper
        ];
        pnpmDeps = pkgs.fetchPnpmDeps {
          inherit pnpm;
          inherit (finalAttrs) pname version src;
          hash = "sha256-vVrIwZiCBnA5sOn2KF14IpPmAqh2XYx5HtfwoTArk3w=";
          fetcherVersion = 4;
        };
        installPhase = ''
          runHook preInstall

          mkdir -p $out/lib/${finalAttrs.pname}
          mkdir $out/bin
          cp -r package.json src node_modules $out/lib/${finalAttrs.pname}/
          makeWrapper ${lib.getExe node} $out/bin/${finalAttrs.pname} \
            --add-flags "$out/lib/${finalAttrs.pname}" \
            --set "NODE_PATH" "$out/lib/${finalAttrs.pname}/node_modules"

          runHook postInstall
        '';

        meta = {
          mainProgram = finalAttrs.pname;
        };
      });
    in {
      options.services.quasar-unlock = {
        enable = lib.mkEnableOption "quasar-unlock web server";
        publicIp = lib.mkOption {
          description = "Public IP address";
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        enableDns = lib.mkOption {
          description = "Enable DNS hijaker via dnsmasq";
          type = lib.types.bool;
          default = true;
        };
        enableCaddy = lib.mkOption {
          description = "Enable Caddy reverse proxy with TLS handling";
          type = lib.types.bool;
          default = true;
        };
        openFirewall = lib.mkOption {
          description = "Open ports in the firewall for enabled services.";
          type = lib.types.bool;
          default = true;
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 9238;
          description = "Port to bind the web service instance to.";
        };
        rateLimit = {
          limit = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Maximum number of requests from an IP allowed within a window.";
          };
          windowMs = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "The amount of milliseconds that it takes for limit to reset.";
          };
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.enableDns -> cfg.publicIp != null;
            message = "When `services.quasar-unlock.enableDns` is enabled `services.quasar-unlock.publicIp` must be configured.";
          }
        ];

        systemd.services.quasar-unlock = {
          description = "quasar-unlock web service";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          environment = {
            PORT = toString cfg.port;
            RATE_LIMIT = toString cfg.rateLimit.limit;
            RATE_LIMIT_WINDOW_MS = toString cfg.rateLimit.windowMs;
          };
          serviceConfig = {
            DynamicUser = true;
            ExecStart = lib.getExe package;
            Restart = "on-failure";
          };
        };

        services.dnsmasq = lib.mkIf cfg.enableDns {
          enable = true;
          resolveLocalQueries = false;
          settings = {
            address = map (domain: "/${domain}/${cfg.publicIp}") domains;
            local = map (domain: "/${domain}/") domains;
            listen-address = [ "${cfg.publicIp}" ];
            bind-dynamic = true;
            server = [ "1.1.1.1" "9.9.9.9" ];
            no-resolv = true;
            log-queries = true;
          };
        };
        services.caddy = lib.mkIf cfg.enableCaddy {
          enable = true;
          globalConfig = ''
            pki {
              ca emudhra {
                name "Best certificate authority ever"
                intermediate {
                  cert "${certs}/CN=EM OV TLS CA - G3B,O=eMudhra BV,C=NL.pem"
                  key  "${certs}/CN=EM OV TLS CA - G3B,O=eMudhra BV,C=NL.key"
                }
              }
            }
          '';
          virtualHosts."${lib.concatStringsSep ", " (map (domain: "${domain}, *.${domain}") domains)}" = {
            extraConfig = ''
              tls {
                issuer internal {
                  ca emudhra
                }
              }
              reverse_proxy http://127.0.0.1:${toString cfg.port} {
                header_up Host {host}
              }
            '';
          };
        };

        networking.firewall = lib.mkIf cfg.openFirewall {
          allowedTCPPorts =
            lib.optionals cfg.enableDns [ 53 ]
            ++ lib.optionals cfg.enableCaddy [ 80 443 ];

          allowedUDPPorts =
            lib.optionals cfg.enableDns [ 53 ]
            ++ lib.optionals cfg.enableCaddy [ 443 ];
        };
      };
    });
  };
}
