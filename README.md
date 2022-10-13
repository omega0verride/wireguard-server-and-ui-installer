A highly costumizable script to install WireGuard Server and WireGuard-UI admin panel.

Please refer to https://github.com/ngoduykhanh/wireguard-ui for more details on the UI. This is simply an installer.

Usage:
```
./wireguard-setup.sh --help

usage: ./wireguard-setup.sh [args]
-h  |--help                [print this help message]
-s  |--silent|-q|--quiet   [the installation will not prompt for any input and will use the provided CLI/default values]
-y  |--yes|--skipprompts   [the installation will not prompt for confirmations]
-w  |--config|--configpath [the path where WireGuard config will be created (/etc/wireguard)]
-p  |-port|--wgport        [the port on which WireGuard will listen (51838)]
-pbi|--publicinterface     [the interface with an internet connection (eth0)]
-wgi|--wginterface         [the interface that will be created for WireGuard (wg0)]
-c  |--cidr                [the server interface address, the wg server will be assigned the first IP of the range, i.e: 10.8.0.1 (10.8.0.0/26)]
-o  |--online              [if specified, the script will download wireguard-ui from --wguilink, otherwise it will use the local build in the same dir]
-u  |--wguilink |--wguiurl [link to the latest wgui release
                            (https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.3.7/wireguard-ui-v0.3.7-linux-amd64.tar.gz)]
-pp |--webuiport|--uiport  [the port on which WireGuard UI will run (5000)]
-l  |--localonly           [ <1|0> if set to 1 the web ui can be accessed only from localhost (default: 0)]
-us |--username            [username of WireGuard-UI (admin)]
-g  |--wguipath |--wguidir [the path where WireGuard-ui will be installed (/opt/wgui)]
-pw |--password            [password of WireGuard-UI (omega@wireguard)]
-b  |--wguibin             [path where the symbolic link for wgui will be made (/usr/local/bin)]
-ctl|--systemctl           [path to systemctl (/usr/bin/systemctl)]
```