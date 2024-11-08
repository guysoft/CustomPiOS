CustomPiOS
==========

.. image:: https://raw.githubusercontent.com/guysoft/CustomPiOS/devel/media/CustomPiOS.png
.. :scale: 50 %
.. :alt: CustomPiOS logo

.. class:: center

A `Raspberry Pi <http://www.raspberrypi.org/>`_ and other ARM devices distribution builder. CustomPiOS opens an already existing image, modifies it and repackages the image ready to ship.

This repository contains the source script to generate a distribution out of an existing `Raspbian <http://www.raspbian.org/>`_ distro image, or Armbian devices.

Donate
------
CustomPiOS is 100% free and open source and maintained by Guy Sheffer. If its helping your life, your organisation or makes you happy, please consider making a donation. It means I can code more and worry less about my balance. Any amount counts.
Also many thanks to people contributing code.

|paypal|

.. |paypal| image:: https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif
   :target: https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=26VJ9MSBH3V3W&source=url

Where to get it?
----------------

`Clone this repo <https://github.com/guysoft/CustomPiOS>`_. Then follow instructions either to build an existing distro or create your own.



How to use it?
--------------

#. Clone this image ``git clone https://github.com/guysoft/CustomPiOS.git``
#. Run ``./src/make_custom_pi_os -g <distro folder>`` in the repo, distro folder should not exist and contain no spaces. This will both create a folder to build a new distro from, and also download the latest raspbian lite image. The initial distro has a module that has the name of your distro, and you can find it under ``<distro folder>/src/modules/<distro name>`` (there should be only one module in the modules folder).
#. cd to ``<distro folder>/src``
#. Edit your ``<distro folder>/src/config``, you can also edit the starting module, which is named as your distro at ``modules/<dstro name>``. More on that in the Developing section.
#. Run ``sudo ./<distro folder>/src/build_dist`` to build an image. If this fails use the method described in the vagrant build section (which makes sure sfdisk and other things work right).

Features
--------

* Modules - write one module and use it for multiple distros
* Write only the code you need for your distro - no need to maintain complicated stuff like building kernels unless its actually want to do it
* Standard modules give extra functionality out of the box
* Supports over 40 embedded devices using `Armbian <http://armbian.com/>`_ and Raspbian.
* Supports Raspberry Pi OS arm64 bit using the ``raspios_lite_arm64`` variant.

Developing
----------

Requirements
~~~~~~~~~~~~

#. `qemu-arm-static <http://packages.debian.org/sid/qemu-user-static>`_ or gentoo qemu with static USE
#. Downloaded `Raspbian <http://www.raspbian.org/>`_ image.
#. root privileges for chroot
#. Bash
#. jq
#. git
#. realpath
#. file
#. sudo (the script itself calls it, running as root without sudo won't work)
#. p7zip-full
#. Python 3.2+
#. GitPython
#. kpartx - optional if you need to run update-grub in the image

Known to work building configurations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Using the `CustomPiOS docker image <https://hub.docker.com/r/guysoft/custompios>`_
2. Linux (Ubuntu / Debian / Gentoo etc)
3. OS X -  `See this thread for information <https://github.com/guysoft/OctoPi/issues/388#issuecomment-316327106>`_


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

``unpack [from_filesystem] [destination] [owner]`` - Lets you unpack files from the ``filesystem`` folder to a given destination. ``[owner]`` lets you set which user is going to be the owner. e.g. ``unpack /filesystem/home/pi /home/pi pi``

``gitclone <MODULE_NAME>_<REPO_NAME>_REPO destination`` - Lets you clone a git repo, and have the settings preset in the ``config`` file. Example usage in OCTOPI module.

In chroot_script::

    gitclone OCTOPI_OCTOPRINT_REPO OctoPrint

In ``config``::

    [ -n "$OCTOPI_OCTOPRINT_REPO_SHIP" ] || OCTOPI_OCTOPRINT_REPO_SHIP=https://github.com/foosel/OctoPrint.git 

Export files from image
~~~~~~~~~~~~~~~~~~~~~~~

CustomPiOS has a feature to export files created in the chroot to archives you can ship as a tar.gz archive.

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

Build using CI/CD
~~~~~~~~~~~~~~~~~
You can build CustomPiOS images from a continuous integration system in the cloud.
For an example on how to do this on github take a look at `this github actions yaml <https://github.com/guysoft/OctoPi/blob/devel/.github/workflows/build.yml/>`_

Usage
~~~~~

#. If needed, override existing config settings by creating a new file ``src/config.local``. You can override all settings found in ``src/config``. If you need to override the path to the Raspbian image to use for building your distro, override the path to be used in ``BASE_ZIP_IMG``, which is part of the base module. By default the most recent file matching ``*-raspbian.zip`` found in ``src/image`` will be used.
#. Run ``src/build`` as root.
#. The final image will be created at the ``src/workspace``


Community
--------
|discord|

.. |discord| image:: https://img.shields.io/discord/1119337877734699018?label=discord&logo=discord&logoColor=white
   :target: https://discord.gg/rK72VZVt

List of Distributions using CustomPiOS
--------------------------------------

* `OctoPi <https://octopi.octoprint.org/>`_ - The ready-to-go Raspberry Pi image with OctoPrint
* `FarmPi <https://farmpi.kevenaar.name/>`_ - An Ubuntu ARM 64bit Raspberry Pi image running `OctoFarm <https://octofarm.net/>`_
* `FullPageOS <https://github.com/guysoft/FullPageOS>`_ - A Raspberry Pi distro to display a full page browser on boot
* `Zynthian <http://zynthian.org/>`_ - Open Synth Platform
* `ElectricSheepPi <https://github.com/guysoft/ElectricSheepPi>`_ - A Raspberry Pi distribution to run Electric Sheep digital art
* `AlarmPi <https://github.com/guysoft/AlarmPi>`_ - A Raspberry Pi distribution that turns a Raspberry Pi to an IOT telegram-controlled alarm clock
* `RealtimePi <https://github.com/guysoft/RealtimePi>`_ - An out-of-the-box Raspebrry Pi/Raspbian distro with a realtime kernel
* `RMS Pi <https://github.com/toddejohnson/rmspi>`_ - Raspberry Pi Distro for Winlink RMS
* `V1PI <https://github.com/jeffeb3/v1pi>`_ - Use your Raspberry Pi to control your V1Engineering machine
* `HotSpotOS <https://github.com/guysoft/HostSpotOS>`_ - Makes a Raspberry Pi start a hotspot, if no wifi was found to connect to
* `MtigOS <https://github.com/guysoft/MtigOS>`_ - Distro that lets you receive, store and graph sensor information from ESP8266 chips. It uses and MTIG stack: Mosquitto, Telegraf, InfluxDB and Grafana which are all pre-configured to work together. They automatically update using Docker.
* `Tilti-Pi <https://github.com/myoung34/tilty-pi>`_ - Distro that lets you submit BLE data for the  `tilt hydrometer <https://tilthydrometer.com/>`_ via the `tilty <https://github.com/myoung34/tilty>`_ package and a built in `dashboard <https://github.com/myoung34/tilty-dashboard>`_
* `MainsailOS <https://github.com/mainsail-crew/mainsailos>`_ - Distro that packages the `Mainsail <https://github.com/mainsail-crew/mainsail>`_ web UI, the `Moonraker <https://github.com/Arksine/moonraker>`_ API, and the `Klipper <https://github.com/klipper3d/klipper>`_ 3D printer firmware in an easy to package.
* `UbuntuDockerPi <https://github.com/guysoft/UbuntuDockerPi>`_ - Distro ships with Ubuntu ARM 64bit Docker and docker-compose ready to build stuff for arm64v8/aarch64 or host whatever you like.
* `FluiddPi <https://github.com/cadriel/fluiddpi>`_ - Distro that packages `Fluidd <https://github.com/cadriel/fluidd>`_, `Moonraker <https://github.com/Arksine/moonraker>`_, and `Klipper <https://github.com/KevinOConnor/klipper>`_ into the ultimate 3D printer firmware package.
* `My Naturewatch Camera <https://github.com/interactionresearchstudio/NaturewatchCameraServer>`_ - A Python / OpenCV camera server to stream Pi camera content to a remote client through a website.
* `PiFireOS <https://github.com/calonmerc/PiFireOS>`_ - Distro for pellet grill/smoker control, running `PiFire <https://nebhead.github.io/PiFire>`_.
* `MonsterPi <https://docs.fdm-monster.net/guides/monsterpi>`_ - An Ubuntu ARM 64bit Raspberry Pi image running `FDM Monster <https://fdm-monster.net/>`_. This 3D Print server will help you connect 200+ OctoPrints together while providing a strong, professional workflow.
* `AllStarLink <https://allstarlink.org>`_ - AllStarLink is a network of Amateur Radio repeaters, remote base stations and hot spots accessible to each other via Voice over Internet Protocol. The ASL3 Pi Appliance uses CustomPiOS

Code contribution would be appreciated!
