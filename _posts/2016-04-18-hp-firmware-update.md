---
layout: post
categories: hp-firmware
comments: true
---

Today I had to update firmwares on a bunch of servers. The firmware update could be done online, only a (manual) reboot was needed afterwards. The updates can be downloaded as rpm's, so here's what I did:

* copy all the rpm's in a single nfs location
  * (you could put them on a yum repo, but this actuall complicates matters imho)
* make a script that installs the rpm, runs the scexe, removes the rpm
  * HP updates each have a single scexe which actually updates the firmware
	* the rpm puts it in `/usr/lib/${arch}-linux-gnu/hp-scexe-compat/CP######.scexe`
* run the script on every server sequentially
  * (if something goes wrong, not all servers go down at the same time ;-))

The script (you will probably need to change the `RPM_DIR` location):

```bash
#!/bin/bash

RPM_DIR=/path/to/nfs/dir/with/rpms

for RPM in $RPM_DIR/*.rpm
do
        NAME=$(rpm -qp --queryformat '%{NAME}\n' $RPM 2>/dev/null)
        SCRIPT=$(rpm -qpl $RPM 2>/dev/null | grep hp-scexe-compat/.*\.scexe)
        echo "Parsing: '$RPM'; name='$NAME', script='$SCRIPT'"
        if [[ -z "$SCRIPT" ]]
        then
                echo "No scexe '$SCRIPT' found in rpm '$RPM'; no idea what to do ..."
        else
                rpm -ivh $RPM
                echo "Running '$SCRIPT' from '$NAME'..."
                $SCRIPT -s
                echo "Done with '$NAME'; uninstalling:"
                rpm -evh $NAME
        fi
done
```
