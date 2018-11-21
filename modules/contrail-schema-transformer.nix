{ config, lib, pkgs, contrailPkgs, ... }:

with lib;

let
  cfg = config.contrail.schemaTransformer;
in {
  options = {
    contrail.schemaTransformer = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      configFile = mkOption {
        type = types.path;
        description = "schema transformer configuration file";
      };
      autoStart = mkOption {
        type = types.bool;
        default = true;
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.contrail-schema-transformer = mkMerge [
      {
        after = [ "network.target" "cassandra.service" "rabbitmq.service"
                  "zookeeper.service" "contrail-api.service" ];
        requires = [ "contrail-api.service" ];
        preStart = "mkdir -p /var/log/contrail/";
        script = "${contrailPkgs.schemaTransformer}/bin/contrail-schema --conf_file ${cfg.configFile}";
      }
      (mkIf cfg.autoStart { wantedBy = [ "multi-user.target" ]; })
    ];
  };
}

