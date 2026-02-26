#!/bin/bash

#===============================================================
# Filename: Basic_IPTables_Firewall_Setup.sh			|
# Assignment Info: Assignment 1 - A Basic iptables Firewall	|
# Author: Loki (Matthew Van Leer)				|
# Creation Date: 01/12/26					|
# Last Modified: 01/16/26					|
#===============================================================

#Variables and Constants:
server1=192.168.4.2
techsupport1=192.168.4.5
updateserver=192.168.4.7
ruleset_dest="/home/$SUDO_USER/firewall_ruleset_logs/"
package="iptables-persistent"
trap 'echo -e "\nProcess aborted. Check iptable rules to ensure additional rules are not present."; exit 0' SIGINT	# Warns user after interupting the process using
															# 	SIGINT (Ctrl+C) that it may leave behind iptable rules.
#-------------------------------------------------------------
# Check the user has root privileges needed to run the script:
#-------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then	#Checks if the Effective User ID is 0 (root). If not equal (-ne) then notifies user and ends process.
	echo "This Script requires root permissions. Please run as root or use sudo."
	exit 0
fi 

#--------------------------------------------------------------------------------------------------------------------------------
# Check if iptables-persistent package is installed. Used for saving iptables rules on shutdown and auto loading them on startup:
#--------------------------------------------------------------------------------------------------------------------------------
if dpkg -l | grep -qw $package; then										# -l is to list packages, -q signals to run in quiet mode which exits
														# 	with a 0 or non zero status, -w needs results to match the whole query.
	echo -e "${package} is installed. Proceeding...\n"
else
	read -r -p "${package} is not installed. Would you like to install the package now (Y/N)?" choice	# -r is for raw input, -p is to  display the prompt string before input.
	case "$choice" in
		[Yy]* ) echo -e "\nBeginning package installation...";;
		* ) echo -e "\nProcess Aborted."; exit 0;;
	esac

	#-------------------------------------------------------------------------------------------------------------------
	# Add temporary rules to ensure apt install is able to grab the package, regardless of current iptable rules/policy.
	#-------------------------------------------------------------------------------------------------------------------
	iptables -A INPUT -p tcp -m multiport --sport 53,80,443 -j ACCEPT | iptables -A INPUT -p udp --sport 53 -j ACCEPT | iptables -A INPUT -i lo -j ACCEPT
	iptables -A OUTPUT -p tcp -m multiport --dport 53,80,443 -j ACCEPT | iptables -A OUTPUT -p udp --dport 53 -j ACCEPT | iptables -A OUTPUT -o lo -j ACCEPT
	apt install $package -y

	#-----------------------------------------------------------------------------------------------------------------
	# Removes the temporary rules after package installation. Ensures rules are removed even if next step is aborted.
	#-----------------------------------------------------------------------------------------------------------------
	iptables -D INPUT -p tcp -m multiport --sport 53,80,443 -j ACCEPT | iptables -D INPUT -p udp --sport 53 -j ACCEPT | iptables -D INPUT -i lo -j ACCEPT
	iptables -D OUTPUT -p tcp -m multiport --dport 53,80,443 -j ACCEPT | iptables -D OUTPUT -p udp --dport 53 -j ACCEPT | iptables -D OUTPUT -o lo -j ACCEPT
	echo -e "\nInstallation complete. Proceeding...\n"
fi

#---------------------------------------------------------------------------------------------------------
# User confirmation prompted prior to making changes as this will affect machine security configurations:
#---------------------------------------------------------------------------------------------------------
read -r -p "You are about to flush and reconfigure your iptables. Are you sure you wish to proceed (Y/N)?" choice	#-r is for raw input, -p is to  display the prompt string before input.
case "$choice" in
	[Yy]* ) echo -e "\nBeginning iptables configuration...";;
	* ) echo -e "\nProcess Aborted."; exit 0;;
esac

#-----------------------------------------------------------------------------------------------------------------------------
# Set default policy to DROP. This will close any ongoing connections after the flush before security reconfiguration begins:
#-----------------------------------------------------------------------------------------------------------------------------
echo "Setting default policy as DROP..."
iptables -P INPUT DROP | iptables -P FORWARD DROP | iptables -P OUTPUT DROP
echo -e  "Policy change successful!\n"

#--------------------------------------------------
# Flush all existing iptable rules from all tables:
#--------------------------------------------------
echo "Flushing iptables..."
iptables -F | iptables -X				# Flush all rules from the filter table. -X also ensures any user defined chains are also flushed.
iptables -t nat -F | iptables -t nat -X 		# Flush nat table. -X also ensures any user defined chains are also flushed from the table.
iptables -t mangle -F | iptables -t mangle -X		# Flush mangle table. -X also ensures any user defined chains are also flushed from the table.
iptables -t raw -F | iptables -t raw -X 		# Flush raw table. -X also ensures any user defined chains are also flushed from the table.
iptables -t security -F | iptables -t security -X 	# Flush the security table often used in SELinux. -X also ensures any user defined chains are also flushed.
echo -e "iptables flush successful!\n"

#--------------------------------------------
# Output initial firewall rules, post flush:
#--------------------------------------------
echo -e "Initial firewall ruleset:\n" 
initial_ruleset="$(iptables -L -v; echo ""; iptables-save)"		# iptables-save should show any rules from all tables which can be used to confirm a total rule flush.
echo "${initial_ruleset}"
echo -e "\nCreating initial firewall ruleset log...\n"
mkdir -p "${ruleset_dest}"						# Creates a folder to hold the files if it doesnt already exist. Does nothing and moves on quietly
									# 	if the directory already exists by using -p option.
echo "${initial_ruleset}" > ${ruleset_dest}/initialstate.log		# This will create a file containing the initial ruleset from after the flush.
echo -e "Initial ruleset file created at ${ruleset_dest}\n"

#--------------------------------------------------------------------------------
# Add modules to session for dynamic data port support:
#--------------------------------------------------------------------------------
echo "Beginning firewall rule configuration..."
#Add modules to session for dynamic data ports:
echo "Loading necessary FTP modules..."
modprobe nf_conntrack_ftp
modprobe nf_nat_ftp		#In case of NAT connection.

#---------------------------------------------------------------------------------------------------
# Checks to see if the neccecary configuration files are in place to allow modules to load on boot:
#---------------------------------------------------------------------------------------------------
if [ -f "/etc/modules-load.d/ftp.conf" ]; then
	echo "Modules saved to load at boot!"
else
	echo "Modules being saved to load at boot..."
	echo "nf_conntrack_ftp" | tee /etc/modules-load.d/ftp.conf
	echo "nf_nat_ftp" | tee -a /etc/modules-load.d/ftp.conf
fi

#-------------------------------
# Configure new firewall rules:
#-------------------------------
iptables -A INPUT -i lo -j ACCEPT | iptables -A OUTPUT -o lo -j ACCEPT			# Loopback configuration to allow inbound and outbound traffic. -A appends the rule to the given chain.
											# 	-i signifies input interface. -o is output interface. -j Jumps to a target, such as ACCEPT or DROP.
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT			# Stateful firewall setup allowing inbound traffic for ESTABLISHED and RELATED connections,
											# 	and allowing outbound traffic for ESTABLISHED and NEW connections. -m implements a module,
											# 	in this case the connection tracking module conntrack. --ctstate matches packets based on the parameters given.
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,NEW -j ACCEPT
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP				# Drops invalid packets that cannot be verified and could be malicious. Can also lower load on the firewall.
iptables -A INPUT -p tcp -s $techsupport1 --dport 22 -j ACCEPT				# Allow incoming SSH from techsupport1 IP address. -p specifies the protocol, -s specifies the source,
											#	--dport specifies the destination port.
iptables -A OUTPUT -p tcp -d $server1 -m multiport --sport 20,21,22,990 -j ACCEPT	# Allow outgoing FTP traffic to server1 IP address(Added SFTP and FTPS ports as well).
iptables -A INPUT -p tcp -s $updateserver -m multiport --dport 20,21,22,990 -j ACCEPT	# Allow incoming FTP traffic from updateserver IP address(Added SFTP and FTPS ports as well).
sudo iptables -t raw -A PREROUTING -p tcp --dport 21 -j CT --helper ftp			# Allow passive FTP by assigning helper module.
echo -e "Firewall rule configuration complete!\n"

#-------------------------
# Set new default policy:
#-------------------------
echo "Configuring new default policy..."
iptables -P INPUT DROP | iptables -P FORWARD DROP | iptables -P OUTPUT ACCEPT
echo -e "New default policy configured!\n"

#--------------------------
# Save new firewall rules:
#--------------------------
echo "Saving firewall rules..."
netfilter-persistent save	# Saves the rules to the netfilter service which is used to flush, save, and load iptable rules on system boot. Save location is /etc/iptables/rules.v4.
echo -e "Save complete!\n"

#-----------------------------
# Display new firewall rules:
#-----------------------------
echo -e "Configured firewall ruleset:\n"
config_ruleset="$(iptables -L -v; echo ""; iptables-save)"	# iptables-save included for a more comprehensive log as it shows all rules including other tables.
echo "${config_ruleset}"
echo -e "\nCreating configured firewall ruleset log..."
echo "${config_ruleset}" > ${ruleset_dest}/configuredstate.log
echo "Configured ruleset file created at ${ruleset_dest}"
echo -e "\nPROCESS COMPLETE!\n"
