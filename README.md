bash-zimbra-single
==================

This script automates the process of installing single-server Zimbra Open Source Edition v8.8.15 and v9.0.0 on CentOS 8 and Ubuntu 18.04.

Requirements
------------

1) Must be a fresh CentOS 8 or Ubuntu 18.04 minimal installation
2) Static network configuration must be already set

How to use
----------

Clone and change directory to the project folder

    # git clone https://github.com/jancubillan/bash-zimbra-single.git
    # cd bash-zimbra-single

Modify the variables file then run the main.sh script. Good for traditional and on-premise deployments.

    # vi vars/main.txt
    # bash main.sh
    OR
    # bash main.sh --zimbra9

If you want to configure local DNS first then Zimbra later. Good for when networking is managed externally eg. AWS, Azure, GCP, etc.

    # bash main.sh --dns-only
    # bash main-sh --no-dns (After you have pointed nameserver to localhost or private IP)
    OR
    # bash main-sh --zimbra9-no-dns (After you have pointed nameserver to localhost or private IP)

If you want to setup Zimbra without local DNS eg. DNS is handled externally (Setup records first before running!)

    # bash main.sh --no-dns
    OR
    # bash main.sh --zimbra9-no-dns

Other Features
--------------

The script also installs Fail2Ban configured with predetermined jails and filters. You can view them in /etc/fail2ban directory.

    # fail2ban-client status
      Status
      |- Number of jail:	4
      `- Jail list:	sshd, zimbra-admin, zimbra-smtp, zimbra-webmail

License
-------

MIT License

Author Information
------------------

Author: Jan Cubillan<br/>
GitHub: https://github.com/jancubillan<br/>
