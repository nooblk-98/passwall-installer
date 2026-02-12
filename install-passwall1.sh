#!/bin/sh

# Passwall 1 Installer
# Downloads IPK files directly from official GitHub releases

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   Passwall 1 Installer/Updater${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

# Get system information
. /etc/openwrt_release

echo -e "${YELLOW}System Information:${NC}"
echo " - Release: $DISTRIB_RELEASE"
echo " - Architecture: $DISTRIB_ARCH"
echo ""

# Check if Passwall 1 is already installed
INSTALLED=`ls /etc/init.d/passwall 2>/dev/null`

if [ "$INSTALLED" == "/etc/init.d/passwall" ]; then
    echo -e "${GREEN}Passwall 1 is currently installed${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Update Passwall 1"
    echo -e "${YELLOW}2.${NC} Reinstall Passwall 1 (Clean install)"
    echo -e "${YELLOW}3.${NC} Exit"
    echo ""
    printf "Select option: "
    read choice
else
    echo -e "${YELLOW}Passwall 1 is not installed${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Install Passwall 1"
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
        if [ "$INSTALLED" == "/etc/init.d/passwall" ]; then
            MODE="update"
            echo -e "${CYAN}Updating Passwall 1...${NC}"
        else
            MODE="install"
            echo -e "${CYAN}Installing Passwall 1...${NC}"
        fi
        ;;
    2)
        if [ "$INSTALLED" == "/etc/init.d/passwall" ]; then
            MODE="reinstall"
            echo -e "${CYAN}Reinstalling Passwall 1...${NC}"
            # Remove existing installation
            opkg remove luci-app-passwall --force-removal-of-dependent-packages
            opkg remove luci-i18n-passwall-zh-cn
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

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"

# Replace dnsmasq with dnsmasq-full if not already done
DNS_FULL=`opkg list-installed | grep dnsmasq-full`
if [ -z "$DNS_FULL" ]; then
    echo "Installing dnsmasq-full..."
    opkg remove dnsmasq
    opkg install dnsmasq-full
fi

# Install required packages
PACKAGES="unzip wget-ssl curl ipset iptables iptables-mod-tproxy iptables-mod-socket \
iptables-mod-iprange iptables-mod-conntrack-extra kmod-ipt-nat ca-bundle"

for pkg in $PACKAGES; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        echo "Installing $pkg..."
        opkg install $pkg 2>/dev/null || echo "  Warning: $pkg not available"
    fi
done

# Ensure unzip is installed (critical for extracting packages)
if ! which unzip >/dev/null 2>&1; then
    echo -e "${RED}Error: unzip is required but not installed!${NC}"
    opkg install unzip || exit 1
fi

# Get architecture for downloads
read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

# Set GitHub release URLs (official Openwrt-Passwall/openwrt-passwall repository)
GITHUB_PW="https://github.com/Openwrt-Passwall/openwrt-passwall/releases/latest/download"

# Create temporary directory
TMP_DIR="/tmp/passwall_install"
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
cd $TMP_DIR

echo -e "${YELLOW}Downloading Passwall 1 from GitHub releases...${NC}"

# Download luci-app-passwall (standalone file)
echo "Downloading luci-app-passwall..."
wget --no-check-certificate -O luci-app-passwall.ipk "${GITHUB_PW}/luci-app-passwall_git-24.365.74654-a130463_all.ipk" 2>/dev/null

if [ ! -s "luci-app-passwall.ipk" ]; then
    # Try to find the latest version via listing page
    echo "Trying alternative download method..."
    LATEST_URL=$(wget -qO- --no-check-certificate "https://github.com/Openwrt-Passwall/openwrt-passwall/releases/latest" | grep -o 'href="[^"]*luci-app-passwall[^"]*_all.ipk"' | head -n1 | sed 's/href="//;s/"//' | sed 's|^|https://github.com|')
    if [ -n "$LATEST_URL" ]; then
        wget --no-check-certificate -O luci-app-passwall.ipk "$LATEST_URL"
    fi
fi

# Download passwall packages zip for architecture
echo "Downloading core packages zip for ${arch}..."
ZIP_FILE="passwall_packages_ipk_${arch}.zip"
wget --no-check-certificate -O packages.zip "${GITHUB_PW}/${ZIP_FILE}" 2>/dev/null

if [ ! -s "packages.zip" ]; then
    echo "Direct download failed, trying alternative..."
    ZIP_URL=$(wget -qO- --no-check-certificate "https://github.com/Openwrt-Passwall/openwrt-passwall/releases/latest" | grep -o "href=\"[^\"]*passwall_packages_ipk_${arch}.zip\"" | head -n1 | sed 's/href="//;s/"//' | sed 's|^|https://github.com|')
    if [ -n "$ZIP_URL" ]; then
        wget --no-check-certificate -O packages.zip "$ZIP_URL"
    fi
fi

if [ -f "packages.zip" ] && [ -s "packages.zip" ]; then
    echo "Extracting packages..."
    unzip -q -o packages.zip
else
    echo -e "${YELLOW}Warning: Could not download packages zip${NC}"
    echo -e "${YELLOW}Will try to install core packages from opkg...${NC}"
fi

# Install downloaded packages
echo -e "${YELLOW}Installing Passwall 1 packages...${NC}"

# Find and install all ipk files
IPK_COUNT=0
find . -name "*.ipk" -type f | while read ipk; do
    if [ -f "$ipk" ] && [ -s "$ipk" ]; then
        echo "Installing $(basename $ipk)..."
        opkg install "$ipk" --force-reinstall --force-overwrite 2>/dev/null
        IPK_COUNT=$((IPK_COUNT + 1))
    fi
done

# If no packages were extracted from zip, install cores from opkg
if [ $IPK_COUNT -lt 5 ]; then
    echo -e "${YELLOW}Installing core packages from opkg...${NC}"
    opkg update
    opkg install xray-core 2>/dev/null || echo "  xray-core not available"
    opkg install sing-box 2>/dev/null || echo "  sing-box not available" 
    opkg install v2ray-core 2>/dev/null || echo "  v2ray-core not available"
    opkg install hysteria 2>/dev/null || echo "  hysteria not available"
fi

# Cleanup
cd /
rm -rf $TMP_DIR

# Verify installation
if [ -f "/etc/init.d/passwall" ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Passwall 1 installed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Enable and start service
    /etc/init.d/passwall enable
    
    # Configure basic settings
    uci set passwall.@global[0].tcp_proxy_mode='proxy' 2>/dev/null
    uci set passwall.@global[0].udp_proxy_mode='proxy' 2>/dev/null
    uci set passwall.@global[0].dns_mode='udp' 2>/dev/null
    uci set passwall.@global[0].remote_dns='8.8.8.8' 2>/dev/null
    uci commit passwall 2>/dev/null
    
    echo -e "${CYAN}Access Passwall at:${NC} Services -> Passwall"
    echo ""
    
    if [ "$MODE" != "update" ]; then
        echo -e "${YELLOW}Reloading configuration...${NC}"
        /etc/init.d/passwall restart
    fi
else
    echo ""
    echo -e "${RED}Installation failed!${NC}"
    echo -e "${YELLOW}Trying alternative installation from opkg feeds...${NC}"
    opkg update
    opkg install luci-app-passwall
    
    if [ -f "/etc/init.d/passwall" ]; then
        echo -e "${GREEN}Passwall 1 installed from opkg feeds!${NC}"
        /etc/init.d/passwall enable
    else
        echo -e "${RED}Installation failed from all sources.${NC}"
        echo -e "${RED}Please check your internet connection and try again.${NC}"
        exit 1
    fi
fi

echo -e "${CYAN}Done!${NC}"
