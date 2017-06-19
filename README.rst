CustomPiOS
==========

A `Raspberry Pi <http://www.raspberrypi.org/>`_ and other ARM devices) distribution builder. CustomPiOS is opens an already existing image, modifies it and repackages the image ready to ship.

This repository contains the source script to generate a distribution out of an existing `Raspbian <http://www.raspbian.org/>`_ distro image, or Armbian devices.

Where to get it?
----------------

Clone this repo for now, we are still new. Then follow instructions.



How to use it?
--------------

#. Clone this image ``git clone https://github.com/guysoft/CustomPiOS.git``
#. Run ``src/make_custom_pi_os -g <distro folder>`` in the repo. This will both create a folder to build a new distro from, and also download the latest raspbian lite image.
#. cd to ``<distro folder>/src``
#. Edit your ``<distro folder>/src/config``, you can also edit the example module at ``modules/example_module``. More on that in the Developing section.
#. Run ``<distro folder>/src/build_dist`` to build an image. If this failes use the method discribed in the vagrant build the section (which makes sure sfdisk and other things work right).

Features
--------

* Modules - write one module and use if for multiple distros
* Write only the code you need for your distro - no need to maintain complicated stuff like building kernels unless its actually want to do it
* Standard modules give extra functionality out of the box
* Supports over 40 embedded devices using `Armbian <http://armbian.com/>`_ and Raspbian.

Developing
----------

Requirements
~~~~~~~~~~~~

#. `qemu-arm-static <http://packages.debian.org/sid/qemu-user-static>`_
#. Downloaded `Raspbian <http://www.raspbian.org/>`_ image.
#. root privileges for chroot
#. Bash
#. git
#. realpath
#. sudo (the script itself calls it, running as root without sudo won't work)
#. Python 2.6+ or 3.2+


Modules 
-------
One of the main features in CustomPiOS is writing modules. A module is a structured piece of code that adds a function to a distro. 

Setting Modules
~~~~~~~~~~~~~~~

To set what the distro does, you can add and remove modules. The modules are defined in the ``MODULES`` variable set in your distro ``<distro folder>/src/config`` file. Modules can be nested, the enables you to provide namespaces or run cleanup functions after other module have run. For example ``MODULES=base(network(octopi, picamera))``, in this example base will start first, and end last, network will start second and end one before last, octopi will start third and end first.

Writing Modules
~~~~~~~~~~~~~~~
* Module are places in folders whose names are small letters and with hyphens.
* The can be placed either in ``CustomPiOS/src/modules`` or ``<distro folder>/src/modules``.

See the ``example`` module in the example disro.

*Modules are made from 3 parts:*

* ``start_chroot_script`` / ``end_chroot_script``
* ``filesystem`` folder
* ``config`` file

chroot_script
~~~~~~~~~~~~~
This is where the stuff you want to execute inside the distro is written.

In ``start_chroot_script`` write the main code, you can use ``end_chroot_script`` to write cleanup functions, that are run at the end of the module namespace.

*Useful commands from common.sh*

CustomPiOS comes with a script ``common.sh`` that has useful functions you can use inside your chroot_script.
To use it you can add to your script ``source /common.sh``.

``unpack [from_filesystem] [destination] [owner]`` - Lets you unpack files from the ``filesystem`` folder to a given destination. ``[owner]`` lets you set which user is going to be the owner. eg. ``unpack /filesystem/home/pi /home/pi pi``

``gitclone <MODULE_NAME>_<REPO_NAME>_REPO destination`` - Lets you clone a git repo, and have the settings preset in the ``config`` file. Example usage in OCTOPI module.

In chroot_script::

    gitclone OCTOPI_OCTOPRINT_REPO OctoPrint

In ``config``::

    [ -n "$OCTOPI_OCTOPRINT_REPO_SHIP" ] || OCTOPI_OCTOPRINT_REPO_SHIP=https://github.com/foosel/OctoPrint.git 

filesystem
~~~~~~~~~~

Lets you add files to your distro, and save them to the repo. The files can be unpacked using the ``unpack`` command that is in ``common.sh``.

config
~~~~~~

This is where you can create module-specific settings. They can then be overwritten in a distro or variant.
The naming convention is the module name in 

Build a Distro From within Raspbian / Debian / Ubuntu / CustomPiOS Distros
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CustomPiOS distros can be built from Debian, Ubuntu, Raspbian, or even within a distro itself (for other systems use the Vagrant build option).
Build requires about 2.5 GB of free space available, depending on what you install.
You can build it by issuing the following commands::

    sudo apt-get install gawk util-linux realpath qemu-user-static git
    
    git clone https://github.com/guysoft/CustomPiOS.git
    cd CustomPiOS/src
    ./make_custom_pi_os -g /path/to/new_distro
    cd /path/to/new_distro/src
    sudo modprobe loop
    sudo bash -x ./build_dist
    
Building Distro Variants
~~~~~~~~~~~~~~~~~~~~~~~~

CustomPiOS supports building variants, which are builds with changes from the main release build. An example and other variants are available in the folder ``src/variants/example``.

To build a variant use::

    sudo bash -x ./build_dist [Variant]
    
Building Using Vagrant
~~~~~~~~~~~~~~~~~~~~~~
There is a vagrant machine configuration to let build a CustomPiOS distro in case your build environment behaves differently. Unless you do extra configuration, vagrant must run as root to have nfs folder sync working.

To use it::

    sudo apt-get install vagrant nfs-kernel-server
    sudo vagrant plugin install vagrant-nfs_guest
    sudo modprobe nfs
    cd <distro folder>/src/vagrant
    sudo vagrant up

After provisioning the machine, its also possible to run a nightly build which updates from devel using::

    cd <distro folder>//src/vagrant
    run_vagrant_build.sh
    
To build a variant on the machine simply run::

    cd <distro folder>/src/vagrant
    run_vagrant_build.sh [Variant]
    

Usage
~~~~~

#. If needed, override existing config settings by creating a new file ``src/config.local``. You can override all settings found in ``src/config``. If you need to override the path to the Raspbian image to use for building yoru dstro, override the path to be used in ``BASE_ZIP_IMG``, which is part of the base module. By default the most recent file matching ``*-raspbian.zip`` found in ``src/image`` will be used.
#. Run ``src/build`` as root.
#. The final image will be created at the ``src/workspace``


Code contribution would be appreciated!
