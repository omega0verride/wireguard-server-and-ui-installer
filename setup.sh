#!/bin/bash
# @omega0verride
set -e

# default values
DEFAULT_SYSTEMCTL_PATH="/usr/bin/systemctl"     # systemctl path
WGUI_KEYPARI_FILE_PATH="db/server/keypair.json" # the path where WireGuard-UI saves the keypair

# WireGuard
DEFAULT_WIREGUARD_CONFIG_PATH="/etc/wireguard"                           # the path where WireGuard config will be created
DEFAULT_WIREGUARD_INTERFACE="wg0"                                        # name of the WireGuard interface that will be created
DEFAULT_CIDR=10.8.0.0/26                                                 # the server interface address, the wg server will be assigned the first IP of the range, i.e: 10.8.0.1 unless --serverip is specified
DEFAULT_PUBLIC_INTERFACE=$(ip route list default | awk -- '{printf $5}') # the default public interface guess
DEFAULT_WG_PORT=51838                                                    # the port on which WireGuard will run

# WGUI
DEFAULT_ONLINE=0
DEFAULT_WGUI_DOWNLOAD_LINK="https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.3.7/wireguard-ui-v0.3.7-linux-amd64.tar.gz" # Link to the latest wgui release
DEFAULT_WGUI_INTSTALLATION_PATH="/opt/wgui"                                                                                              # the path where WireGuard-ui will be installed
DEFAULT_WGUI_BIN_PATH="/usr/local/bin"                                                                                                   # path where the symbolic link for wgui will be made
DEFAULT_WG_WEB_UI_PORT=5000
DEFAULT_WGUI_LOCALHOST_ONLY=1
DEFAULT_WGUI_USERNAME="admin"
DEFAULT_WGUI_PASSWORD="omega@wireguard"

# A list of some of the variables the script will use, those will be resolved later by the "input" functions
# ----------------------------------------------------------------------------
# SILENT=''
# CONFIRM=''
# ONLINE=''
# INSTALL_ONLY_WGUI=''

# SYSTEMCTL_PATH=''

# # WireGuard
# WIREGUARD_CONFIG_PATH=''
# PUBLIC_INTERFACE=''
# WIREGUARD_INTERFACE=''
# CIDR=''
# ServerIP=''
# Subnet=''
# WG_PORT=''

# # WGUI
# WGUI_DOWNLOAD_LINK=''
# WGUI_INTSTALLATION_PATH=''
# WGUI_BIN_PATH=''
# WG_WEB_UI_PORT=''
# WGUI_LOCALHOST_ONLY=''
# WG_WEB_UI_IP=''
# WGUI_USERNAME
# WGUI_PASSWORD

# # other
# PrivateKeyFile=''
# PublicKeyFile=''
# ConfigFile=''
# ----------------------------------------------------------------------------

main() {

  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root!"
    exit 1
  fi

  parse_cli_args "$@"

  if [ -z "$SILENT" ]; then SILENT=0; fi
  if [ -z "$SKIPPROMPTS"]; then CONFIRM=1; fi

  get_and_validate_required_args

  SETUP_INFO_FILE=~/wg_setup_info_$WIREGUARD_INTERFACE.log
  PrivateKeyFile=$WIREGUARD_CONFIG_PATH/private_$WIREGUARD_INTERFACE.key
  PublicKeyFile=$WIREGUARD_CONFIG_PATH/public_$WIREGUARD_INTERFACE.key
  ConfigFile=$WIREGUARD_CONFIG_PATH/$WIREGUARD_INTERFACE.conf
  WGUI_WORKING_DIR=$WGUI_INTSTALLATION_PATH/$WIREGUARD_INTERFACE

  print_final_config_values

  echo ""
  msg "----------------------"
  msg "ok" "Starting Installation"
  msg "----------------------"
  msg "----------------------"
  msg "ko" "Installing Dependencies!"
  msg "----------------------"
  if [ ! $(which iproute2)  ]; then
    apt install iproute2 -y || { msg "ko" "Could not install package 'iproute2'!"; exit 1; }
  fi

  if [ "$INSTALL_ONLY_WGUI" -eq 0 ]; then
    msg "----------------------"
    msg "Installing WireGuard"
    msg "----------------------"
    apt -y install wireguard || { msg "ko" "Could not install package 'wireguard'!"; exit 1; }
    msg "ok" "Successfully installed WireGuard! Configuring..."


    msg ""
    mkdir -p $WIREGUARD_CONFIG_PATH || {
      msg "Could not create config root dir! PATH='$WIREGUARD_CONFIG_PATH'"
      exit 1
    }

    echo ""
    generate_wg_keypair $EXISTING_PRIVATE_KEY || {
      msg "ko" "Could not generate key-pair for WireGuard!"
      exit 1
    }

    echo ""
    generate_wg_config || {
      msg "ko" "Could not generate config!"
      exit 1
    }

    echo ""
    enable_ipv4_forwarding

    # to do firewall

    echo ""
    create_wg_service
  fi 
  # put wireguard config on the if above
  # leave wg-ui fw config outside
  # todo firewall config
  # ufw allow 51820/udp
  # ufw disable
  # ufw enable

  # todo postup postdown?

  echo ""
  install_wg_ui

  rm -rf $WGUI_WORKING_DIR   # delete old wireguard-ui dir if it exists to make sure we do not use old db config
  mkdir -p $WGUI_WORKING_DIR # create interface specific working directory for wireguard-ui to save its "db" files

  echo ""
  create_wgui_service

  if [ "$INSTALL_ONLY_WGUI" -eq 1 ]; then
    echo ""
    generate_wg_keypair $EXISTING_PRIVATE_KEY || {
      msg "ko" "Could not generate key-pair from existing pricate key!"
      exit 1
    }
  fi

  echo ""
  export_keypair || {
    msg "ko" "Could not export keypair!"
    exit 1
  }
  msg "Restarting $WGUI_SERVICE after exporting keypair..."
  $SYSTEMCTL_PATH restart $WGUI_SERVICE

  print_setup_done_message

  exit
}

# ------ installer functions -------

function generate_wg_keypair() {
  msg "Generating key-pair for WireGuard"
  existingPrivateKey=$1
  if [ -z "$existingPrivateKey" ]; then
    msg "warn" "No private key specified. Generating new key!"
  else
    msg "warn" "Using specified private key: $1"
  fi

  msg "Writing private key... -> file $PrivateKeyFile"
  touch $PrivateKeyFile || exit 1
  chmod 700 $PrivateKeyFile # allow access only to root users
  if [ -z "$existingPrivateKey" ]; then
    wg genkey >"$PrivateKeyFile" || return 1
  else
    echo $existingPrivateKey >"$PrivateKeyFile" || return 1
  fi
  
  PrivateKey=$(cat $PrivateKeyFile) || return 1
  msg "ok" "PrivateKey: $PrivateKey"

  msg "Writing public key... -> file $PublicKeyFile"
  wg pubkey <<<"$PrivateKey" >"$PublicKeyFile" || return 1
  PublicKey=$(cat $PublicKeyFile) || return 1
  msg "ok" "PublicKey: $PublicKey"

  msg "ok" "Successfully generated WireGuard keys!"
  return 0
}

function generate_wg_config() {
  msg "Generating WireGuard config -> file $ConfigFile"
  printf -v config "
[Interface]
Address = $ServerIP/32
ListenPort = $WG_PORT
PrivateKey = $PrivateKey
PostUp = ""
PostDown = ""
"
  # PostUp = ufw route allow in on $WIREGUARD_INTERFACE out on $PUBLIC_INTERFACE
  # PostUp = iptables -t nat -I POSTROUTING -o $PUBLIC_INTERFACE -j MASQUERADE
  # PreDown = ufw route delete allow in on $WIREGUARD_INTERFACE out on $PUBLIC_INTERFACE
  # PreDown = iptables -t nat -D POSTROUTING -o $PUBLIC_INTERFACE -j MASQUERADE
  msg "info" "$config"
  rm -f $ConfigFile || return 1
  echo "$config" >>$ConfigFile || return 1
  msg "ok" "Successfully generated config file!"
  return 0
}

function export_keypair() {
  msg "Exporting key-pair to WireGuard-UI -> $WGUI_WORKING_DIR/$WGUI_KEYPARI_FILE_PATH"
  printf -v keypair "{
        \"private_key\": \"$PrivateKey\",
        \"public_key\": \"$PublicKey\",
        \"updated_at\": \"$(date +%Y-%m-%dT%H:%M:%S.%NZ)\"
}
"
  rm -f $WGUI_WORKING_DIR/$WGUI_KEYPARI_FILE_PATH || return 1
  mkdir -p $WGUI_WORKING_DIR/$WGUI_KEYPARI_FILE_PATH
  echo "$keypair" >>$WGUI_WORKING_DIR/$WGUI_KEYPARI_FILE_PATH || return 1
  msg "ok" "Successfully exported key-pair!"
  return 0
}

function install_wg_ui() {
  msg "----------------------"
  msg "Installing Wireguard-UI"
  msg "----------------------"
  msg "Creating installation directory: $WGUI_INTSTALLATION_PATH"
  if [ ! -d $WGUI_INTSTALLATION_PATH ]; then
    mkdir -m 077 $WGUI_INTSTALLATION_PATH || {
      msg "ko" "Could not create WG-UI installation driectory: $WGUI_INTSTALLATION_PATH"
      exit 1
    }
  fi
  msg "ok" "Directory created sucessfully!"

  if [ "$ONLINE" -eq 0 ]; then
      cp wireguard-ui $WGUI_INTSTALLATION_PATH || { msg "ko" "Could not copy wireguard-ui from installer directory!"; exit 1; } # add support for local build in same directory
  else
    msg "Downlading and extracting WG-UI from $WGUI_DOWNLOAD_LINK"
    wget -qO - $WGUI_DOWNLOAD_LINK | tar xzf - -C $WGUI_INTSTALLATION_PATH || { msg "ko" "Could not download WG-UI from url: WGUI_DOWNLOAD_LINK"; exit 1; }
    msg "ok" "Successfully downloaded WG-UI!"
  fi


  msg "Creating symbolic link between $WGUI_INTSTALLATION_PATH/wireguard-ui -> $WGUI_BIN_PATH/wireguard-ui"
  ln -s -f $WGUI_INTSTALLATION_PATH/wireguard-ui $WGUI_BIN_PATH/wireguard-ui || {
    msg "ko" "Could not create symbolic link for WG-UI installation in WGUI_BIN_PATH: $WGUI_BIN_PATH/wireguard-ui"
    exit 1
  }
  msg "ok" "Successfully created link!"

  msg "ok" "Successfully installed WireGuard-UI!"
}

function enable_ipv4_forwarding() {
  msg "Enabling IPv4 forwarding"
  file="/etc/sysctl.conf"
  pattern="#*\s*net.ipv4.ip_forward\s*=\s*(0|1)"
  if grep -qP "$pattern" $file; then
    msg "Found existing entry in $file, modifying..."
    sed -ir "s/$pattern/net.ipv4.ip_forward = 1/g" $file || {
      msg "ko" "Could not set net.ipv4.ip_forward = 1 on $file"
      exit 1
    }
  else
    msg "No existing entry, appending to $file..."
    echo "net.ipv4.ip_forward = 1" >>$file || {
      msg "ko" "Could not set net.ipv4.ip_forward = 1 on $file"
      exit 1
    }
  fi
  out=$''
  if sysctl -p | grep -q "net.ipv4.ip_forward = 1"; then
    msg "ok" "Successfully enabled IPv4 forwarding!"
  else
    msg "ko" "Could not set net.ipv4.ip_forward = 1 on $file"
  fi
}

function create_wgui_service() {
  msg "Setting Up WireGuard-UI Services"

  echo "[Unit]
  Description=Wireguard UI
  After=network.target
  [Service]
  Type=simple
  Environment=\"WGUI_USERNAME=$WGUI_USERNAME\"
  Environment=\"WGUI_PASSWORD=$WGUI_PASSWORD\"
  Environment=\"WGUI_CONFIG_FILE_PATH=$ConfigFile\"
  Environment=\"WGUI_SERVER_INTERFACE_ADDRESSES=$ServerIP/$Subnet\"
  Environment=\"WGUI_SERVER_LISTEN_PORT=$WG_PORT\"
  Environment=\"WGUI_DEFAULT_CLIENT_ALLOWED_IPS=$ServerIP/32\"
  Environment=\"WGUI_DEFAULT_CLIENT_USE_SERVER_DNS=false\"
  Environment=\"WGUI_DEFAULT_CLIENT_ENABLE_AFTER_CREATION=true\"
  WorkingDirectory=$WGUI_WORKING_DIR
  ExecStart=$WGUI_BIN_PATH/wireguard-ui -bind-address $WG_WEB_UI_IP:$WG_WEB_UI_PORT
  [Install]
  WantedBy=multi-user.target" > /etc/systemd/system/$WGUI_SERVICE

  $SYSTEMCTL_PATH enable $WGUI_SERVICE
  $SYSTEMCTL_PATH start $WGUI_SERVICE

  echo "[Unit]
  Description=Restart WireGuard
  After=network.target
  [Service]
  Type=oneshot
  ExecStart=$SYSTEMCTL_PATH restart $WG_SERVICE" > /etc/systemd/system/$WG_CHANGE_LISTENER_SERVICE.service

  echo "[Unit]
  Description=Watch $ConfigFile for changes
  [Path]
  PathModified=$ConfigFile
  [Install]
  WantedBy=multi-user.target" > /etc/systemd/system/$WG_CHANGE_LISTENER_SERVICE.path

  $SYSTEMCTL_PATH enable $WG_CHANGE_LISTENER_SERVICE.{path,service}
  $SYSTEMCTL_PATH start $WG_CHANGE_LISTENER_SERVICE.{path,service}

  msg "ok" "Successfully configured and started WireGuard-UI services!"
}

function create_wg_service() {
  msg "Setting Up WireGuard Services"
  $SYSTEMCTL_PATH enable $WG_SERVICE || {
    msg "ko" "Could not enable WireGuard Service $WG_SERVICE"
    exit 1
  }
  msg "Starting WireGuard server..."
  $SYSTEMCTL_PATH start $WG_SERVICE || {
    msg "ko" "Could not start WireGuard Service $WG_SERVICE"
    exit 1
  }
  msg "ok" "Successfully configured and started WireGuard services!"
}

function clean_old_installation_with_same_config() {
  $SYSTEMCTL_PATH disable $WG_SERVICE || msg "info" "Could not disable service: $WG_SERVICE"
  $SYSTEMCTL_PATH stop $WG_SERVICE && rm -f /etc/systemd/system/$WG_SERVICE || msg "info" "Could not stop/remove service: $WG_SERVICE"
  $SYSTEMCTL_PATH disable $WGUI_SERVICE || msg "info" "Could not disable service: $WGUI_SERVICE"
  $SYSTEMCTL_PATH stop $WGUI_SERVICE && rm -f /etc/systemd/system/$WGUI_SERVICE || msg "info" "Could not stop/remove service: $WGUI_SERVICE"
  $SYSTEMCTL_PATH disable $WG_CHANGE_LISTENER_SERVICE.{path,service} || msg "info" "Could not disable service: $WG_CHANGE_LISTENER_SERVICE.{path,service}"
  $SYSTEMCTL_PATH stop $WG_CHANGE_LISTENER_SERVICE.{path,service} && rm -f /etc/systemd/system/$WG_CHANGE_LISTENER_SERVICE.path && /etc/systemd/system/$WG_CHANGE_LISTENER_SERVICE.service || msg "info" "Could not stop/remove service: $WG_CHANGE_LISTENER_SERVICE.{path,service}"
  ip link delete $WIREGUARD_INTERFACE || msg "info" "Could not delete interface: $WIREGUARD_INTERFACE"
  rm -rf $WGUI_WORKING_DIR || msg "info" "Could not remove $WGUI_WORKING_DIR"
  rm -f $ConfigFile || msg "info" "Could not remove $ConfigFile"
  msg "ok" "Cleanup done!"
}

function prompt_clean_old_installation_with_same_config() {
  msg "This error might have been caused by a conflict from a previous installation or an unsuccessful installation."
  msg "You have to to delete any old installtion or failed setup with the same properties, including:"
  msg "WIREGUARD_INTERFACE $WIREGUARD_INTERFACE"
  msg "WG_PORT $WG_PORT"
  msg "WG_WEB_UI_PORT $WG_WEB_UI_PORT"

  read -p "Do you want to remove any possible previous installation with this config? [n/y] " tmpYN
  case $tmpYN in
  Y | y | yes | Yes | YES)
    read -p "This will delete any previous installation with these configs! Confirm choice? [n/y] " yn
    case $yn in
    Y | y | yes | Yes | YES)
      clean_old_installation_with_same_config
      msg "ok" "Retrying installation in 5s..."
      sleep 5
      main "$@"
      ;;
    *) return 1;;
    esac
    ;;
  *) return 1;;
  esac
}

# ------ user input/args functions -------

function parse_cli_args() {
  # https://unix.stackexchange.com/a/603569
  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      print_help
      exit 0
      ;;
    -s | --silent | -q | --quiet)
      SILENT=1
      ;;
    -y | --yes | --skipprompts)
      CONFIRM=0
      ;;
    -ui | --uionly)
      INSTALL_ONLY_WGUI=1
      ;;
    -w | --config | --configpath)
      WIREGUARD_CONFIG_PATH="$2"
      shift
      ;;
    -pki|--privatekey)
      $EXISTING_PRIVATE_KEY="$2"
      shift
      ;;
    -p | --port | --wgport)
      WG_PORT="$2"
      shift
      ;;
    -pbi | --publicinterface)
      PUBLIC_INTERFACE="$2"
      shift
      ;;
    -wgi | --wginterface)
      WIREGUARD_INTERFACE="$2"
      shift
      ;;
    -c | --cidr)
      CIDR="$2"
      shift
      ;;
    -ip | --serverip)
      ServerIP="$2"
      shift
      ;;
    -o | --online)
      ONLINE=1
      ;;
    -lo | --local)
      ONLINE=0
      ;;
    -u | --wguilink | --wguiurl)
      WGUI_DOWNLOAD_LINK="$2"
      shift
      ;;
    -g | --wguipath | --wguidir)
      WGUI_INTSTALLATION_PATH="$2"
      shift
      ;;
    -pp | --webuiport | --uiport)
      WG_WEB_UI_PORT="$2"
      shift
      ;;
    -l | --localonly)
      WGUI_LOCALHOST_ONLY=$2
      shift
      ;;
    -b | --wguibin)
      WGUI_BIN_PATH="$2"
      shift
      ;;
    -us | --username)
      WGUI_USERNAME="$2"
      shift
      ;;
    -pw | --password)
      WGUI_PASSWORD="$2"
      shift
      ;;
    -ctl | --systemctl)
      SYSTEMCTL_PATH="$2"
      shift
      ;;
    *)
      print_help
      msg "ko" "***************************"
      msg "ko" "* Error: Invalid argument.*"
      msg "ko" "***************************"
      exit 1
      ;;
    esac
    shift
  done

  msg "info" "CLI Values:"
  msg "info" "--WireGuard--"
  print_user_cli_value "WIREGUARD_CONFIG_PATH" "$WIREGUARD_CONFIG_PATH"
  print_user_cli_value "$EXISTING_PRIVATE_KEY" "$EXISTING_PRIVATE_KEY"
  print_user_cli_value "PUBLIC_INTERFACE" "$PUBLIC_INTERFACE"
  print_user_cli_value "WIREGUARD_INTERFACE" "$WIREGUARD_INTERFACE"
  print_user_cli_value "CIDR" "$CIDR"
  print_user_cli_value "ServerIP" "$ServerIP"
  print_user_cli_value "WG_PORT" "$WG_PORT"
  msg "info" "--WGUI--"
  print_user_cli_value "WGUI_DOWNLOAD_LINK" "$WGUI_DOWNLOAD_LINK"
  print_user_cli_value "WGUI_INTSTALLATION_PATH" "$WGUI_INTSTALLATION_PATH"
  print_user_cli_value "WGUI_BIN_PATH" "$WGUI_BIN_PATH"
  print_user_cli_value "WG_WEB_UI_PORT" "$WG_WEB_UI_PORT"
  print_user_cli_value "WGUI_LOCALHOST_ONLY" "$WGUI_LOCALHOST_ONLY"
  print_user_cli_value "WGUI_USERNAME" "$WGUI_USERNAME"
  print_user_cli_value "WGUI_PASSWORD" "$WGUI_PASSWORD"
  msg "info" "--Other--"
  print_user_cli_value "SILENT" "$SILENT"
  print_user_cli_value "CONFIRM" "$CONFIRM"
  print_user_cli_value "ONLINE" "$ONLINE"
  print_user_cli_value "INSTALL_ONLY_WGUI" "$INSTALL_ONLY_WGUI"
  print_user_cli_value "SYSTEMCTL_PATH" "$SYSTEMCTL_PATH"
  echo ""
}

function get_and_validate_required_args() {

  # check INSTALL_ONLY_WGUI
  if [ -z "$INSTALL_ONLY_WGUI" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Do you want the istaller to insall only wireguard-ui and use an existing wireguard server (n)? [n/y]: " tmpUIonly
        if [ -z "$tmpUIonly" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            INSTALL_ONLY_WGUI=1
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$INSTALL_ONLY_WGUI" ]; then
      INSTALL_ONLY_WGUI=0
    fi
  fi

  # check SYSTEMCTL_PATH
  if [ -z "$SYSTEMCTL_PATH" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Provide the systemctl path. Press enter to use the default path ($DEFAULT_SYSTEMCTL_PATH): " tmpDefaultSystemctlPath
        if [ -z "$tmpDefaultSystemctlPath" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            SYSTEMCTL_PATH=$tmpDefaultSystemctlPath
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$SYSTEMCTL_PATH" ]; then
      SYSTEMCTL_PATH=$DEFAULT_SYSTEMCTL_PATH
      msg "warn" "No SYSTEMCTL_PATH specified, using default: $SYSTEMCTL_PATH"
    fi
  fi

  # check WIREGUARD_INTERFACE
  if [ -z "$WIREGUARD_INTERFACE" ]; then
    while true; do
      defaultFlag=0
      if [ "$SILENT" == 0 ]; then
        read -p "Provide the name of the wireguard interface you want to use. Press enter to use the default interface ($DEFAULT_WIREGUARD_INTERFACE): " WIREGUARD_INTERFACE
      fi
      if [ -z "$WIREGUARD_INTERFACE" ]; then
        WIREGUARD_INTERFACE=$DEFAULT_WIREGUARD_INTERFACE
        msg "warn" "No WireGuardInterface specified, using default: $WIREGUARD_INTERFACE"
        defaultFlag=1
      fi
      eval_services $WIREGUARD_INTERFACE
      if [ "$INSTALL_ONLY_WGUI" -eq 1 ] || check_if_network_interface_exitsts $WIREGUARD_INTERFACE; then
        if [ "$SILENT" == 0 ]; then
          if [ "$defaultFlag" == 0 ]; then
            if [ "$CONFIRM" == 1 ]; then
              read -p "Confirm choice? [y/n] " yn
            fi
          else
            yn=y
          fi
        else
          yn=y
        fi
        case $yn in
        "" | Y | y | yes | Yes | YES)
          WIREGUARD_INTERFACE=$WIREGUARD_INTERFACE
          break
          ;;
        *) ;;
        esac
      else
        if [ "$SILENT" == 1 ]; then
          exit 1
        fi
      fi
    done
    eval_services $WIREGUARD_INTERFACE
  else
    if [ "$INSTALL_ONLY_WGUI" -eq 0 ] && ! check_if_network_interface_exitsts $WIREGUARD_INTERFACE; then
      exit 1
    fi
  fi  

  # check WIREGUARD_CONFIG_PATH
  if [ -z "$WIREGUARD_CONFIG_PATH" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Provide the absolute path where the WireGuard config file should be created or is located. Press enter to use the default path ($DEFAULT_WIREGUARD_CONFIG_PATH): " tmpWireGuardConfigPath
        if [ -z "$tmpWireGuardConfigPath" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            WIREGUARD_CONFIG_PATH=$tmpWireGuardConfigPath
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$WIREGUARD_CONFIG_PATH" ]; then
      WIREGUARD_CONFIG_PATH=$DEFAULT_WIREGUARD_CONFIG_PATH
      msg "warn" "No WireGuard config path specified, using default: $WIREGUARD_CONFIG_PATH"
    fi
  fi

  # check EXISTING_PRIVATE_KEY
  if [ -z "$EXISTING_PRIVATE_KEY" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Enter the private key to be used with wireguard-server. Press enter to auto generate a new key.: " tmpKey
        if [ -z "$tmpKey" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            EXISTING_PRIVATE_KEY=$tmpKey
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$EXISTING_PRIVATE_KEY" ]; then
      msg "warn" "No Private Key specified. A new ket will be generated."
    fi
  fi

  # check CIDR
  if [ -z "$CIDR" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Please enter the server subnet in CIDR fromat. The wg server will be assigned the first IP of the range, i.e: 10.8.0.1 unless --serverip is specified. Press enter to use the default value ($DEFAULT_CIDR):  " CIDR
        if [ -z "$CIDR" ]; then break; fi
        if validate_cidr $CIDR; then
          if [ "$CONFIRM" == 1 ]; then
            read -p "Confirm choice? [y/n] " yn
            case $yn in
            "" | Y | y | yes | Yes | YES)
              CIDR=$CIDR
              break
              ;;
            *) ;;
            esac
          fi
        fi
      done
    fi
    if [ -z "$CIDR" ]; then
      CIDR=$DEFAULT_CIDR
      msg "warn" "No CIDR specified, using default: $CIDR"
    fi
  else
    if ! validate_cidr $CIDR; then
      exit 1
    fi
  fi

  # check ServerIP
  if [ -z "$ServerIP" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "The ip of the wireguard server. Should be in the CIDR subnet. i.e: 10.8.0.1. Press enter to auto-assign the value: " tmpIP
        if [ -z "$tmpIP" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            ServerIP=$tmpIP
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$ServerIP" ]; then
      ServerIP=$(resolve_server_ip_from_CIDR $CIDR) || msg "ko" "Could not resolve ip from CIDR: $CIDR"
      msg "warn" "No ServerIP specified, auto-assigning: $ServerIP"
    fi
  fi

  Subnet=$(resolve_subnet_from_CIDR $CIDR) || msg "ko" "Could not resolve subnet from CIDR: $CIDR"
  msg "ok" "The server will be assigned to this IP:" false
  msg $ServerIP/32

  # check WG_PORT
  if [ -z "$WG_PORT" ]; then
    while true; do
      defaultFlag=0
      if [ "$SILENT" == 0 ]; then
        read -p "Please enter the WireGuard listen port. Press enter to use the default value ($DEFAULT_WG_PORT):  " WG_PORT
      fi
      if [ -z "$WG_PORT" ]; then
        WG_PORT=$DEFAULT_WG_PORT
        msg "warn" "No WireGuard listen port specified, using default: $WG_PORT"
        defaultFlag=1
      fi
      if [ "$INSTALL_ONLY_WGUI" -eq 1 ] || check_if_port_is_available $WG_PORT; then
        if [ "$SILENT" == 0 ]; then
          if [ "$defaultFlag" == 0 ]; then
            if [ "$CONFIRM" == 1 ]; then
              read -p "Confirm choice? [y/n] " yn
            fi
          else
            yn=y
          fi
        else
          yn=y
        fi
        case $yn in
        "" | Y | y | yes | Yes | YES)
          WG_PORT=$WG_PORT
          break
          ;;
        *) ;;
        esac
      else
        if [ "$SILENT" == 1 ]; then
          exit 1
        fi
      fi
    done
  else
    if [ "$INSTALL_ONLY_WGUI" -eq 0 ] && ! check_if_port_is_available $WG_PORT; then
      exit 1
    fi
  fi

    # check ONLINE
  if [ -z "$ONLINE" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Do you want to download the wg-ui binary from github or use the wireguard-ui file included with this script. Note that the online build may not work. Last time I checked their builds are outdated. (y->online, defaults to: no): [n/y]" tmpOnline
        if [ -z "$tmpOnline" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            ONLINE=1
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$ONLINE" ]; then
      ONLINE=$DEFAULT_ONLINE  
      if [ "$ONLINE" -eq 1 ]; then
        msg "warn" "The installer will use the online wireguard-ui build."
      else
        msg "warn" "The installer will use the local wireguard-ui build."
      fi
    fi
  fi

  if [ "$ONLINE" -eq 1 ]; then
    # check WGUI_DOWNLOAD_LINK
    if [ -z "$WGUI_DOWNLOAD_LINK" ]; then
      if [ "$SILENT" == 0 ]; then
        while true; do
          read -p "Provide the download url of WGUI. Make sure the url is valid, otherwise, press enter to use the default latest download url ($DEFAULT_WGUI_DOWNLOAD_LINK): " tmpWguiDownloadLink
          if [ -z "$tmpWguiDownloadLink" ]; then break; fi
          if [ "$CONFIRM" == 1 ]; then
            read -p "Confirm choice? [y/n] " yn
            case $yn in
            "" | Y | y | yes | Yes | YES)
              WGUI_DOWNLOAD_LINK=$tmpWguiDownloadLink
              break
              ;;
            *) ;;
            esac
          fi
        done
      fi
      if [ -z "$WGUI_DOWNLOAD_LINK" ]; then
        WGUI_DOWNLOAD_LINK=$DEFAULT_WGUI_DOWNLOAD_LINK
        msg "warn" "No download url specified, using default: $WGUI_DOWNLOAD_LINK"
      fi
    fi
    fi

  # check WGUI_INTSTALLATION_PATH
  if [ -z "$WGUI_INTSTALLATION_PATH" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Provide the path where WGUI will be installed. Press enter to use the default path ($DEFAULT_WGUI_INTSTALLATION_PATH): " tmpWguiInstallationPath
        if [ -z "$tmpWguiInstallationPath" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            WGUI_INTSTALLATION_PATH=$tmpWguiInstallationPath
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$WGUI_INTSTALLATION_PATH" ]; then
      WGUI_INTSTALLATION_PATH=$DEFAULT_WGUI_INTSTALLATION_PATH
      msg "warn" "No WGUI_INTSTALLATION_PATH specified, using default: $WGUI_INTSTALLATION_PATH"
    fi
  fi

  # check WGUI_BIN_PATH
  if [ -z "$WGUI_BIN_PATH" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Provide the WGUI binary path on which the symbolic link will be made. Press enter to use the default path ($DEFAULT_WGUI_BIN_PATH): " tmpWguiBinPath
        if [ -z "$tmpWguiBinPath" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            WGUI_BIN_PATH=$tmpWguiBinPath
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$WGUI_BIN_PATH" ]; then
      WGUI_BIN_PATH=$DEFAULT_WGUI_BIN_PATH
      msg "warn" "No WGUI_BIN_PATH specified, using default: $WGUI_BIN_PATH"
    fi
  fi

  # check WG_WEB_UI_PORT
  if [ -z "$WG_WEB_UI_PORT" ]; then
    while true; do
      defaultFlag=0
      if [ "$SILENT" == 0 ]; then
        read -p $'Please enter the WireGuard \e[1;34mWeb UI\e[0;39m listen port. Press enter to use the default value '"($DEFAULT_WG_WEB_UI_PORT): " WG_WEB_UI_PORT
      fi
      if [ -z "$WG_WEB_UI_PORT" ]; then
        WG_WEB_UI_PORT=$DEFAULT_WG_WEB_UI_PORT
        msg "warn" "No WireGuard listen port specified, using default: $WG_WEB_UI_PORT"
        defaultFlag=1
      fi
      if check_if_port_is_available $WG_WEB_UI_PORT; then
        if [ "$SILENT" == 0 ]; then
          if [ "$defaultFlag" == 0 ]; then
            if [ "$CONFIRM" == 1 ]; then
              read -p "Confirm choice? [y/n] " yn
            fi
          else
            yn=y
          fi
        else
          yn=y
        fi
        case $yn in
        "" | Y | y | yes | Yes | YES)
          WG_WEB_UI_PORT=$WG_WEB_UI_PORT
          break
          ;;
        *) ;;
        esac
      else
        if [ "$SILENT" == 1 ]; then
          exit 1
        fi
      fi
    done
  else
    if ! check_if_port_is_available $WG_WEB_UI_PORT; then
      exit 1
    fi
  fi

  # check WGUI_LOCALHOST_ONLY
  if [ -z "$WGUI_LOCALHOST_ONLY" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        WGUI_LOCALHOST_ONLY=0
        read -p "Should the Web UI accessible outside localhost? [y/n] ($DEFAULT_WGUI_LOCALHOST_ONLY): " wguiLocalhostOnly_YN
        if [ -z "$wguiLocalhostOnly_YN" ]; then break; fi
        case $wguiLocalhostOnly_YN in
        "" | Y | y | yes | Yes | YES)
          WGUI_LOCALHOST_ONLY=1
          ;;
        *) ;;
        esac
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$WGUI_LOCALHOST_ONLY" ]; then
      WGUI_LOCALHOST_ONLY=$DEFAULT_WGUI_LOCALHOST_ONLY
      msg "warn" "No WGUI_LOCALHOST_ONLY value specified, using default: $WGUI_LOCALHOST_ONLY"
    fi
  fi

  if [ "$WGUI_LOCALHOST_ONLY" -eq 1 ]; then
    WG_WEB_UI_IP="127.0.0.1"
  else
    WG_WEB_UI_IP="0.0.0.0"
  fi

  # check WGUI_USERNAME
  if [ -z "$WGUI_USERNAME" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Provide the username of your WireGuard-UI WEB Admin Panel. Press enter to use the default value ($DEFAULT_WGUI_USERNAME): " tmpWguiUsername
        if [ -z "$tmpWguiUsername" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            WGUI_USERNAME=$tmpWguiUsername
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$WGUI_USERNAME" ]; then
      WGUI_USERNAME=$DEFAULT_WGUI_USERNAME
      msg "warn" "No WG-UI username specified, using default: $WGUI_USERNAME"
    fi
  fi

  # check WGUI_PASSWORD
  if [ -z "$WGUI_PASSWORD" ]; then
    if [ "$SILENT" == 0 ]; then
      while true; do
        read -p "Provide the password of your WireGuard-UI WEB Admin Panel. Press enter to use the default value ($DEFAULT_WGUI_PASSWORD): " tmpWguiPassword
        if [ -z "$tmpWguiPassword" ]; then break; fi
        if [ "$CONFIRM" == 1 ]; then
          read -p "Confirm choice? [y/n] " yn
          case $yn in
          "" | Y | y | yes | Yes | YES)
            WGUI_PASSWORD=$tmpWguiPassword
            break
            ;;
          *) ;;
          esac
        fi
      done
    fi
    if [ -z "$WGUI_PASSWORD" ]; then
      WGUI_PASSWORD=$DEFAULT_WGUI_PASSWORD
      msg "warn" "No WG-UI password specified, using default: $WGUI_PASSWORD"
    fi
  fi
}

function eval_services() {
  WG_SERVICE=wg-quick@$1.service
  WGUI_SERVICE=wgui_http_$1.service
  WG_CHANGE_LISTENER_SERVICE=wg_config_change_listener_$1
}
# ------- utils ---------

function validate_cidr() {
  CIDR="$1"

  # Parse "a.b.c.d/n" into five separate variables
  IFS="./" read -r ip1 ip2 ip3 ip4 N <<<"$CIDR"
  if [ -z "$ip1" ] || [ -z "$ip2" ] || [ -z "$ip3" ] || [ -z "$ip4" ] || [ -z "$N" ]; then
    msg "ko" "Invalid CIDR format: $CIDR"
    return 1
  fi

  # Convert IP address from quad notation to integer
  ip=$(($ip1 * 256 ** 3 + $ip2 * 256 ** 2 + $ip3 * 256 + $ip4))

  # Remove upper bits and check that all $N lower bits are 0
  if [ "$N" -gt 32 ] || [ "$N" -lt 0 ]; then
    msg "ko" "Invalid CIDR format: $CIDR"
    return 1
  fi

  if [ $(($ip % 2 ** (32 - $N) )) = 0 ]; then
    msg "ok" "Valid CIDR format: $CIDR"
    return 0 # CIDR OK!
  else
    msg "ko" "Invalid CIDR format: $CIDR"
    return 1 # CIDR NOT OK!
  fi
}

resolve_server_ip_from_CIDR() (
  IFS="./" read -r ip1 ip2 ip3 ip4 N <<<"$1" || exit 1
  ip4=$(($ip4 + 1)) || exit 1
  echo "$ip1.$ip2.$ip3.$ip4"
)

resolve_subnet_from_CIDR() (
  IFS="./" read -r ip1 ip2 ip3 ip4 N <<<"$1" || exit 1
  echo "$N"
)

function check_if_port_is_available() {
  portPid=$(ss -tunlp | grep ":$1\b" 2>&1) # make sure we redirect error messages
  if [ -z "$portPid" ]; then
    msg "ok" "Port available! $1"
    return 0
  else
    msg "ko" "******************************************************"
    msg "ko" "* Error: Port '$1' is being used or invalid value! *"
    msg "ko" "******************************************************"
    prompt_clean_old_installation_with_same_config || return 1
  fi
}

function check_if_network_interface_exitsts() {
  interfaces=$(ls /sys/class/net)
  for i in $interfaces; do
    if [ "$i" = "$1" ]; then
      msg "ko" "Interface '$1' already exists! Please specify another interface or remove the old one."
      prompt_clean_old_installation_with_same_config || return 1
    fi
  done
  return 0
}

# ------ print functions ------

function msg() {
  local GREEN="\\033[1;32m"
  local NORMAL="\\033[0;39m"
  local RED="\\033[1;31m"
  local PINK="\\033[1;35m"
  local BLUE="\\033[1;34m"
  local WHITE="\\033[0;02m"
  local YELLOW="\\033[1;33m"

  if [ "$1" == "ok" ]; then
    echo -e -n "$GREEN $2 $NORMAL"
  elif [ "$1" == "ko" ]; then
    echo -e -n "$RED $2 $NORMAL"
  elif [ "$1" == "warn" ]; then
    echo -e -n "$YELLOW $2 $NORMAL"
  elif [ "$1" == "info" ]; then
    echo -e -n "$BLUE $2 $NORMAL"
  else
    if [ -z "$2" ]; then
      echo -e -n "$NORMAL $1 $NORMAL"
    fi
  fi

  if [ -z $3 ]; then
    echo ""
  fi
}

function print_help() {
  echo "usage: ./setup.sh [args]"
  echo "-h  |--help                [print this help message]"
  echo "-s  |--silent|-q|--quiet   [the installation will not prompt for any input and will use the provided CLI/default values]"
  echo "-y  |--yes|--skipprompts   [the installation will not prompt for confirmations]"
  echo "-ui |--uionly              [if specified the insaller will only install and configure wireguard-ui based on the specified config file]"
  echo "-w  |--config|--configpath [the path where WireGuard config will be created ($DEFAULT_WIREGUARD_CONFIG_PATH)]"
  echo "-pki|--privatekey          [specifies an existing private instead of generating a new one.]"
  echo "-p  |--port|--wgport       [the port on which WireGuard will listen ($DEFAULT_WG_PORT)]"
  echo "-pbi|--publicinterface     [the interface with an internet connection ($DEFAULT_PUBLIC_INTERFACE)]"
  echo "-wgi|--wginterface         [the interface that will be created for WireGuard ($DEFAULT_WIREGUARD_INTERFACE)]"
  echo "-c  |--cidr                [the server interface address, the wg server will be assigned the first IP of the range, i.e: 10.8.0.1 unless --serverip is specified ($DEFAULT_CIDR)]"
  echo "-ip |--serverip            [The wg server will be assigned the first IP of the CIDR range, --server ip overrides this. (null)]" 
  echo "-o  |--online              [if specified, the script will download wireguard-ui from --wguilink, otherwise it will use the local build in the same dir]"
  echo "-lo |--local               [if specified, the script will use tge local wireguard-ui build included with this script]"
  echo "-u  |--wguilink |--wguiurl [link to the latest wgui release "
  echo "                            ($DEFAULT_WGUI_DOWNLOAD_LINK)]"
  echo "-pp |--webuiport|--uiport  [the port on which WireGuard UI will run ($DEFAULT_WG_WEB_UI_PORT)]"
  echo "-l  |--localonly           [ <1|0> if set to 1 the web ui can be accessed only from localhost (default: $DEFAULT_WGUI_LOCALHOST_ONLY)]"
  echo "-us |--username            [username of WireGuard-UI ($DEFAULT_WGUI_USERNAME)]"
  echo "-pw |--password            [password of WireGuard-UI ($DEFAULT_WGUI_PASSWORD)]"
  echo "-g  |--wguipath |--wguidir [the path where WireGuard-ui will be installed ($DEFAULT_WGUI_INTSTALLATION_PATH)]"
  echo "-b  |--wguibin             [path where the symbolic link for wgui will be made ($DEFAULT_WGUI_BIN_PATH)]"
  echo "-ctl|--systemctl           [path to systemctl ($DEFAULT_SYSTEMCTL_PATH)]"
}

function print_user_cli_value() {
  if [ -z "$2" ]; then
    msg "$1: $2"
  else
    msg "ok" "$1: $2"
  fi
}

function print_final_value() {
  if [ -z "$2" ]; then
    msg "ko" "$1: $2"
  else
    msg "$1: $2"
  fi
}

function print_final_config_values() {
  msg "info" "Final Values:"
  msg "info" "--WireGuard--"
  print_final_value "WIREGUARD_CONFIG_PATH" "$WIREGUARD_CONFIG_PATH"
  print_final_value "$EXISTING_PRIVATE_KEY" "$EXISTING_PRIVATE_KEY"
  print_final_value "PUBLIC_INTERFACE" "$PUBLIC_INTERFACE"
  print_final_value "WIREGUARD_INTERFACE" "$WIREGUARD_INTERFACE"
  print_final_value "CIDR" "$CIDR"
  print_final_value "ServerIP" "$ServerIP"
  print_final_value "Subnet" "$Subnet"
  print_final_value "WG_PORT" "$WG_PORT"
  print_final_value "PrivateKeyFile" "$PrivateKeyFile"
  print_final_value "PublicKeyFile" "$PublicKeyFile"
  print_final_value "ConfigFile" "$ConfigFile"
  msg "info" "--WGUI--"
  print_final_value "WGUI_DOWNLOAD_LINK" "$WGUI_DOWNLOAD_LINK"
  print_final_value "WGUI_INTSTALLATION_PATH" "$WGUI_INTSTALLATION_PATH"
  print_final_value "WGUI_BIN_PATH" "$WGUI_BIN_PATH"
  print_final_value "WG_WEB_UI_PORT" "$WG_WEB_UI_PORT"
  print_final_value "WGUI_LOCALHOST_ONLY" "$WGUI_LOCALHOST_ONLY"
  print_final_value "WG_WEB_UI_IP" "$WG_WEB_UI_IP"
  print_final_value "WGUI_USERNAME" "$WGUI_USERNAME"
  print_final_value "WGUI_PASSWORD" "$WGUI_PASSWORD"
  msg "info" "--Other--"
  print_user_cli_value "INSTALL_ONLY_WGUI" "$INSTALL_ONLY_WGUI"
  print_final_value "SYSTEMCTL_PATH" "$SYSTEMCTL_PATH"
}

function print_setup_done_message(){
    printf -v setup_complete_message "
##################################################################################
                                    Setup done.
[WireGuard-Interface]: $WIREGUARD_INTERFACE
[WireGuard-Config]: $ConfigFile
[WireGuard-UI URL]: $WG_WEB_UI_IP:$WG_WEB_UI_PORT
[WireGuard-UI accessible from localhost only]: $WGUI_LOCALHOST_ONLY
[WireGuard-UI Usernmae]: $WGUI_USERNAME
[WireGuard-UI Password]: $WGUI_PASSWORD

[WireGuard Service] -> $WG_SERVICE
$SYSTEMCTL_PATH enable $WG_SERVICE
$SYSTEMCTL_PATH disable $WG_SERVICE   
$SYSTEMCTL_PATH start $WG_SERVICE
$SYSTEMCTL_PATH stop $WG_SERVICE 

[WireGuard UI Service] -> $WGUI_SERVICE
$SYSTEMCTL_PATH enable $WGUI_SERVICE
$SYSTEMCTL_PATH disable $WGUI_SERVICE
$SYSTEMCTL_PATH start $WGUI_SERVICE
$SYSTEMCTL_PATH stop $WGUI_SERVICE

[WireGuard UI Config Change-Listener Service/Path] -> $WG_CHANGE_LISTENER_SERVICE 
$SYSTEMCTL_PATH enable $WG_CHANGE_LISTENER_SERVICE.{path,service}
$SYSTEMCTL_PATH disable $WG_CHANGE_LISTENER_SERVICE.{path,service}
$SYSTEMCTL_PATH start $WG_CHANGE_LISTENER_SERVICE.{path,service}
$SYSTEMCTL_PATH stop $WG_CHANGE_LISTENER_SERVICE.{path,service}

##################################################################################"

  msg "$setup_complete_message"
  rm -f $SETUP_INFO_FILE
  echo "$setup_complete_message" >>$SETUP_INFO_FILE
  msg "info" "You can find these details saved at $SETUP_INFO_FILE"
}

main "$@"
exit 0
