bash-zimbra-single
=====================

This script automates the process of installing single-server Zimbra Open Source Edition v8.8.15 on CentOS 7.

Requirements
------------

1) Must be a fresh CentOS 7 minimal installation
2) Static network configuration must be already set

How to use:
-----------

Clone and change directory to the project folder

    # git clone https://github.com/jancubillan/bash-zimbra-single.git
    # cd bash-zimbra-single

Modify the variables file then run the main.sh script

    # vi vars/main.txt
    # bash main.sh

Reset Administrator password:

    # zmprov sp admin@example.com mypassword

License
-------

MIT License

Author Information
------------------

Author: Jan Cubillan<br/>
GitHub: https://github.com/jancubillan<br/>
