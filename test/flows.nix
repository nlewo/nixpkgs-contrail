{ pkgs
, contrailPkgs
, mode
}:

with import (pkgs.path + /nixos/lib/testing.nix) { inherit pkgs; system = builtins.currentSystem; };
with pkgs.lib;
assert (mode == "udp" || mode == "tcp");

let

  udp = mode == "udp";

  machine = { config, ...}: {
    imports = [ ../modules/all-in-one.nix ];

    config = {
      _module.args = { inherit pkgs contrailPkgs; };

      virtualisation = { memorySize = 4096; cores = 2; };

      environment.systemPackages = with pkgs; [
        # Used by the test suite
        jq iperf2
        contrailApiCliWithExtra
        contrailPkgs.configUtils
      ];

      environment.variables = {
        CONTRAIL_API_VERSION = contrailPkgs.contrailVersion;
      };

      contrail.allInOne = {
        enable = true;
        vhostInterface = "eth1";
      };
      contrail.analyticsApi.autoStart = false;
      contrail.collector.autoStart = false;
      contrail.queryEngine.autoStart = false;
      contrail.svcMonitor.autoStart = false;
    };
  };

  testScript = ''
    $machine->waitForUnit("cassandra.service");
    $machine->waitForUnit("rabbitmq.service");
    $machine->waitForUnit("zookeeper.service");

    $machine->waitForUnit("contrail-discovery.service");
    $machine->waitForUnit("contrail-api.service");
    $machine->waitForUnit("contrail-schema-transformer.service");
    $machine->waitForUnit("contrail-control.service");

    # check services state
    my @services = qw(ApiServer IfmapServer xmpp-server);
    foreach my $service (@services)
    {
      $machine->waitUntilSucceeds(sprintf("curl -s http://localhost:5998/services.json | jq -e '.services[] | select(.service_type == \"%s\" and .oper_state == \"up\")'", $service));
    }

    $machine->succeed("lsmod | grep -q vrouter");
    $machine->waitForUnit("contrail-vrouter-agent.service");
    $machine->waitForUnit("provision-vrouter-agent.service");

    $machine->waitUntilSucceeds("curl http://localhost:8083/Snh_ShowBgpNeighborSummaryReq | grep machine | grep -q Established");

    subtest "setup works", sub {
      $machine->succeed("contrail-api-cli --ns contrail_api_cli.provision add-vn --project-fqname default-domain:default-project --subnet 20.1.1.0/24 vn1");
      $machine->succeed("netns-daemon-start -n default-domain:default-project:vn1 vm1");
      $machine->succeed("netns-daemon-start -n default-domain:default-project:vn1 vm2");
      $machine->succeed("contrail-api-cli --ns contrail_api_cli.provision add-sg --project-fqname default-domain:default-project --rule ingress:${mode}:5000:5000: sg1");
      $machine->succeed("contrail-api-cli --ns contrail_api_cli.provision add-sg --project-fqname default-domain:default-project --rule ingress:${mode}:4900:4900: sg2");
      $machine->succeed("ip netns exec ns-vm1 ip a | grep -q 20.1.1.252");
      $machine->succeed("ip netns exec ns-vm2 ip a | grep -q 20.1.1.251");
    };

    subtest "flow setup works without SG", sub {
      # start flow from vm1 to vm2
      $machine->succeed("ip netns exec ns-vm2 iperf -s ${optionalString udp "-u"} -p 5000 &");
      $machine->waitUntilSucceeds("ip netns exec ns-vm2 ss -lnp${if udp then "u" else "t"} | grep -q 0.0.0.0:5000");
      $machine->succeed("ip netns exec ns-vm1 iperf -c 20.1.1.251 ${optionalString udp "-u"} -p 5000 -t 10000 &");
      $machine->succeed("flow -l --match 20.1.1.251:5000 | grep 'Action:F,' | wc -l | grep -q 2");
    };

    subtest "flow dropped by SG", sub {
      # sg2 allow only port 4900
      $machine->succeed("contrail-api-cli apply-sg --project-fqname default-domain:default-project machine-vm2-veth0 sg2");
      $machine->waitUntilSucceeds("flow -l --match 20.1.1.251:5000 | grep 'Action:D(' | wc -l | grep -q 2");
    };

    subtest "flow still dropped after vrouter-agent restart", sub {
      $machine->succeed("systemctl restart contrail-vrouter-agent");
      $machine->sleep(2);
      $machine->waitUntilSucceeds("flow -l --match 20.1.1.251:5000 | grep 'Action:D(' | wc -l | grep -q 2");
    };

    subtest "flow allowed by SG", sub {
      # sg1 allow port 5000
      $machine->succeed("contrail-api-cli apply-sg --project-fqname default-domain:default-project machine-vm2-veth0 sg1");
      $machine->waitUntilSucceeds("flow -l --match 20.1.1.251:5000 | grep 'Action:F,' | wc -l | grep -q 2");
    };

    subtest "flow still allowed after vrouter-agent restart", sub {
      $machine->succeed("systemctl restart contrail-vrouter-agent");
      $machine->sleep(2);
      $machine->waitUntilSucceeds("flow -l --match 20.1.1.251:5000 | grep 'Action:F,' | wc -l | grep -q 2");
    };
  '';

in
  makeTest {
    name = "${mode}-flows";
    nodes = { inherit machine; };
    inherit testScript;
  }
