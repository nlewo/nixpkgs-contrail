{ pkgs
, python
, pythonPackages
, contrailVersion
, contrailWorkspace
, contrailPythonBuild
, isContrail32
, isContrail41
}:

with pkgs.lib;

let
  contrailPythonPackages = self: super:
    let
      callPackage = pkgs.lib.callPackageWith
        (self // { inherit pkgs contrailVersion contrailWorkspace
                           contrailPythonBuild pythonPackages isContrail41; });
    in {
      gevent = super.gevent.overridePythonAttrs(old: rec {
        version = "1.2.2";
        src = self.fetchPypi {
          inherit version;
          pname = old.pname;
          sha256 = "0bbbjvi423y9k9xagrcsimnayaqymg6f2dj76m9z3mjpkjpci4a7";
        };
      });
      thrift = super.thrift.overridePythonAttrs(old: rec {
        name = "thrift-${version}";
        version = "0.9.3";
        src = pkgs.fetchurl {
          url = "mirror://pypi/t/thrift/${name}.tar.gz";
          sha256 = "dfbc3d3bd19d396718dab05abaf46d93ae8005e2df798ef02e32793cd963877e";
        };
      });
      # for cassandra-driver
      cython = super.cython.overridePythonAttrs(old: rec {
        pname = "Cython";
        version = "0.28.3";
        src = self.fetchPypi {
          inherit pname version;
          sha256 = "1aae6d6e9858888144cea147eb5e677830f45faaff3d305d77378c3cba55f526";
        };
        checkPhase = "";
      });
      bottle = callPackage ./bottle.nix { };
      pycassa = callPackage ./pycassa.nix { };
      kafka = callPackage ./kafka.nix { };
      # Theses weren't used before
      # sseclient = callPackage ./sseclient.nix { };
      # jsonpickle = callPackage ./jsonpickle.nix { };
      bitarray = callPackage ./bitarray.nix { };
      flexmock = callPackage ./flexmock.nix { };
      junitxml = callPackage ./junitxml.nix { };
      keystonemiddleware = callPackage ./keystonemiddleware { };
      neutron_constants = callPackage ./neutron_constants { };
      python-neutronclient = callPackage ./python-neutronclient { };
      python-novaclient = callPackage ./python-novaclient { };
      contrail_neutron_plugin = callPackage ./contrail-neutron-plugin.nix { };
      contrail_vrouter_api = callPackage ./vrouter-api.nix { };
      vnc_api = callPackage ./vnc-api.nix { };
      cfgm_common = callPackage ./cfgm-common.nix { };
      vnc_openstack = callPackage ./vnc-openstack.nix { };
      sandesh_common = callPackage ./sandesh-common.nix { };
      pysandesh = callPackage ./pysandesh.nix { };
    } // optionalAttrs isContrail32 {
      discovery_client = callPackage ./discovery-client.nix { };
    };
in
# We don't use an override on the python package set because overrides
# are not composable yet: an override can not be overriden.
pkgs.lib.fix' (pkgs.lib.extends contrailPythonPackages pkgs.python27.pkgs.__unfix__)
