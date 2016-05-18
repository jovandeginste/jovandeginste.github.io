---
layout: post
title: "Using PlatformIO to compile for Jeelabs' Jeenode Micro"
date: "2016-05-11 12:44:46 +0200"
author: jovandeginste
comments: true
tags:
- platformio
- arduino
- jeenode
---

Today I thought about finally testing PlatformIO. It looked great, but I've had issues using Arduino's IDE and other tools to build for Jeelabs' [Jeenode Micro](http://jeelabs.net/projects/hardware/wiki/JeeNode_Micro). I wondered if this time it would be different!

First the installation: no problems here! I used PlatformIO's integreated installer (via deb) and then immediately installed a few other plugins :-)

Then using the editor to build my first (normal) Arduino project.

First I tried to manually recreate a PlatformIO project from my existing code, but this turned out to be harder than just using the "Import Arduino IDE Project..." feature in PlatformIO. I simply hadn't seen that feature first :-) Using the import, I quickly had the project. Now the library dependencies.

With the Arduino IDE I knew there was a central place where I had to put the libraries. This is also possible with PlatformIO; however, after experimenting, I dediced to include the libraries with the project (which is probably the preferred way). So I copied them to the lib/ subdirectory.

Building for Arduino Uno worked. Great! Next challenge, building for Jeenode Micro.

The Jeenode Micro is an attiny84 with onboard RFM12B; Arduino (and PlatformIO) have support for attiny84, however not this "variant"... The error I got was this one:

```
In file included from .pioenvs/attiny84/jeelib/JeeLib.h:17:0,
from /home/jo/projects/applications/onewire-wireless-network/w1sender/src/w1sender.ino:35:
.pioenvs/attiny84/jeelib/Ports.h:717:49: error: 'Serial' was not declared in this scope
InputParser (byte size, Commands*, Stream& =Serial);
^
.pioenvs/attiny84/jeelib/Ports.h:718:60: error: 'Serial' was not declared in this scope
InputParser (byte* buf, byte size, Commands*, Stream& =Serial);
^
```

The error I always got with Arduino :-)

I will not bore you with all the missed attempts to get PlatformIO working with this board, but immediately skip to the working method:

a) Add the special 'tiny' variant to the `cores`

From [jcw's GitHub repo](http://github.com/jcw/ide-hardware) I got the necessary core files. I copied `avr/cores/tiny` from the repo to `~/.platformio/packages/framework-arduinoavr/cores/`.

b) Add a board definition for `jeenode-micro`

I found out I could make a directory `~/.platformio/boards` and add json files there. I created a file `jeenode.json` with this content:

```json
{
    "jeenode-micro": {
        "build": {
            "core": "tiny",
            "extra_flags": "-DARDUINO_ARCH_AVR -DARDUINO_AVR_ATTINY84",
            "f_cpu": "8000000L",
            "mcu": "attiny84",
            "variant": "tiny14"
        },
        "frameworks": ["arduino"],
        "name": "Jeenode Micro",
        "platform": "atmelavr",
        "upload": {
            "maximum_ram_size": 512,
            "maximum_size": 8192,
            "protocol": "usbtiny"
        },
        "url": "http://www.atmel.com/devices/ATTINY84.aspx",
        "vendor": "Jeelabs"
    }
}
```

Now I changed `platformio.ini` file for my project:

`board = jeenode-micro`

Et voila, compile works. Didn't try uploading yet, however. Later :-)
