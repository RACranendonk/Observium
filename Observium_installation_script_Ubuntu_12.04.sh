#!/bin/bash

# Make sure only root can run script
if [[ $EUID -ne 0 ]]; then
	echo "Please execute this script as root."
	exit 1
fi

red='\e[0;31m'
green='\e[0;32m'
NC='\e[0m' # No Color

error_file="/var/log/observium_errors.log"
log_file="/var/log/observium_script.log"
observium_file_name="observium-community-latest.tar.gz"
url="http://www.observium.org/$observium_file_name"
date > $error_file
date > $log_file
errors="Error messages:"

function quit {
	echo -e "$errors\n" >> $error_file
	echo -e "\n${red}Fatal error encountered. Error messages saved to $error_file.${NC}"
	echo -e $errors 
	echo -e "${red}Exiting...${NC}"
	exit 1
}

clear
echo -e "========================================================="
echo -e "[\t${green}Observium installation script${NC}\t\t\t]"
echo -e "[\tCreated by Robert Cranendonk - March 2015\t]"
echo -e "[\tDesigned for Ubuntu 12.04 LTS\t\t\t]"
echo -e "[\t\t\t\t\t\t\t]"
echo -e "[\tThis program will install and configure\t\t]"
echo -e "[\tObservium on your system. Installation will\t]"
echo -e "[\ttake several minutes.\t\t\t\t]"
echo -e "[\tPlease save any work before proceeding.\t\t]"
echo -e "[\t\t\t\t\t\t\t]"
echo -e "[\t\t** DISCLAIMER **\t\t\t]"
echo -e "[\tThis software is provided \"as is\" without\t]"
echo -e "[\twarranty of any kind. Use at your own risk.\t]"
echo -e "[\t\t\t\t\t\t\t]"
echo -e "[\tLogs and error messages are saved in\t\t]"
echo -e "[\t/var/log/Observium_<errors/script>.log\t\t]"
echo -e "========================================================="
read -n1 -p 'Press any key to continue or Ctrl+C to exit...'

mysql_def_pw="MySQL_root_password"
observium_mysql_def_user="observium"
observium_mysql_def_pw="observium_MySQL_password"
observium_admin_def_pw="observium_admin_password"

# Update system
echo -en "${green}Updating system...${NC}"
apt-get install software-properties-common python-software-properties 2>> $error_file >> $log_file
add-apt-repository -y ppa:ondrej/php5 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Adding PHP5 repo failed."
	quit
fi

apt-get update 2>> $error_file >> $log_file
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" -y upgrade 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Upgrading failed."
	quit
fi
echo -e "\t\t\t\t\t${green}[OK]${NC}"

# Install necesarry packages for Observium
echo -en "${green}Installing Observium prerequisites...${NC}"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysql_def_pw"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysql_def_pw"
apt-get -y install libapache2-mod-php5 php5 php5-cli php5-mysql php5-gd php5-mcrypt php5-json php-pear snmp fping mysql-server mysql-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Installing packages failed."
	quit
fi
echo -e "\t\t\t${green}[OK]${NC}"

# Make directories for Observium
echo -en "${green}Creating directories for Observium in /opt...${NC}"
mkdir -p /opt/observium 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Creating directory /opt/observium failed."
	quit
fi
cd /opt
echo -e "\t\t${green}[OK]${NC}"

# Download latest observium
echo -e "${green}Downloading latest Observium version...${NC}"
wget --progress=dot $url 2>&1 | grep --line-buffered -o "[0-9]*%"|xargs -L1 echo -en "\r";echo -n

if [ ! -f $observium_file_name ]; then
	errors="$errors \n- At line $LINENO: Downloading Observium failed."
	quit
fi
echo -e "\r${green}[OK]  ${NC}"

# Unpack downloaded package
echo -en "${green}Unpacking...${NC}"
tar -zxvf observium-community-latest.tar.gz 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Unpacking failed."
	quit
fi

cd observium
echo -e "\t\t\t\t\t\t${green}[OK]${NC}"

# Initializing default config
echo -en "${green}Initializing default configuration...${NC}"
cp config.php.default config.php 2>> $error_file >> $log_file
sed -i "s/USERNAME/$observium_mysql_def_user/" /opt/observium/config.php 2>> $error_file >> $log_file
sed -i "s/PASSWORD/$observium_mysql_def_pw/" /opt/observium/config.php 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Initialization of config file failed."
	quit
fi
echo -e "\t\t\t${green}[OK]${NC}"

# Init the MySQL database
echo -en "${green}Initializing MySQL database and default schema...${NC}"
mysql -uroot -p$mysql_def_pw << EOF
CREATE DATABASE IF NOT EXISTS observium DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci; 
GRANT ALL PRIVILEGES ON observium.* TO '$observium_mysql_def_user'@'localhost' IDENTIFIED BY '$observium_mysql_def_pw';
EOF
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Initializing MySQL database failed."
	quit
fi

# Setup the default schema
php includes/update/update.php 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Creating default schema failed."
	quit
fi
echo -e "\t${green}[OK]${NC}"

# Create log and rrd folders
echo -en "${green}Creating logs and RRD folders for Observium...${NC}"
mkdir -p logs 2>> $error_file >> $log_file
mkdir -p rrd 2>> $error_file >> $log_file
chown www-data:www-data rrd 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Changing owner of RRD folder failed."
	quit
fi
echo -e "\t\t${green}[OK]${NC}"

# Config apache
echo -en "${green}Creating apache config...${NC}"
rm -f /etc/apache2/sites-available/default 2>> $error_file >> $log_file
cat > /etc/apache2/sites-available/default << EOF
<VirtualHost *:80>
       ServerAdmin webmaster@localhost
       DocumentRoot /opt/observium/html
       <Directory />
               Options FollowSymLinks
               AllowOverride None
       </Directory>
       <Directory /opt/observium/html/>
               Options Indexes FollowSymLinks MultiViews
               AllowOverride All
               Order allow,deny
               allow from all
       </Directory>
       ErrorLog  ${APACHE_LOG_DIR}/error.log
       LogLevel warn
       CustomLog  ${APACHE_LOG_DIR}/access.log combined
       ServerSignature On
</VirtualHost>
EOF
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Creating apache config failed."
	quit
fi
echo -e "\t\t\t\t${green}[OK]${NC}"

# Starting services
echo -en "${green}Starting services...${NC}"
php5enmod mcrypt 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Starting php5enmod mcrypt failed."
	quit
fi

a2enmod rewrite 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Rewriting a2enmod failed."
	quit
fi

apache2ctl restart 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Restarting apache2ctl failed."
	quit
fi
echo -e "\t\t\t\t\t${green}[OK]${NC}"

# Add user to observium
echo -en "${green}Adding admin user to Observium...${NC}"
./adduser.php admin $observium_admin_def_pw 10 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Adding admin user failed."
	quit
fi
echo -e "\t\t\t${green}[OK]${NC}"

# Create CRONjobs
echo -en "${green}Creating CRON jobs...${NC}"
cat > /etc/cron.d/observium << EOF
33  */6   * * *   root    /opt/observium/discovery.php -h all >> /dev/null 2>>&1
*/5 *     * * *   root    /opt/observium/discovery.php -h new >> /dev/null 2>>&1
*/5 *     * * *   root    /opt/observium/poller-wrapper.py 2 >> /dev/null 2>>&1
EOF
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Creating CRON jobs failed."
	quit
fi
echo -e "\t\t\t\t\t${green}[OK]${NC}"

# Run poller and discovery
echo -en "${green}Running initial discovery and poller...${NC}"
./discovery.php -h all 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Running discovery failed."
	quit
fi
./poller.php -h all 2>> $error_file >> $log_file
if [ $? -ne 0 ]; then
	errors="$errors \n- At line $LINENO: Running poller failed."
	quit
fi
echo -e "\t\t\t${green}[OK]${NC}"

echo -e "\nInstallation successful!\n"
echo -e "${red}Please change the following passwords ASAP:${NC}"
echo -e "MySQL Root login: root // $mysql_def_pw"
echo -e "Observium MySQL login: observium // $observium_mysql_def_pw"
echo -e "Observium webapp admin login: admin // $observium_admin_def_pw"
echo -e "Go to GitHub.com/RACranendonk/Observium for a how-to guide."
