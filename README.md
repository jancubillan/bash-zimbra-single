NOT FOR PRODUCTION USE
======================

bash-zimbra-single
=====================

This role automates the process of installing single-server Zimbra Open Source Edition v8.8.15 on CentOS 7.

Requirements
------------

1) Must be a fresh CentOS 7 minimal installation
2) Static network configuration must be already set

How to use:

    # git clone https://github.com/jancubillan/bash-zimbra-single.git
    # cd bash-zimbra-single
    # vi install.sh
    # bash install.sh

Reset Administrator password:

    # zmprov sp admin@example.com mypassword

License
-------

MIT License

Author Information
------------------

Author: Jan Cubillan<br/>
GitHub: https://github.com/jancubillan<br/>
