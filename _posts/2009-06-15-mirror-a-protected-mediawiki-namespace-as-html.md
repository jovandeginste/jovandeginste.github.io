---
layout: post
title: "Mirror a protected MediaWiki namespace as html"
date: "2009-06-15 18:32:46 +0200"
comments: true
categories: mediawiki
---

## Problem:

We have a MediaWiki containing the full documentation for all our systems. For security reasons, this server is behind corporate firewalls and Shibboleth authentication. Access is limited to a lucky few(including the Linux system administrators).

Obviously, any system has users, and often user support is provided by a dedicated team. This team usually doesn't consist of system administrators, and therefore doesn't have access to our central documentation - which is good!

However, we found that a limited amount of information should be available to those teams, and we were looking for a solution which does not involve maintaining documentation on two separate locations (eg. two separate wikis).

Some options include:

* a second wiki which is regularly mirrored from the primary wiki
* some way of (static) html "download" of the to be public part

Another issue was how to specify the public parts.

## Solution:

We use DumpHTML to make a dump of the whole wiki in a temporary directory. We then copy the public parts into a directory which is accessible through an Apache VirtualHost.

### Get DumpHTML:

* svn export [http://svn.wikimedia.org/svnroot/mediawiki/trunk/extensions/DumpHTML](http://www.mediawiki.org/wiki/Extension_talk:DumpHTML)
* [http://www.mediawiki.org/wiki/Extension_talk:DumpHTML](http://www.mediawiki.org/wiki/Extension_talk:DumpHTML)

### Add the "DumpHTML" user to your wiki:

Since we are automatically authenticated via Shibboleth, and can't login as WikiSysop or something like that, we had to add the DumpHTML user directly in the MySQL database. You need to log in to the MySQL database using the credentials of your wiki. Those can typically be found in a file called "LocalSettings.php" (search for `$wgDBadminuser`) in your wiki installation directory.

```bash
$ mysql $wgDBname -u $wgDBadminuser -p
```

This will prompt you for a password (`$wgDBpassword`) and then provide you with the MySQL prompt.
If your wikitables are prefixed with wk (see `$wgDBprefix$wgDBprefix`), then this MySQL insert statement should add the user:

```sql
insert into wk_user (user_name, user_real_name, user_password, user_newpassword, user_newpass_time, user_email, user_options, user_touched, user_token, user_email_authenticated, user_email_token, user_email_token_expires, user_registration, user_editcount) VALUES ("DumpHTML", "DumpHTML", "nologin", "", "NULL", "", "quickbar=1\nunderline=2\ncols=80\nrows=25\nsearchlimit=20\ncontextlines=5\ncontextchars=50\nskin=\nmath=1\nrcdays=7\nrclimit=50\nwllimit=250\nhighlightbroken==1\nstubthreshold=0\npreviewontop=1\neditsection=1\neditsectiononrightclick=0\nshowtoc=1\nshowtoolbar=1\ndate=default\nimagesize=2\nthumbsize=2\nrememberpassword=0\nenotifwatchlistpages=0\nenotifusertalkpages=1\nenotifminoredits=0\nenotifrevealaddr=0\nshownumberswatching=1\nfancysig=0\nexternaleditor=0\nexternaldiff=0\nshowjumplinks=1\nnumberheadings=0\nuselivepreview=0\nwatchlistdays=3\nvariant=en\nlanguage=en\nsearchNs0=1", "20090615124318", "3034252b230ab51f25ea42b99949b675", "NULL", "NULL", "NULL", "20090121092840", "178")
```

You may need to grant this user "bureaucrat" and/or "sysop" access to the Wiki; this can be done in two ways...

Through the wiki web interface:

* browse to [http://yourwikiurl/index.php/Special:Userrights](http://yourwikiurl/index.php/Special:Userrights)

By poking in the mysql DB:

* find out the `user_id` of the DumpHTML user: `select user_id from wk_user where user_name="DumpHTML";` this should give you a number, eg. 42
* add this `user_id` to the group "bureaucrat": `insert into wk_user_groups (ug_user,ug_group) values (42, "bureaucrat");`
* and to the group "sysop": `insert into wk_user_groups (ug_user,ug_group) values (42, "sysop");`

### Try the script

We use some temporary directory for this: eg. `/tmp/wikidumptest`

```bash
$ mkdir /tmp/wikidumptest /usr/bin/php dumpHTML.php -d /tmp/wikidumptest -k monobook --image-snapshot --force-copy
```

Chances are real that you get the following error:

```
PHP Warning: require_once(/maintenance/commandLine.inc): failed to open stream: No such file or directory in /opt/wikidump/DumpHTML/dumpHTML.php on line 61
PHP Fatal error: require_once(): Failed opening required '/maintenance/commandLine.inc' (include_path='.:/usr/share/pear:/usr/share/php') in /opt/wikidump/DumpHTML/dumpHTML.php on line 61
```

This is be solved by exporting the `MW_INSTALL_PATH` environment variable:

```bash
$ export MW_INSTALL_PATH=/path/to/your/wiki/installation/root
```

If it works, you should find your wiki content in /tmp/wikidumptest. If you have links or similar installed on your host, try this:

```bash
$ links /tmp/wikidumptest/index.html
```

### Only provide the "public" parts

Now we have a full dump of our wiki, which is halfway there ;-) We want to provide only a part of it, which we want somehow to dynamically mark as public. To specify the public parts as so, we decided to add namespaces: one for each public part of a separate subdomain.

E.g. we have a top level namespace "Linux" (which contains all our documenation, we are the Linux team remember ;-)), with a subdomain "HPC"; the public part of the HPC subdomain of the documentation would then be inside the namespace "/Linux/HPC/public/" - not too hard huh? Of course it needs to be "contained", which means no linking to private pages from the public ones. Otherwise, users on the public mirror would get dead links...

In our mirroring script, we specify each public namespace separately. Finding those files is as simple as this (one line per namespace):

```bash
$ find /tmp/wikidumptest -name Linux_HPC_public_*
```

### The full script:

```bash
#!/bin/sh

# Define some directories to use

# The place where we temporarily store the full wiki dump
TMP_DEST=/tmp/wikidumpdirectory
# The eventual location of our public mirror - this is a subdirecotry of the site
DEST=/usr/local/wiki/public-config/wiki

echo "Creating '$TMP_DEST' - deleting first if it already exists..."
rm -rf "$TMP_DEST"
mkdir "$TMP_DEST"

# DumpHTML.php expects to be run from the its directory. The skin won't get HTMLified if you run it from another directory
echo "Generating full dump"
export MW_INSTALL_PATH=/path/to/your/wiki/installation/root
cd /opt/wikidump/DumpHTML /usr/bin/php dumpHTML.php -d "$TMP_DEST" -k monobook --image-snapshot --force-copy

# Prepare real destination directory - we use another intermediate directory,
# to prevent interference
rm -rf "${DEST}-new"
mkdir "${DEST}-new"

# Copy stuff like logo's
cp -r "$TMP_DEST/misc" "${DEST}-new"
cp -r "$TMP_DEST/raw" "${DEST}-new"

echo "Filtering out the public stuff ..."
# One "find" per namespace, we then process everything at once
( find $TMP_DEST -name Linux_Toledo_public_*
find $TMP_DEST -name Linux_HPC_public_*
) | while read file; do
destfile=$(echo $file | sed "s%$TMP_DEST%${DEST}-new%")
mkdir -p $(dirname "$destfile")
cp -v $file $destfile
done
# All files are copied, let's remove it again!
rm -rf "$TMP_DEST"

echo "Replacing old mirror with new one ..."
mv "${DEST}" "${DEST}-old"
mv "${DEST}-new" "${DEST}"
rm -rf "${DEST}-old"
```

### And an index file for the users

Now we have a bunch of files in some directory structure: not really user friendly! However, we can now provide some index.html file to direct users to the subdomain they need:
Edit the file `/usr/local/wiki/public-config/index.html` and add some links to the respective portals for each public part - you do know HTML, right?

### Apache configuration

Finally, you need to point your Apache to this location. This can be done by adding a new `VirtualHost` to your existing configuration.
Don't forget to restart apache/httpd ;-)
