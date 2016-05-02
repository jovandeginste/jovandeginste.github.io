---
layout: post
title: "Semi-automatic http gateway"
date: "2009-06-19 15:24:36 +0200"
comments: true
tags: squid
---

*Warning - this is from my archive*

By default we block all external traffic, and enable what's needed. For http traffic, this is can be real pain in the ass. We have a group of machines which provide content based on external rss feeds. They regularly download the content from those feeds, and cache them for the end users. This means we need to enable access from those machines to each of the external hosts on port 80\. All pages on those hosts are then fully accessible. This is not limited to rss feeds, but eg. includes package repositories.
The solution is to set up an http proxy server to filter http access on a higher level

## Exploration

We want to allow some groups of machines to access some types of content (eg. rss feeds):
In squid.conf:

```
# Define the machine group by listing the source ip's:
acl rss_machines src <ip address 1>
acl rss_machines src <ip address 2>

...

# Define the url regexs:
acl rss_uris url_regex <regex1>
acl rss_uris url_regex <regex2>
...

# Allow access to the regexs from the machine group ...
http_access allow rss_uris rss_machines
# .. but deny access to anyone else:
http_access deny rss_uris
```

Concrete example:

```
acl rss_machines src 10.33.5.99
acl rss_uris url_regex http\:\/\/feeds\.feedburner\.com/dso-snelnieuws

http_access allow rss_uris rss_machines
http_access deny rss_uris
```

Instead of adding a line per host or per website, it is possible to provide a file name (between quotes); squid will read the file and add every line to the acl:

```
acl rss_machines src "/path/to/rss.machines"

acl rss_uris url_regex "/path/to/rss.uris"

http_access allow rss_uris rss_machines
http_access deny rss_uris
```

Now just add the right lines to the right files and reload squid! But that's what we wanted to automate ... :-)
We will still add the machines manually to the correct group, but the url's should be checked regularly and added automatically to the right uri list. That's what comes now...

## Implementation

On the http gateway, we make a directory to contain all our scripts and files. The list of classes is "calculated" by listing `*.test` and checking if the file is executable.
The scripts are:

a `squid-parser.sh`
  This script should be executed regularly, with a cron job. It will parse the squid access log file and look for 403's (forbidden - those are the URI's we need). Then for each URI it will match the host that tried to access it to the classes the host is member of. Next, the URI is matched to the uris and uris.false file for these classes (ie. $class.uris, $class.uris.false). This match supports regexes.
  Finally, it will select for each class the URI's that occurred more often than some threshold (MINHITS), and test each of them to see if they fit the class (eg. see if some URI is actually an rss feed). Depending on the result of this test, the URI is "de-regexed" (ie. some escapes are added to prevent unwanted regex matching) and added to $class.uris or $class.uris.false.
b `squid-generator.sh`
  This script will generate the `/etc/squid/squid.conf` file based on two templates (squid.conf.pre and squid.conf.post), and insert per class a few lines to enable the class (the exploration above quotes an example for the rss class)
c `$class.test`
  Finally, we need a test-file per class. This means we create a script "rss.test" for the class "rss" (and make it executable). From then on, the other two scripts "know" rss is a class. The point of the class.test script is to make the whole framework extendible: the test script is called from squid-parser.sh with the URI as parameter and should exit with 0 if the URI matches its class or 1 if it doesn't. Based on that exit code the URI is classified and appended to the correct file (class.uris or class.uris.false).

### a) squid-parser.sh

```bash
#!/bin/bash

CLASSES=""

for CLASSFILE in *.test
do
 [[ -x $CLASSFILE ]] && \
  CLASS=$(echo $CLASSFILE | sed 's/\.test$//') && \
  ([[ -f ${CLASS}.uris ]] || touch ${CLASS}.uris) && \
  ([[ -f ${CLASS}.uris.false ]] || touch ${CLASS}.uris.false) && \
  CLASSES="$CLASSES $CLASS"
done

CLASSES=$(echo $CLASSES)
echo "###########################################################"

if [ -z "$CLASSES" ]
then
 echo "Warning: no classes detected!"

 echo "###########################################################"
 exit 1
fi

echo "Detected the following classes: $CLASSES"
echo "###########################################################"

MINHITS=20

for CLASS in $CLASSES
do
 FILE="/tmp/uri_${CLASS}"
 [[ -f "$FILE" ]] && rm -f "$FILE"

done

cat /var/log/squid/access.log |
 while read Timestamp Elapsed Client ActionCode Size Method URI Ident HierarchyFrom Content
do
 case "$ActionCode" in
  "TCP_DENIED/403")
   echo "$Client tried to go to $URI"
   for CLASS in $CLASSES
   do
    # Is the machine allowed to access this class of URI's?
    [[ $(grep "$Client" $CLASS.machines) ]] || continue

    # If any line in the URI files match this line (regex!),
    # it's already added earlier:
    for LINE in $(cat $CLASS.uris $CLASS.uris.false)
    do
     [[ "$URI" =~ "$LINE" ]] && continue 2
    done

    # If we're here, we can assume the URI should be checked...
    echo $URI >> /tmp/uri_${CLASS}
    echo "Added '$URI' to the possible-hit-list for $CLASS"

   done
   ;;
  *)
   # NOOP ...
   ;;
 esac
done

echo "###########################################################"
echo "Done parsing logs, starting to parse results..."

for CLASS in $CLASSES
do
 FILE="/tmp/uri_${CLASS}"
 [[ -f "$FILE" ]] \
 && sort $FILE |
  uniq -c |
  while read COUNT URI
  do
   echo "$URI matched $COUNT time(s)"

   URI_REGEX=$(echo "^$URI\$" | sed 's%[/\.&;:\*\+\?]%\\&%g')
   [[ "$COUNT" -gt "$MINHITS" ]] \
    && (
     ./$CLASS.test "$URI" \
     && (echo "$URI_REGEX" >> $CLASS.uris \
      && echo "Added '$URI' to $CLASS.uris") \
     || (echo "$URI_REGEX" >> $CLASS.uris.false \
      && echo "Added '$URI' to $CLASS.uris.false")
    )
  done \
 && rm -f "/tmp/uri_${CLASS}"

done

echo "Reloading squid ..."
/etc/init.d/squid reload
echo "Done."
```

### b) squid-generator.sh

```bash
#!/bin/bash

CLASSES=""

SQUIDTMP=$(mktemp)
ROOT=/usr/local/sm/scripts/squid

for CLASSFILE in *.test
do
 [[ -x $CLASSFILE ]] && \
  CLASS=$(echo $CLASSFILE | sed 's/\.test$//') && \
  CLASSES="$CLASSES $CLASS"
done

CLASSES=$(echo $CLASSES)
echo "###########################################################"

if [ -z "$CLASSES" ]
then
 echo "Warning: no classes detected!"

 echo "###########################################################"
 exit 1
fi

echo "Detected the following classes: $CLASSES"
echo "###########################################################"

[[ -f squid.conf.pre ]] && echo "* adding squid.conf.pre" && cat squid.conf.pre >> $SQUIDTMP || echo "* squid.conf.pre not found!"

for CLASS in $CLASSES
do
 echo "* generating class $CLASS"

 # Something like:
 # acl rss.machines src "$(pwd)/rss.machines"
 # acl rss.uris url_regex "$(pwd)/rss.uris"
 # http_access allow rss.uris rss.machines
 # http_access deny rss.uris

 echo -e "\n########################## Start of ${CLASS} ##########################" >> $SQUIDTMP
 echo -e "# Allow machines from ${CLASS}.machines to access URI's from ${CLASS}.uris:" >> $SQUIDTMP
 echo "acl ${CLASS}_machines src \"${ROOT}/${CLASS}.machines\"" >> $SQUIDTMP
 echo "acl ${CLASS}_uris url_regex \"${ROOT}/${CLASS}.uris\"" >> $SQUIDTMP
 echo "http_access allow ${CLASS}_uris ${CLASS}_machines" >> $SQUIDTMP
 echo "http_access deny ${CLASS}_uris" >> $SQUIDTMP
 echo -e "########################### End of ${CLASS} ###########################\n" >> $SQUIDTMP
done

[[ -f squid.conf.post ]] && echo "* adding squid.conf.post" && cat squid.conf.post >> $SQUIDTMP || echo "* squid.conf.post not found!"

rm -vf /etc/squid/squid.conf
cp -v $SQUIDTMP /etc/squid/squid.conf

rm -f $SQUIDTMP

echo "Reloading squid ..."
/etc/init.d/squid reload
echo "Done."
```

### c) rss.test

```bash
#!/bin/bash

URL=$1

echo -n "Testing if '$URL...' is rss feed..." >&2

# Download the given URL to test based on content
TMPFILE=$(mktemp)

function exit_rm {
 [[ -f "$TMPFILE" ]] && rm -f $TMPFILE
 [[ "$1" == "0" ]] && echo " yes" || echo " no"

 exit $1
}

wget -qO $TMPFILE "$URL"

# Test against some known RSS headers
[[ $(grep "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" $TMPFILE) ]] && exit_rm 0

# If all tests fail, it's not an rss feed ...
exit_rm 1
```

## Use the proxy on your machines

You can add the proxy for some specific items, like the yum package repositories:

```
proxy=http://your-http-gw:8080
http_caching=packages
```

Or you can define a "general" proxy for applications that support his (eg. wget, links)

```
export http_proxy=http://your-http-gw:8080
```
