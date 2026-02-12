#!/bin/sh

# Passwall 2 Installer
# Downloads IPK files directly from official GitHub releases

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   Passwall 2 Installer/Updater${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

# Get system information
. /etc/openwrt_release

echo -e "${YELLOW}System Information:${NC}"
echo " - Release: $DISTRIB_RELEASE"
echo " - Architecture: $DISTRIB_ARCH"
echo ""

# Check RAM requirement
TOTAL_RAM=$(free | grep Mem | awk '{print $2}')
if [ $TOTAL_RAM -lt 250000 ]; then
    echo -e "${RED}WARNING: Passwall 2 requires at least 256MB RAM${NC}"
    echo -e "${YELLOW}Your system has less RAM. Installation may fail.${NC}"
    printf "Continue anyway? (y/n): "
    read confirm
    if [ "$confirm" != "y" ]; then
        exit 0
    fi
fi

# Check if Passwall 2 is already installed
INSTALLED=`ls /etc/init.d/passwall2 2>/dev/null`

if [ "$INSTALLED" == "/etc/init.d/passwall2" ]; then
    echo -e "${GREEN}Passwall 2 is currently installed${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Update Passwall 2"
    echo -e "${YELLOW}2.${NC} Reinstall Passwall 2 (Clean install)"
    echo -e "${YELLOW}3.${NC} Exit"
    echo ""
    printf "Select option: "
    read choice
else
    echo -e "${YELLOW}Passwall 2 is not installed${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Install Passwall 2"
    echo -e "${YELLOW}2.${NC} Exit"
    echo ""
    printf "Select option: "
    read choice
    
    if [ "$choice" == "2" ]; then
        exit 0
    fi
    choice=1
fi

case $choice in
    1)
        if [ "$INSTALLED" == "/etc/init.d/passwall2" ]; then
            MODE="update"
            echo -e "${CYAN}Updating Passwall 2...${NC}"
        else
            MODE="install"
            echo -e "${CYAN}Installing Passwall 2...${NC}"
        fi
        ;;
    2)
        if [ "$INSTALLED" == "/etc/init.d/passwall2" ]; then
            MODE="reinstall"
            echo -e "${CYAN}Reinstalling Passwall 2...${NC}"
            # Remove existing installation
            opkg remove luci-app-passwall2 --force-removal-of-dependent-packages
            opkg remove luci-i18n-passwall2-zh-cn
        else
            exit 0
        fi
        ;;
    3)
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Update package lists
echo -e "${YELLOW}Updating package lists...${NC}"
opkg update

# Add Passwall feeds from SourceForge
echo -e "${YELLOW}Configuring Passwall feeds...${NC}"

# Download and add GPG key
wget --no-check-certificate -O /tmp/passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub 2>/dev/null
if [ -f "/tmp/passwall.pub" ]; then
    opkg-key add /tmp/passwall.pub
    rm -f /tmp/passwall.pub
fi

# Backup existing custom feeds (keep OpenWrt official feeds)
if [ -f "/etc/opkg/customfeeds.conf" ]; then
    cp /etc/opkg/customfeeds.conf /etc/opkg/customfeeds.conf.backup
fi

# Add SourceForge feeds to custom feeds (OpenWrt official feeds remain active)
>/etc/opkg/customfeeds.conf

read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

# Add SourceForge Passwall feeds - these will take priority
for feed in passwall_luci passwall_packages passwall2; do
  echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

echo -e "${GREEN}SourceForge feeds configured (OpenWrt official feeds remain active)${NC}"
echo -e "${CYAN}Release: $release, Architecture: $arch${NC}"

# Update package lists
opkg update

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"

# Replace dnsmasq with dnsmasq-full if not already done
DNS_FULL=`opkg list-installed | grep dnsmasq-full`
if [ -z "$DNS_FULL" ]; then
    echo "Installing dnsmasq-full..."
    opkg remove dnsmasq
    opkg install dnsmasq-full
fi

# Install required packages for Passwall 2
PACKAGES="unzip wget-ssl curl ca-bundle kmod-nft-socket kmod-nft-tproxy \
kmod-inet-diag kmod-netlink-diag kmod-tun ipset"

for pkg in $PACKAGES; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        echo "Installing $pkg..."
        opkg install $pkg 2>/dev/null || echo "  Warning: $pkg not available"
    fi
done

# Get architecture for downloads
read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

echo -e "${CYAN}System: OpenWrt $release, Architecture: $arch${NC}"
echo ""

# Install Passwall 2 and all dependencies from feeds
echo -e "${YELLOW}Installing Passwall 2 from feeds...${NC}"

opkg install luci-app-passwall2

# Verify installation
if [ -f "/etc/init.d/passwall2" ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Passwall 2 installed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Restore previous custom feeds if existed
    if [ -f "/etc/opkg/customfeeds.conf.backup" ]; then
        echo -e "${YELLOW}Restoring previous custom feeds...${NC}"
        mv /etc/opkg/customfeeds.conf.backup /etc/opkg/customfeeds.conf
        opkg update
    fi
    
    # Enable and start service
    /etc/init.d/passwall2 enable
    
    # Configure basic settings
    uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535' 2>/dev/null
    uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535' 2>/dev/null
    uci set passwall2.@global[0].remote_dns='8.8.8.8' 2>/dev/null
    
    # Configure Iran IP bypass (if desired)
    uci set passwall2.Direct=shunt_rules 2>/dev/null
    uci set passwall2.Direct.network='tcp,udp' 2>/dev/null
    uci set passwall2.Direct.remarks='Direct' 2>/dev/null
    uci set passwall2.Direct.ip_list='geoip:private' 2>/dev/null
    
    uci commit passwall2 2>/dev/null
    
    echo -e "${CYAN}Access Passwall 2 at:${NC} Services -> Passwall 2"
    echo ""
    
    if [ "$MODE" != "update" ]; then
        echo -e "${YELLOW}Reloading configuration...${NC}"
        /etc/init.d/passwall2 restart
    fi
else
    echo ""
    echo -e "${RED}Installation failed!${NC}"
    
    # Restore previous custom feeds if existed
    if [ -f "/etc/opkg/customfeeds.conf.backup" ]; then
        mv /etc/opkg/customfeeds.conf.backup /etc/opkg/customfeeds.conf
    fi
    
    echo -e "${YELLOW}Trying alternative installation from opkg feeds...${NC}"
    opkg update
    opkg install luci-app-passwall2
    
    if [ -f "/etc/init.d/passwall2" ]; then
        echo -e "${GREEN}Passwall 2 installed from opkg feeds!${NC}"
        /etc/init.d/passwall2 enable
    else
        echo -e "${RED}Installation failed from all sources.${NC}"
        echo -e "${RED}Please check your internet connection and try again.${NC}"
        exit 1
    fi
fi

echo -e "${CYAN}Done!${NC}"
