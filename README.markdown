# WARNING:

**NEVER** run imager.pl as a root. Always run it as an unprivileged user. Check your udev rules carefully to avoid accidentally writing over the wrong devices and losing data.

# Instructions

I made 250 copies of some conference proceedings on USB sticks using this. Several failed MD5 sums for one reason or another during the process.

This software helped me organise this, makign it obvious which devices had successfully been written too by turning lights off when they were done. 

This saved me quite a bit of time and minimised errors in the final USB sticks. Hopefully it might help you too.

## Getting started:
0. Create a group (e.g. usblast) that you will run the imager as.
1. Compile the setuid helper for dropping disk caches:

        g++ -Wall -Wextra drop_cache.cc -o drop_cache
2. Set the permissions for drop_cache:

        sudo chown root:usblast drop_cache
        # Only allow root and usblast members to execute, make setuid/gid
        sudo chmod 6710 drop_cache
3. Install to /usr/local/bin

        sudo mv drop_cache /usr/local/bin/
4. Modify and install the udev rules, e.g.:

        ATTRS{idVendor}=="090c", ATTRS{idProduct}=="1000", GROUP="usblast", MODE="0664"
    Matches VID=0x090c, PID=0x1000 and sets mode 0664 with gid usblast

## Creating an image:
You can either use a loopback device, or a real, physical device to create the master image. For the real physical device use `dd if=/dev/XXX of=master.img` to create a raw image.

## Running usblast:

Make sure `imager.pl` will be run with an egid of the group you created, e.g.:

    chgrp usblast imager.pl
    chmod g+s imager.pl

Run imager.pl, optionally specifying an image file (it defaults to master.img). It will compute an md5sum for the image you are using and then start to loop waiting for devices to show up that match the group id it's being run as. When it has spotted the right number of devices press enter to start running.

As it runs it will write to all devices simultaneously, before droping any caches and then verifying the md5sums by reading back in. Once the MD5 sum has been verified each device is "ejected". On most USB sticks this will result in the light turning off, it's safe to unplug the device (and connect more if you want) once that's done
