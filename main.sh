#!/bin/bash

source ./vars/main.txt

zimbra_domain=$(echo "${zimbra_fqdn}" | awk -F'.' '{print $2,".",$3}')

set_time() {
    if ! which lsb_release >/dev/null 2>&1; then
        if ! rpm -q chrony; then
            yum install -y chrony
            systemctl --now enable chronyd
            timedatectl set-timezone "${zimbra_timezone}"
            timedatectl set-ntp true
            systemctl restart chronyd
        else
            timedatectl set-timezone "${zimbra_timezone}"
            timedatectl set-ntp true
            systemctl restart chronyd
        fi
    else
        timedatectl set-timezone "${zimbra_timezone}"
        systemctl --now disable systemd-timesyncd
        systemctl mask systemd-timesyncd
        apt-get install -y chrony
    fi
}

set_hostname() {
    zimbra_shortname=$(echo "${zimbra_fqdn}" | awk -F'.' '{print $1}')
    hostnamectl set-hostname "${zimbra_fqdn}"
    if ! which lsb_release >/dev/null 2>&1; then
        printf '%s\n' "${zimbra_ip} ${zimbra_fqdn} ${zimbra_shortname}" | tee -a /etc/hosts
    else
        {
        printf '%s\n' "127.0.0.1 localhost.localdomain localhost"
        printf '%s\n' "${zimbra_ip} ${zimbra_fqdn} ${zimbra_shortname}"
        } > /etc/hosts
    fi
}

install_packages() {
    if ! which lsb_release >/dev/null 2>&1; then
        yum install -y bash-completion tmux telnet bind-utils tcpdump wget lsof rsync tar nmap-ncat
        yum update -y
    else
        apt-get install -y bash-completion tmux telnet dnsutils tcpdump wget lsof rsync
        apt-get -y dist-upgrade
    fi
}

open_ports() {
    if ! which lsb_release >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port={25,465,587,110,995,143,993,80,443,7071}/tcp
        firewall-cmd --reload
    else
        ufw disable
        systemctl --now disable ufw
        systemctl mask ufw
        apt-get install -y firewalld
        firewall-cmd --permanent --add-port={25,465,587,110,995,143,993,80,443,7071}/tcp
        firewall-cmd --reload
    fi
}

disable_postfix() {
    if systemctl status postfix; then
        systemctl --now disable postfix
        systemctl mask postfix
    fi
}

install_dnsmasq() {
    if ! which lsb_release >/dev/null 2>&1; then
        yum install -y dnsmasq
    else
        systemctl --now disable systemd-resolved
        systemctl mask systemd-resolved
        rm -f /etc/resolv.conf
        {
        printf '%s\n' "search ${zimbra_domain// /}"
        printf '%s\n' "nameserver 8.8.8.8"
        printf '%s\n' "nameserver 8.8.4.4"
        } > /etc/resolv.conf
        apt-get install -y dnsmasq
    fi
    mv /etc/dnsmasq.conf /etc/dnsmasq.conf."$(date +%F)".bak
    cat << EOF > /etc/dnsmasq.conf
server=8.8.8.8
server=8.8.4.4

listen-address=127.0.0.1,${zimbra_ip}

domain=${zimbra_domain// /}

mx-host=${zimbra_domain// /},${zimbra_fqdn},1

addn-hosts=/etc/hosts

cache-size=9500
EOF

    if ! which lsb_release >/dev/null 2>&1; then
        chown root.dnsmasq /etc/dnsmasq.conf
        chmod 644 /etc/dnsmasq.conf
        systemctl --now enable dnsmasq
    else
        systemctl restart dnsmasq
    fi
}

set_loopback_dns() {
    if ! which lsb_release >/dev/null 2>&1; then
        nmcli con mod "${zimbra_network_name}" ipv4.method manual ipv4.addresses "${zimbra_ip}${zimbra_prefix}" ipv4.gateway "${zimbra_gateway}"
        nmcli con mod "${zimbra_network_name}" ipv4.dns 127.0.0.1
        nmcli con reload
        nmcli con up "${zimbra_network_name}"
    else
        {
        printf '%s\n' "search ${zimbra_domain// /}"
        printf '%s\n' "nameserver 127.0.0.1"
        } > /etc/resolv.conf
    fi
}

prepare_zimbra() {
    if ! which lsb_release >/dev/null 2>&1; then
        zimbra_installer_file=$(echo "${zimbra_installer_url}" | awk -F'/' '{print $6}')
        yum install -y perl net-tools
        wget -P ./files "${zimbra_installer_url}"
        tar xvf ./files/"${zimbra_installer_file}" -C ./files/
        cd ./files/"${zimbra_installer_file%.tgz}" || exit 1
    else
        zimbra_installer_file_ubuntu=$(echo "${zimbra_installer_url_ubuntu}" | awk -F'/' '{print $6}')
        apt-get install -y perl net-tools
        wget -P ./files "${zimbra_installer_url_ubuntu}"
        tar xvf ./files/"${zimbra_installer_file_ubuntu}" -C ./files/
        cd ./files/"${zimbra_installer_file_ubuntu%.tgz}" || exit 1
    fi
}

prepare_zimbra9() {
    if ! which lsb_release >/dev/null 2>&1; then
        zimbra9_installer_file=$(echo "${zimbra9_installer_url}" | awk -F'/' '{print $4}')
        yum install -y perl net-tools
        wget -P ./files "${zimbra9_installer_url}"
        tar xvf ./files/"${zimbra9_installer_file}" -C ./files/
        cd ./files/zimbra-installer || exit 1
    else
        zimbra9_installer_file_ubuntu=$(echo "${zimbra9_installer_url_ubuntu}" | awk -F'/' '{print $4}')
        apt-get install -y perl net-tools
        wget -P ./files "${zimbra9_installer_url_ubuntu}"
        tar xvf ./files/"${zimbra9_installer_file_ubuntu}" -C ./files/
        cd ./files/zimbra-installer || exit 1
    fi
}

phase1_install() {
    cat << EOF > ../zimbra_answers.txt
y
y
y
y
y
n
y
y
y
y
y
y
n
n
n
y
EOF

    ./install.sh -s < ../zimbra_answers.txt
}

phase2_install() {
    zimbra_system_password="$(date | md5sum | cut -c 1-14)"
    sleep 3
    zimbra_random_chars="$(date | md5sum | cut -c 1-9)"
    zimbra_mailboxd_memory="$(free -m | awk 'NR==2{printf "%.0f\n", $2*0.25 }')"
    zimbra_system_memory="$(free -h | awk 'NR==2{printf "%.0f\n", $2 }')"

    cat << EOF > ../zimbra_config.txt
AVDOMAIN="${zimbra_domain// /}"
AVUSER="admin@${zimbra_domain// /}"
CREATEADMIN="admin@${zimbra_domain// /}"
CREATEADMINPASS="${zimbra_admin_password}"
CREATEDOMAIN="${zimbra_domain// /}"
DOCREATEADMIN="yes"
DOCREATEDOMAIN="yes"
DOTRAINSA="yes"
EXPANDMENU="no"
HOSTNAME="${zimbra_fqdn}"
HTTPPORT="8080"
HTTPPROXY="TRUE"
HTTPPROXYPORT="80"
HTTPSPORT="8443"
HTTPSPROXYPORT="443"
IMAPPORT="7143"
IMAPPROXYPORT="143"
IMAPSSLPORT="7993"
IMAPSSLPROXYPORT="993"
INSTALL_WEBAPPS="service zimlet zimbra zimbraAdmin"
JAVAHOME="/opt/zimbra/common/lib/jvm/java"
LDAPBESSEARCHSET="set"
LDAPHOST="${zimbra_fqdn}"
LDAPPORT="389"
LDAPREPLICATIONTYPE="master"
LDAPSERVERID="2"
MAILBOXDMEMORY="${zimbra_mailboxd_memory}"
MAILPROXY="TRUE"
MODE="https"
MYSQLMEMORYPERCENT="30"
POPPORT="7110"
POPPROXYPORT="110"
POPSSLPORT="7995"
POPSSLPROXYPORT="995"
PROXYMODE="https"
REMOVE="no"
RUNARCHIVING="no"
RUNAV="yes"
RUNCBPOLICYD="no"
RUNDKIM="yes"
RUNSA="yes"
RUNVMHA="no"
SERVICEWEBAPP="yes"
SMTPDEST="admin@${zimbra_domain// /}"
SMTPHOST="${zimbra_fqdn}"
SMTPNOTIFY="yes"
SMTPSOURCE="admin@${zimbra_domain// /}"
SNMPNOTIFY="yes"
SNMPTRAPHOST="${zimbra_fqdn}"
SPELLURL="http://${zimbra_fqdn}:7780/aspell.php"
STARTSERVERS="yes"
STRICTSERVERNAMEENABLED="TRUE"
SYSTEMMEMORY="${zimbra_system_memory}"
TRAINSAHAM="ham.${zimbra_random_chars}@${zimbra_domain// /}"
TRAINSASPAM="spam.${zimbra_random_chars}@${zimbra_domain// /}"
UIWEBAPPS="yes"
UPGRADE="yes"
USEEPHEMERALSTORE="no"
USESPELL="yes"
VERSIONUPDATECHECKS="TRUE"
VIRUSQUARANTINE="virus-quarantine.${zimbra_random_chars}@${zimbra_domain// /}"
ZIMBRA_REQ_SECURITY="yes"
ldap_bes_searcher_password="${zimbra_system_password}"
ldap_dit_base_dn_config="cn=zimbra"
LDAPROOTPASS="${zimbra_system_password}"
LDAPADMINPASS="${zimbra_system_password}"
LDAPPOSTPASS="${zimbra_system_password}"
LDAPREPPASS="${zimbra_system_password}"
LDAPAMAVISPASS="${zimbra_system_password}"
ldap_nginx_password="${zimbra_system_password}"
mailboxd_directory="/opt/zimbra/mailboxd"
mailboxd_keystore="/opt/zimbra/mailboxd/etc/keystore"
mailboxd_keystore_password="${zimbra_system_password}"
mailboxd_server="jetty"
mailboxd_truststore="/opt/zimbra/common/lib/jvm/java/lib/security/cacerts"
mailboxd_truststore_password="changeit"
postfix_mail_owner="postfix"
postfix_setgid_group="postdrop"
ssl_default_digest="sha256"
zimbraFeatureBriefcasesEnabled="Enabled"
zimbraFeatureTasksEnabled="Enabled"
zimbraIPMode="ipv4"
zimbraMailProxy="TRUE"
zimbraMtaMyNetworks="127.0.0.0/8 [::1]/128 ${zimbra_subnet}"
zimbraPrefTimeZoneId="${zimbra_timezone}"
zimbraReverseProxyLookupTarget="TRUE"
zimbraVersionCheckNotificationEmail="admin@${zimbra_domain// /}"
zimbraVersionCheckNotificationEmailFrom="admin@${zimbra_domain// /}"
zimbraVersionCheckSendNotifications="TRUE"
zimbraWebProxy="TRUE"
zimbra_ldap_userdn="uid=zimbra,cn=admins,cn=zimbra"
zimbra_require_interprocess_security="1"
INSTALL_PACKAGES="zimbra-core zimbra-ldap zimbra-logger zimbra-mta zimbra-snmp zimbra-store zimbra-apache zimbra-spell zimbra-memcached zimbra-proxy "
EOF

    /opt/zimbra/libexec/zmsetup.pl -c ../zimbra_config.txt
}

set_trusted_ip() {
    su - zimbra -c "zmprov mcf +zimbraMailTrustedIP 127.0.0.1 +zimbraMailTrustedIP ${zimbra_ip}"
    su - zimbra -c "zmcontrol restart"
}

install_fail2ban() {
    if ! which lsb_release >/dev/null 2>&1; then
        yum install -y epel-release
        yum install -y fail2ban
    else
        apt-get install -y fail2ban
    fi
    cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8 ${zimbra_ip}/32
EOF

    cat << EOF > /etc/fail2ban/jail.d/zimbra.local
[zimbra-smtp]
enabled = true
filter = zimbra-smtp
port = 25,465,587
logpath = /var/log/zimbra.log
maxretry = 3
findtime = 600
bantime = 3600

[zimbra-webmail]
enabled = true
filter = zimbra-webmail
port = 80,443
logpath = /opt/zimbra/log/mailbox.log
maxretry = 3
findtime = 600
bantime = 3600

[zimbra-admin]
enabled = true
filter = zimbra-admin
port = 7071,9071
logpath = /opt/zimbra/log/mailbox.log
maxretry = 3
findtime = 600
bantime = 3600
EOF

    cat << EOF > /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
port = 22
maxretry = 3
findtime = 600
bantime = 3600
EOF

    cat << EOF > /etc/fail2ban/filter.d/zimbra-webmail.conf
[Definition]
#
failregex = \[oip=<HOST>;.* SoapEngine - handler exception: authentication failed for .*, account not found$
            INFO .*;oip=<HOST>;.* SoapEngine - handler exception: authentication failed for .*, invalid password$

ignoreregex =
EOF

    cat << EOF > /etc/fail2ban/filter.d/zimbra-smtp.conf
[Definition]
#
failregex = postfix\/submission\/smtpd\[\d+\]: warning: .*\[<HOST>\]: SASL \w+ authentication failed: authentication failure$
            postfix\/smtps\/smtpd\[\d+\]: warning: .*\[<HOST>\]: SASL \w+ authentication failed: authentication failure$

ignoreregex =
EOF

    cat << EOF > /etc/fail2ban/filter.d/zimbra-admin.conf
[Definition]
#
failregex = INFO .*;ip=<HOST>;.* SoapEngine - handler exception: authentication failed for .*, invalid password$
            INFO .*ip=<HOST>;.* SoapEngine - handler exception: authentication failed for .*, account not found$

ignoreregex =
EOF

    if ! which lsb_release >/dev/null 2>&1; then
        systemctl --now enable fail2ban
    else
        systemctl restart fail2ban
    fi
}

case "${1}" in
    --zimbra9|-zm9)
        set_time
        set_hostname
        install_packages
        open_ports
        disable_postfix
        install_dnsmasq
        set_loopback_dns
        prepare_zimbra9
        phase1_install
        phase2_install
        set_trusted_ip
        install_fail2ban
    ;;
    *)
        set_time
        set_hostname
        install_packages
        open_ports
        disable_postfix
        install_dnsmasq
        set_loopback_dns
        prepare_zimbra
        phase1_install
        phase2_install
        set_trusted_ip
        install_fail2ban
    ;;
esac
