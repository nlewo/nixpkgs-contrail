{ config, lib, pkgs, ... }:

with lib;

{

  config = {

    services.cassandra = {
      enable = true;
      rpcAddress = "0.0.0.0";
      extraConfig = {
        broadcast_rpc_address = "127.0.0.1";
        start_native_transport = true;
        batch_size_warn_threshold_in_kb = 1000;
        batch_size_fail_threshold_in_kb = 2000;
      };
      jvmOpts = [
        "-Djava.net.preferIPv4Stack=true"
      ];
    };

    # Adjust limits for cassandra service
    # https://docs.datastax.com/en/dse-trblshoot/doc/troubleshooting/insufficientResources.html
    # Fix upstream ?
    systemd.services.cassandra = {
      serviceConfig = {
        TimeoutSec = "infinity";
        LimitNOFILE = 100000;
        LimitNPROC = 32768;
        LimitMEMLOCK = "infinity";
      };
      postStart = ''
        sleep 2
        while ! ${config.services.cassandra.package}/bin/nodetool status >/dev/null 2>&1; do
          sleep 2
        done
      '';
    };

    boot.kernel.sysctl = {
      "vm.max_map_count" = "1048575";
      "fs.file-max" = "100000";
    };

  };

}
