A highly costumizable script to install WireGuard Server and WireGuard-UI admin panel.  
  
Please refer to https://github.com/ngoduykhanh/wireguard-ui for more details on the UI. This is simply an installer.  

Usage:  
```
./setup.sh --help  

usage: ./setup.sh [args]  
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
-pw |--password            [password of WireGuard-UI (omega@wireguard)]
-g  |--wguipath |--wguidir [the path where WireGuard-ui will be installed (/opt/wgui)]
-b  |--wguibin             [path where the symbolic link for wgui will be made (/usr/local/bin)]
-ctl|--systemctl           [path to systemctl (/usr/bin/systemctl)]
```  
### Note:  
```--configpath``` is the path to the directory where all the config files are located/will be generated (/etc/wireguard)  
It does __not__ point to the config file  
It is used in combination with ```--wginterface``` to form the full path (/etc/wireguard/wg0.conf)  

Running ./setup.sh -q will try to install everything silently using the default values.  
### MAKE SURE YOU CHANGE THE UI PASSWORD OR USE --localonly

The only time the __quiet__ installer will ask for input is if there is a conflict with the WG interface or port.  
In that case it will prompt to delete any old failed or successfull installation with the same interface.  
```
 Interface 'wg0' already exists! Please specify another interface or remove the old one.
 This error might have been caused by a conflict from a previous installation or an unsuccessful installation.
 You have to to delete any old installtion or failed setup with the same properties, including:
 WIREGUARD_INTERFACE wg0
 WG_PORT
 WG_WEB_UI_PORT
Do you want to remove any possible previous installation with this config? [n/y]
```

Running as "non-quiet", without the --quiet flag will force the installer to ask for input on most of the values.  
You can press enter to use the predefined, reccomended values for all of them.
It will also check if the port or the interface specified is being used.

All the properties can be configured from:
1. editing the script default values
2. specifying cli args
3. using the interactive installer (without --quiet)
or a combination of all

### TODO:
1. Add firewall config

### ISSUES:
1. The current WireGuard-UI download link from https://github.com/ngoduykhanh/wireguard-ui is outdated and does not recognise the specified environment args.
If --online is specified the UI will not recognise the custom options and will use its own default config.
I have request the owner to release a new build.
The local build shipped with this script works as expected but is only compiled for amd64.

A sample of a sucessful run
```
./setup.sh -q
 CLI Values:
 --WireGuard--
 WIREGUARD_CONFIG_PATH:
 PUBLIC_INTERFACE:
 WIREGUARD_INTERFACE:
 CIDR:
 WG_PORT:
 --WGUI--
 WGUI_DOWNLOAD_LINK:
 WGUI_INTSTALLATION_PATH:
 WGUI_BIN_PATH:
 WG_WEB_UI_PORT:
 WGUI_LOCALHOST_ONLY:
 WGUI_USERNAME:
 WGUI_PASSWORD:
 --Other--
 SILENT: 1
 CONFIRM:
 SYSTEMCTL_PATH:

 No SYSTEMCTL_PATH specified, using default: /usr/bin/systemctl
 No WireGuardInterface specified, using default: wg0
 No PublicInterface specified, using default: eth0
 No WireGuard config path specified, using default: /etc/wireguard
 No CIDR specified, using default: 10.8.0.0/26
 The server will be assigned to this IP:  10.8.0.1/32
 No WireGuard listen port specified, using default: 51838
 Port available! 51838
 No download url specified, using default: https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.3.7/wireguard-ui-v0.3.7-linux-amd64.tar.gz
 No WGUI_INTSTALLATION_PATH specified, using default: /opt/wgui
 No WGUI_BIN_PATH specified, using default: /usr/local/bin
 No WireGuard listen port specified, using default: 5000
 Port available! 5000
 No WGUI_LOCALHOST_ONLY value specified, using default: 0
 No WG-UI username specified, using default: admin
 No WG-UI password specified, using default: omega@wireguard
 Final Values:
 --WireGuard--
 WIREGUARD_CONFIG_PATH: /etc/wireguard
 PUBLIC_INTERFACE: eth0
 WIREGUARD_INTERFACE: wg0
 CIDR: 10.8.0.0/26
 ServerIP: 10.8.0.1
 Subnet: 26
 WG_PORT: 51838
 PrivateKeyFile: /etc/wireguard/private_wg0.key
 PublicKeyFile: /etc/wireguard/public_wg0.key
 ConfigFile: /etc/wireguard/wg0.conf
 --WGUI--
 WGUI_DOWNLOAD_LINK: https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.3.7/wireguard-ui-v0.3.7-linux-amd64.tar.gz
 WGUI_INTSTALLATION_PATH: /opt/wgui
 WGUI_BIN_PATH: /usr/local/bin
 WG_WEB_UI_PORT: 5000
 WGUI_LOCALHOST_ONLY: 0
 WG_WEB_UI_IP: 0.0.0.0
 WGUI_USERNAME: admin
 WGUI_PASSWORD: omega@wireguard
 --Other--
 SYSTEMCTL_PATH: /usr/bin/systemctl

 ----------------------
 Starting Installation
 ----------------------
 ----------------------
 Installing Dependencies!
 ----------------------
Reading package lists... Done
Building dependency tree
Reading state information... Done
iproute2 is already the newest version (5.5.0-1ubuntu1).
The following packages were automatically installed and are no longer required:
  golang-1.13 golang-1.13-doc golang-1.13-go golang-1.13-race-detector-runtime golang-1.13-src golang-doc golang-go golang-race-detector-runtime golang-src pkg-config python3-cliapp
  python3-markdown python3-packaging python3-pygments python3-pyparsing python3-ttystatus
Use 'apt autoremove' to remove them.
0 upgraded, 0 newly installed, 0 to remove and 244 not upgraded.
 ----------------------
 Installing WireGuard
 ----------------------
Reading package lists... Done
Building dependency tree
Reading state information... Done
wireguard is already the newest version (1.0.20200513-1~20.04.2).
The following packages were automatically installed and are no longer required:
  golang-1.13 golang-1.13-doc golang-1.13-go golang-1.13-race-detector-runtime golang-1.13-src golang-doc golang-go golang-race-detector-runtime golang-src pkg-config python3-cliapp
  python3-markdown python3-packaging python3-pygments python3-pyparsing python3-ttystatus
Use 'apt autoremove' to remove them.
0 upgraded, 0 newly installed, 0 to remove and 244 not upgraded.
 Successfully installed WireGuard! Configuring...


 Generating key pair for WireGuard
 Generating private key... -> file /etc/wireguard/private_wg0.key
 PrivateKey: KINcOlZDRPKWerds1TjJ2UvU4dBk1HmXP5nmnBRRm2w=
 Generating public key... -> file /etc/wireguard/public_wg0.key
 PublicKey: AWjzj4lbmaT9FdfQnbfnGgKG1ydoCyjRYCxUGwl6mHU=
 Successfully generated WireGuard keys!

 Generating WireGuard config -> file /etc/wireguard/wg0.conf

[Interface]
Address = 10.8.0.1/32
ListenPort = 51838
PrivateKey = KINcOlZDRPKWerds1TjJ2UvU4dBk1HmXP5nmnBRRm2w=
PostUp =
PostDown =

 Successfully generated config file!

 Enabling IPv4 forwarding
 Found existing entry in /etc/sysctl.conf, modifying...
 Successfully enabled IPv4 forwarding!

 Setting Up WireGuard Services
 Starting WireGuard server...
 Successfully configured and started WireGuard services!

 ----------------------
 Installing Wireguard-UI
 ----------------------
 Creating installation directory: /opt/wgui
 Directory created sucessfully!
 Creating symbolic link between /opt/wgui/wireguard-ui -> /usr/local/bin/wireguard-ui
 Successfully created link!
 Successfully installed WireGuard-UI!

 Setting Up WireGuard-UI Services
 Successfully configured and started WireGuard-UI services!

 Exporting keypair to WireGuard-UI -> /opt/wgui/wg0/db/server/keypair.json
 Successfully exported keypair!
 Restarting wgui_http_wg0.service after exporting keypair...

##################################################################################
                                    Setup done.
[WireGuard-Interface]: wg0
[WireGuard-Config]: /etc/wireguard/wg0.conf
[WireGuard-UI URL]: 0.0.0.0:5000
[WireGuard-UI accessible from localhost only]: 0
[WireGuard-UI Usernmae]: admin
[WireGuard-UI Password]: omega@wireguard

[WireGuard Service] -> wg-quick@wg0.service
/usr/bin/systemctl enable wg-quick@wg0.service
/usr/bin/systemctl disable wg-quick@wg0.service
/usr/bin/systemctl start wg-quick@wg0.service
/usr/bin/systemctl stop wg-quick@wg0.service

[WireGuard UI Service] -> wgui_http_wg0.service
/usr/bin/systemctl enable wgui_http_wg0.service
/usr/bin/systemctl disable wgui_http_wg0.service
/usr/bin/systemctl start wgui_http_wg0.service
/usr/bin/systemctl stop wgui_http_wg0.service

[WireGuard UI Config Change-Listener Service/Path] -> wg_config_change_listener_wg0
/usr/bin/systemctl enable wg_config_change_listener_wg0.{path,service}
/usr/bin/systemctl disable wg_config_change_listener_wg0.{path,service}
/usr/bin/systemctl start wg_config_change_listener_wg0.{path,service}
/usr/bin/systemctl stop wg_config_change_listener_wg0.{path,service}

##################################################################################
 You can find these details saved at /root/wg_setup_info_wg0.log
```
