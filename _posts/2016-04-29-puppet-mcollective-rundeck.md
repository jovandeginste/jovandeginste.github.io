---
layout: post
title: "puppet, mcollective, rundeck"
date: "2016-04-29 20:27:16 +0200"
author: "Jo Vandeginste"
comments: true
tags:
- puppet
- mcollective
- rundeck
- puppetdb
---

This week I decided to finally spin up and integrate Rundeck with our puppet environment. Obviously, Rundeck should populate its node lists automatically from puppet in some way.

## mCollective

Many months ago, our consultant set up mCollective. There was an mCollective script/plugin for Rundeck, so I could try that path.

Since I myself had not participated in the mCollective setup, I had very little knowledge of the inner workings, and therefore had some catching-up to do.

Ssh key authentication was enabled. This meant that anyone could use mCollective client as long as:

* they had an account with the same name on the remote server(s)
* they had their public key on the remote account's authorized_keys
* they had an ssh agent running on the client

This does not mean that mCollective runs as that user on the remote machine! I tried this with `whoami`, this returned `root`...

The mCollective daemon runs as root on the remote servers, but verified the user's access using the ssh keys. After that, the user is using mCollective's privileges.

This means some complications for the Rundeck setup, since Rundeck runs as a service. I would need a user on every machine, with the same name and public key. On the Rundeck server, that user would need the private key. I would need a way to start the ssh agent, and the user running Rundeck must be able to run commands as that other user.

I defined the user (I called him "mco") with the keys in puppet and deployed this to a bunch of servers for testing.

One shell script and some sudo config were needed on the Rundeck server and we were ready to go.

Script `/usr/local/bin/mcowrapper`:

```bash
# !/bin/bash

SSH_AUTH_SOCK=$HOME/ssh.sock
export SSH_AUTH_SOCK

(
        [[ -e "$SSH_AUTH_SOCK" ]] || ssh-agent -a $SSH_AUTH_SOCK
        ssh-add
) &>/dev/null

mco $@

killall -u $USER ssh-agent
```

Sudo config:

```sudoers
rundeck ALL=(mco) NOPASSWD: /usr/local/bin/mcowrapper
```

## Rundeck

The installation of rundeck was piece of cake using the puppet module. I defined a dummy Rundeck project in puppet, which was then created. The detailed configuration of projects and jobs had to wait until I had the integration part ready.

## Integrating Rundeck and mCollective

I had a simple test job set up (`uptime`). Now I wanted to know the uptime of all my servers ;-)

For the life of me, I could not see how to use the plugin (http://rundeck.org/plugins/2013/01/01/puppet-mc-nodes.html) so I decided to try and build something myself. [if anyone cares to explain how I should use plugins like this, I would appreciate it]

### Node source

In a project's "simple configuration editor" you can choose between several node sources, one of those is "script" (others include "url" and "file"). The output or content of the source can be xml or yaml.

I used `generate.rb` from [this repository](https://github.com/connaryscott/rundeck-mcollective-nodes) and altered it slightly to use my mco wrapper script instead. I specified this as the script for the node source, and behold, I had a list of nodes with metadata in Rundeck!

### Node executor via mCollective

Next step was the "node executor", which will allow Rundeck to actually execute commands on the remote servers.

Here I started to get confused. The options were "ssh", "script" and "stub". Logical choice was "script", at which point I could specify a command line. I could use variables like `${node.hostname}`, `${node.username}` and `${exec.command}`. At this point I started realizing that I was not going to leverage mCollective for the parallel execution - Rundeck would be doing this by itself. Nevertheless I typed the command line, if only to verify that it worked.

```
sudo -u mco /usr/local/bin/mcowrapper shell -I ${node.hostname} run ${exec.command}
```

It worked: I now had the uptime of all nodes that I selected. The command `whoami` returned "root", as expected. Great, but I was left with the feeling that an opportunity was missed...

**Current state:**

* mCollective provides the list of nodes with metadata to Rundeck via an interface script
* Rundeck connects to a remote server using mCollective via a key pair
* the mCollective connections require a special user both on the Rundeck server as on the remote server
* the effective remote user is "root"

### Node executor via ssh

Since Rundeck started an mCollective session for each remote server, I thought I could just as well use simple ssh for the remote execution. So I provided the private key to the user running Rundeck and changed the command line into this:

```
ssh -l mco -o SomeOpts ${exec.command}
```

Great! Still works, but now `whoami` returned "mco" instead. After playing around with sudoers on the remote servers, `sudo whoami` also worked. But I now got rid of the complex setup where Rundeck had to `su` to the `mco` user and have an ssh agent running. In fact, I could now even switch to Rundeck's default ssh plugin! I only needed to configure the default remote ssh user in `framework.properties` and I was done:

```puppet
class { '::rundeck':
  framework_config       => {
    'framework.ssh.user' => 'mco',
  }
}
```

**Current state:**

* mCollective provides the list of nodes with metadata to Rundeck via an interface script
* Rundeck directly connects to a normal remote user over ssh via a key pair
* the effective remote user is **not** "root"
* the remote user however has unrestricted sudo-capabilities (managed via sudoers)

## Integrating Rundeck and PuppetDB

The question kept nagging me: what was mCollective's added value here? It gives me a list of nodes with metadata. But the metadata actually comes from puppet and facter. Metadata that happened to be stored in the PuppetDB...

So I did a quick search and found a possible solution: [puppetdb2-rundeck](https://github.com/sirloper/puppetdb2-rundeck)

This is a Sinatra app, providing a REST-bridge between PuppetDB and Rundeck. Without any additional config, I could start the app on the same server running PuppetDB, and `curl` returned the list of servers found in PuppetDB with some metadata. Great!

I changed the Rundeck project's node source to "url" and pointed it to the Sinatra app. Refreshing the node list took a few seconds, and then gave me a full list, complete with metadata filters. To make sure this keeps working, I added the Ruby script and the Sinatra config to puppet, and included a Systemd unit file to control it.

Since mCollective was now out of the picture, I decided to rename the special "mco" user to "rundeck-user". Again, puppet made this a simple task.

**Current state:**

* PuppetDB provides the list of nodes with metadata to Rundeck via a bridge
* Rundeck directly connects to a normal remote user "rundeck-user" over ssh via a key pair
* the effective remote user is **not** "root"
* the remote user however has unrestricted sudo-capabilities (for now at least, managed via sudoers)

## A final bug to fix

Meanwhile, the rundeck-user was added to all nodes in our puppet environment. And now, everytime I ran a command on all servers, I ended up with a stack trace and this error in the log file (after a lot of successful commands):

```
2016-04-29 18:24:23,965 [qtp1545044507-58] INFO  grails.app.services.rundeck.services.ScheduledExecutionService - scheduling temp job: TEMP:admin:75
2016-04-29 18:24:24,038 [quartzScheduler_Worker-7] ERROR grails.app.services.rundeck.services.ExecutionUtilService - Execution failed: 75: Null hostname value
```

The stack trace being what it was, the execution also just stopped (only about half the nodes executed the command, then came the stack trace and execution stopped), and the final job report was purged because of the error. This was a severe issue.

And a strange error, since the information comes from PuppetDB...

After playing with the node filter, I found that the error occurred when any of a specific set of servers were included. And looking those up in PuppetDB, I discovered that they really did not have a `hostname` fact; the REST-bridge reflected this:

```
$ curl -s http://localhost:4567/ | grep -e good-server.domain -e bad-server.domain
```

```yaml
good-server.domain:
  hostname: good-server.domain
  fqdn: good-server.domain
  clientcert: good-server.domain
bad-server.domain:
  fqdn: bad-server.domain
  clientcert: bad-server.domain
```

Those bad servers had at some point been added to the PuppetDB, but they had never submitted a catalog or fact list. (How? Why? Who could I blame? ;-))

I could fix those nodes now in PuppetDB, but chances where real that other nodes would be added later without `hostname`, if only temporarily. I could not risk production jobs to fail because of that.

For now, I settled on patching the bridge between Rundeck and PuppetDB, filtering the list of nodes returned by excluding the nodes without `hostname` field. Now running a command across all servers and with a success code, and a full report. Great!

## Things to look at later

* send the patch on the bridge to interested parties
* deploy Rundeck projects with git
* maybe switch to an existing puppet module (eg. https://github.com/opentable/puppetdb_rundeck)
* integrate with Jenkins
* integrate with Mattermost
