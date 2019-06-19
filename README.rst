CustomPiOS
==========

A `Raspberry Pi <http://www.raspberrypi.org/>`_ and other ARM devices distribution builder. CustomPiOS opens an already existing image, modifies it and repackages the image ready to ship.

This repository contains the source script to generate a distribution out of an existing `Raspbian <http://www.raspbian.org/>`_ distro image, or Armbian devices.

Where to get it?
----------------

`Clone this repo <https://github.com/guysoft/CustomPiOS>`_. Then follow instructions either to build an existing distro or create your own.



How to use it?
--------------

#. Clone this image ``git clone https://github.com/guysoft/CustomPiOS.git``
#. Run ``src/make_custom_pi_os -g <distro folder>`` in the repo, distro folder should not exist and contain no spaces. This will both create a folder to build a new distro from, and also download the latest raspbian lite image. The initial distro has a module that has the name of your distro, and you can find it under ``<distro folder>/src/modules/<distro name>`` (there should be only one module in the modules folder).
#. cd to ``<distro folder>/src``
#. Edit your ``<distro folder>/src/config``, you can also edit the starting module, which is named as your distro at ``modules/<dstro name>``. More on that in the Developing section.
#. Run ``<distro folder>/src/build_dist`` to build an image. If this fails use the method described in the vagrant build section (which makes sure sfdisk and other things work right).

Features
--------

* Modules - write one module and use it for multiple distros
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
#. p7zip-full
#. Python 3.2+

Known to work building configurations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Linux (Ubuntu / Debian etc)
2. OS X -  `See this thread for information <https://github.com/guysoft/OctoPi/issues/388#issuecomment-316327106>`_


Modules 
-------
`See Modules entry in wiki <https://github.com/guysoft/CustomPiOS/wiki/Modules>`_


chroot_script
~~~~~~~~~~~~~
This is where the stuff you want to execute inside the distro is written.

In ``start_chroot_script`` write the main code, you can use ``end_chroot_script`` to write cleanup functions, that are run at the end of the module namespace.

Useful commands from common.sh
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CustomPiOS comes with a script ``common.sh`` that has useful functions you can use inside your chroot_script.
To use it you can add to your script ``source /common.sh``.

``unpack [from_filesystem] [destination] [owner]`` - Lets you unpack files from the ``filesystem`` folder to a given destination. ``[owner]`` lets you set which user is going to be the owner. eg. ``unpack /filesystem/home/pi /home/pi pi``

``gitclone <MODULE_NAME>_<REPO_NAME>_REPO destination`` - Lets you clone a git repo, and have the settings preset in the ``config`` file. Example usage in OCTOPI module.

In chroot_script::

    gitclone OCTOPI_OCTOPRINT_REPO OctoPrint

In ``config``::

    [ -n "$OCTOPI_OCTOPRINT_REPO_SHIP" ] || OCTOPI_OCTOPRINT_REPO_SHIP=https://github.com/foosel/OctoPrint.git 

Export files from image
~~~~~~~~~~~~~~~~~~~~~~~

CustomPiOS has a feature to export files created in the chroot to archives you can ship as a tar.gz arcive.

To export run inside of a chroot_script:
``custompios_export [name of archive] [file path in chroot]``

You can also use:
``copy_and_export [name of archive] [source] [destination]``

and:
``copy_and_export_folder [name of archive] [folder] [destination]``

The results would be saved in the workspace folder.

filesystem
~~~~~~~~~~

Lets you add files to your distro, and save them to the repo. The files can be unpacked using the ``unpack`` command that is in ``common.sh``.

config
~~~~~~

This is where you can create module-specific settings. They can then be overwritten in a distro or variant.
The naming convention is the module name in 

Build a Distro From within Raspbian / Debian / Ubuntu / CustomPiOS Distros
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
`See building entry in wiki <https://github.com/guysoft/CustomPiOS/wiki/Building>`_
    
Building Distro Variants
~~~~~~~~~~~~~~~~~~~~~~~~
`See building entry in wiki <https://github.com/guysoft/CustomPiOS/wiki/Building>`_

Building Using Docker
~~~~~~~~~~~~~~~~~~~~~~
`See Building with docker entry in wiki <https://github.com/guysoft/CustomPiOS/wiki/Building-with-Docker>`_
    
Building Using Vagrant
~~~~~~~~~~~~~~~~~~~~~~
`See Building with Vagrant entry in wiki <https://github.com/guysoft/CustomPiOS/wiki/Building-with-Vagrant>`_
    

Usage
~~~~~

#. If needed, override existing config settings by creating a new file ``src/config.local``. You can override all settings found in ``src/config``. If you need to override the path to the Raspbian image to use for building your distro, override the path to be used in ``BASE_ZIP_IMG``, which is part of the base module. By default the most recent file matching ``*-raspbian.zip`` found in ``src/image`` will be used.
#. Run ``src/build`` as root.
#. The final image will be created at the ``src/workspace``


List of Distributions using CustomPiOS
--------------------------------------

* `OctoPi <https://octopi.octoprint.org/>`_ - The ready-to-go Raspberry Pi image with OctoPrint
* `FullPageOS <https://github.com/guysoft/FullPageOS>`_ - A raspberrypi distro to display a full page browser on boot
* `Zynthian <http://zynthian.org/>`_ - Open Synth Platform
* `ElectricSheepPi <https://github.com/guysoft/ElectricSheepPi>`_ - A Raspberry Pi distribution to run Electric Sheep digital art
* `AlarmPi <https://github.com/guysoft/AlarmPi>`_ - A Raspberry Pi distribution that turns a raspberrypi to an IOT telegram-controlled alarm clock
* `RealtimePi <https://github.com/guysoft/RealtimePi>`_ - An out-of-the-box raspebrrypi/raspbian distro with a realtime kernel
* `RMS Pi <https://github.com/toddejohnson/rmspi>`_ - Raspberry Pi Distro for Winlink RMS
* `V1PI <https://github.com/jeffeb3/v1pi>`_ - Use your raspberry pi to control your V1Engineering machine
* `HotSpotOS <https://github.com/guysoft/HostSpotOS>`_ - Makes a Raspberrypi start a hotspot, if no wifi was found to conenct to


Code contribution would be appreciated!
