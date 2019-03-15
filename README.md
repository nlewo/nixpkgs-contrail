Nix expressions to build OpenContrail components, run some basic
tests, build OpenContrail preconfigured VMs and deploy a build CI by
using [Hydra](https://nixos.org/hydra/).


### Install [Nix](https://nixos.org/nix/)

```
$ curl https://nixos.org/nix/install | sh
```


### Subscribe to the OpenContrail Nix channel

This [Hydra CI](http://84.39.63.212/) builds OpenContrail expressions
and creates a channel (a kind of packages repository) that can be used
to get precompiled OpenContrail sotfwares.


```
$ nix-channel --add http://84.39.63.212/jobset/opencontrail/trunk/channel/latest contrail
$ nix-channel --update
```

We can easily install the `contrail-api` for instance:
```
$ nix-env -i contrail-api-server --option extra-binary-caches http://84.39.63.212 --option trusted-public-keys cache.opencontrail.org:u/UFsj0N3c/Ycell/q81MiPRo0Zz6ZlVqu3wB2SY340=
$ contrail-api -h
```
Note options can also be set in your `nix.conf` file.

To list available packages on the channel
```
nix-env -qa '.*contrail.*'
```

Note: for the rest of this README, it is not mandatory to subscribe to
      this channel. It is only used to download prebuilt expressions
      instead of locally build them.


### Build OpenContrail Components

To build all OpenContrail components
```
$ nix-build -A contrail32
```

Since they have been already built by the CI, they are only
downloaded. You can force the rebuild by adding the `--check`
argument.

To build specific ones
```
$ nix-build -A contrail32.apiServer
$ nix-build -A contrail32.control
```

`$ nix-env -f default.nix -qaP -A contrail32` to get the list of all attributes


### Run basic tests

The tests are implemented using the [NixOS testing framework](https://nixos.org/nixos/manual/index.html#sec-nixos-tests). 
Essentially the tests will boot a server inside QEMU, deploy and start OpenContrail and execute a sequence of commands and
assertions to test if the setup is working as expected. The following test cases are available:

- `allInOne`: Starts all OpenContrail services, creates networks and ports through the API and performs a simple traffic test.
- `tcpFlow`: Generates TCP traffic and checks if the traffic is behaving according to the configured security groups.
- `udpFlow`: Generates UDP traffic and checks if the traffic is behaving according to the configured security groups.

All of the tests above can be executed as follows for any of the supported OpenContrail versions:

```
$ nix-build -A contrail32.test.allInOne
$ nix-build -A contrail41.test.udpFlow
$ nix-build -A contrail50.test.tcpFlow
```


Apart from generating a lot of output on the terminal, each test execution will also
ceate a `result` output link containing a `log.html` file which contains a pretty-printed 
overview of the test.

#### Build and run an all-in-one VM

```
$ nix-build -A contrail32.test.allInOne.driver
$ ./result/bin/nixos-run-vms

```
If you need ssh access this is also possible:

```
$ nix-build -A contrail32.test.allInOne.driver
$ QEMU_NET_OPTS="hostfwd=tcp::2222-:22" result/bin/nixos-run-vms

$ ssh -p 2222 root@localhost
Password: root
```

Please refer to the [NixOS manual](https://nixos.org/nixos/manual/index.html#sec-nixos-tests) for more details.

### Using `nix-shell` to locally compile `contrail-control`

```
$ nix-shell -A contrail32.control # Can download lot of things
```

`nix-shell` has download all build requires of `contrail-control` and
prepare a build environment. We can then get the contrail workspace,
and run `scons` to start the `contrail-control` compilation

```
$ unpackPhase && cd $sourceRoot
unpacking source archive /nix/store/9jswqjmq6q4ijrmac5qbw2z5b63cl1x0-contrail-workspace
source root is contrail-workspace
$ scons contrail-control
```				 

### Load a Cassandra database dump and start the contrail api and schema transformer

```
$ nix-build -A contrail32.tools.databaseLoader
```

This builds a script that runs a VM. This VM loads a database dump
from the host directory `/tmp/xchg-shared/cassandra-dump/`. This
directory contents can be created by running the script

```
cqlsh -e "DESC SCHEMA" > /tmp/cassandra-dump/schema.cql
for t in obj_uuid_table obj_fq_name_table; do
  echo "COPY config_db_uuid.$t TO '/tmp/cassandra-dump/config_db_uuid.$t.csv';" | cqlsh
done
```

