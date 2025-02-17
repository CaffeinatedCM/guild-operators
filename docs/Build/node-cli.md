!!! info "Reminder !!"
    Ensure the [Pre-Requisites](../basics.md#pre-requisites) are in place before you proceed.

### Build Instructions

#### Clone the repository

Execute the below to clone the cardano-node repository to `$HOME/git` folder on your system:

``` bash
cd ~/git
git clone https://github.com/input-output-hk/cardano-node
cd cardano-node
```

#### Build Cardano Node

You can use the instructions below to build the latest release of [cardano-node](https://github.com/input-output-hk/cardano-node). 

``` bash
git fetch --tags --all
git pull
# Replace tag against checkout if you do not want to build the latest released version
git checkout $(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r .tag_name)

# Use `-l` argument if you'd like to use system libsodium instead of IOG fork of libsodium while compiling
$CNODE_HOME/scripts/cabal-build-all.sh
```

The above would copy the binaries built into `~/.cabal/bin` folder.

### Verify

Execute `cardano-cli` and `cardano-node` to verify output as below:

```bash
cardano-cli version
# cardano-cli 1.29.0 - linux-x86_64 - ghc-8.10
# git rev 4c59442958072657812c6c0bb8e0b4ab85ce1ba2
cardano-node version
# cardano-node 1.29.0 - linux-x86_64 - ghc-8.10
# git rev 4c59442958072657812c6c0bb8e0b4ab85ce1ba2
```

#### Update port number or pool name for relative paths

Before you go ahead with starting your node, you may want to update values for `CNODE_PORT` in `$CNODE_HOME/scripts/env`. Note that it is imperative for operational relays and pools to ensure that the port mentioned is opened via firewall to the destination your node is supposed to connect from. Update your network/firewall configuration accordingly. Future executions of `prereqs.sh` will preserve and not overwrite these values.

```bash
CNODE_PORT=6000
POOL_NAME="GUILD"
```

!!! important
    POOL_NAME is the name of folder that you will use when registering pools and starting node in core mode. This folder would typically contain your `hot.skey`,`vrf.skey` and `op.cert` files required. If the mentioned files are absent, the node will automatically start in a passive mode.

#### Start the node

To test starting the node in interactive mode, you can use the pre-built script below (`cnode.sh`) (note that your node logs are being written to `$CNODE_HOME/logs` folder, you may not see much output beyond `Listening on http://127.0.0.1:12798`). This script automatically determines whether to start the node as a relay or block producer (if the required pool keys are present in the `$CNODE_HOME/priv/pool/<POOL_NAME>` as mentioned above). The script contains a user-defined variable `CPU_CORES` which determines the number of CPU cores the node will use upon start-up:

```bash
######################################
# User Variables - Change as desired #
# Common variables set in env file   #
######################################

#CPU_CORES=2            # Number of CPU cores cardano-node process has access to (please don't set higher than physical core count, 2-4 recommended)
```
You can uncomment this and set to the desired number, but be wary not to go above your physical core count.
```bash
cd $CNODE_HOME/scripts
./cnode.sh
```

Stop the node by hitting Ctrl-C.

#### Run as systemd service {: id="systemd"}

The preferred way to run the node is through a service manager like systemd. This section explains how to setup a systemd service file.

**1. Deploy as a systemd service**  
Execute the below command to deploy your node as a systemd service (from the respective scripts folder):
```bash
cd $CNODE_HOME/scripts
./deploy-as-systemd.sh
```

**2. Start the node**  
Run below commands to enable automatic start of service on startup and start it.
``` bash
sudo systemctl start cnode.service
```

**3. Check status and stop/start commands** 
Replace `status` with `stop`/`start`/`restart` depending on what action to take.
``` bash
sudo systemctl status cnode.service
```

!!! important
    In case you see the node exit unsuccessfully upon checking status, please verify you've followed the transition process correctly as documented below, and that you do not have another instance of node already running. It would help to check your system logs (`/var/log/syslog` for debian-based and `/var/log/messages` for Red Hat/CentOS/Fedora systems, you can also check `journalctl -f -u <service>` to examine startup attempt for services) for any errors while starting node.

You can use [gLiveView](../Scripts/gliveview.md) to monitor your node that was started as a systemd service.

```bash
cd $CNODE_HOME/scripts
./gLiveView.sh
```
