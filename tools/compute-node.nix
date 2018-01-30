{ contrailPkgs, pkgs_path, isContrailMaster, isContrail32 }:

with import (pkgs_path + "/nixos/lib/testing.nix") { system = builtins.currentSystem; };

let
  contrailVrouterAgentFilepath = "/run/contrail-vrouter.conf";
  agent = pkgs.writeTextFile {
    name = "contrail-agent.conf";
    text = ''
      [DEFAULT]
      ble_flow_collection = 1
      log_file = /var/log/contrail/vrouter.log
      log_level = SYS_DEBUG
      log_local = 1
      collectors= collector:8086
      [CONTROL-NODE]
      server = control
      [DISCOVERY]
      port = 5998
      server = discovery
      [FLOWS]
      max_vm_flows = 20
      [METADATA]
      metadata_proxy_secret = t96a4skwwl63ddk6
      [TASK]
      tbb_keepawake_timeout = 25
    '';
  };

  config = { pkgs, lib, config, ... }: {
    imports = [ ../modules/compute-node.nix ];
    config = {
      _module.args = { inherit contrailPkgs isContrailMaster isContrail32; };

      networking.firewall.enable = false;
      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      users.extraUsers.root.password = "root";
      virtualisation.graphics = false;
      virtualisation.memorySize = 1024;

      contrail.vrouterAgent = {
        enable = true;
        configurationFilepath = contrailVrouterAgentFilepath;
        provisionning = false;
        contrailInterface = "eth2";
      };

      # We use the MAC address to set the hostname and the IP address
      # on the contrail inteface. We use this hack since it hard to
      # pass values through QEMU.  The compute node uses its hostname
      # to subscribe to the controller IFMAP and its IP to set the
      # nexthop.
      systemd.services.configureContrailInterface = {
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        before = [ "configureVhostInterface.service" "contrailVrouterAgent.service"];
        path = [ pkgs.iproute pkgs.nettools ];
        script = ''
          set -x
          # The last part of the MAC address is used to define the IP
          # address and the hostname
          CONTRAIL_INTERFACE=eth2
          NUMBER=$(ip l show $CONTRAIL_INTERFACE | grep 52:54:00:12:02 | sed 's/.*52:54:00:12:02:\(..\).*/\1/')
          hostname compute-$NUMBER
          ip a add 192.168.2.$NUMBER dev $CONTRAIL_INTERFACE
          ip l set $CONTRAIL_INTERFACE up
          ip r add 192.168.2.0/24 dev $CONTRAIL_INTERFACE

          IP=$(ip a show $CONTRAIL_INTERFACE | grep "inet "| sed 's|.*inet \(.*\)/.* scope.*|\1|')
          cp ${agent} ${contrailVrouterAgentFilepath}
          cat >>${contrailVrouterAgentFilepath} <<EOF
          [VIRTUAL-HOST-INTERFACE]
          name = vhost0
          ip = $IP/24
          gateway = 192.168.2.255
          physical_interface = $CONTRAIL_INTERFACE
          EOF
        '';
      };
    };
  };

  startVm = pkgs.writeShellScriptBin "startVm" ''
    if [ "$COMPUTE_NUMBER" == "" ]; then
      echo "Environment varible COMPUTE_NUMBER must be set! Exiting."
      exit 1
    fi

    export QEMU_NET_OPTS=hostfwd=udp::51234-:51234,hostfwd=tcp::22-:22,hostfwd=tcp::8085-:8085,guestfwd=tcp:10.0.2.200:5998-tcp:discovery:5998,guestfwd=tcp:10.0.2.200:8082-tcp:api:8082,guestfwd=tcp:10.0.2.200:5269-tcp:control:5269
    export QEMU_OPTS="-net nic,vlan=2,macaddr=52:54:00:12:2:$COMPUTE_NUMBER,model=virtio -net vde,vlan=2,sock=/tmp/vde/switch"
    ${computeNode}/bin/nixos-run-vms
  '';

  computeNode = (makeTest { name = "compute-node"; machine = config; testScript = ""; }).driver;

in rec {
  # TODO: This image is quiet big. There are some dependencies that should
  # be removed.
  # docker run --device /dev/kvm -d --network dockercompose_cloudwatt -p 2122:22 --name compute1 --volume /tmp/vde/:/tmp/vde vrouter:latest
  computeNodeDockerImage = pkgs.dockerTools.buildImage {
    name = "vrouter";
    config = { Cmd = [ "${startVm}/bin/startVm" ]; };
  };
}
