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
$ nix-env -i contrail-api-server
$ contrail-api -h
```

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
$ nix-build -A contrailMaster
```

Since they have been already built by the CI, they are only
downloaded. You can force the rebuild by adding the `--check`
argument.

To build specific ones
```
$ nix-build -A contrail32.api
$ nix-build -A contrail32.control
```

`$ nix-env -f default.nix -qaP -A contrail32` to get the list of all attributes


### Run basic tests

```
$ nix-build -A contrail32.test.allInOne
```

The `allInOne` test creates a virtual machine and deploys several
OpenContrail components. It then checks services provisioning
(discovery, bgp peering,...), associates ports to `net namespaces` and
validates ping is working.


To run all tests
```
$ nix-build -A contrail32.test
```


#### Build and run an all-in-one VM

```
$ nix-build -A contrail32.test.allInOne.driver
$ QEMU_NET_OPTS="hostfwd=tcp::2222-:22,guestfwd=tcp:10.0.2.201:5998-tcp:127.0.0.1:5998" ./result/bin/nixos-run-vms

```

and reached with

```
$ ssh -p 2222 root@localhost
Password: root
```


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
