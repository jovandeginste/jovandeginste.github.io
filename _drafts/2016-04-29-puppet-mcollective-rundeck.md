---
layout: post
title: "puppet, mcollective, rundeck"
date: "2016-04-29 20:27:16 +0200"
comments: true
categories: puppet
---

This week I decided to finally spin up and integrate Rundeck with our puppet environment. Obviously, Rundeck should populate its node lists automatically from puppet in some way. 

## mCollective

Many months ago, our consultant already set up mCollective. There was a mCollective script/plugin for Rundeck, so I could try that path. 

Since I myself had not participated in the mCollective setup, I had very little knowledge of the inner workings, and therefore had some catching-up to do.

Ssh key authentication was enabled. This meant that anyone could use mCollective client as long as:

* they had an account with the same name on the remote server(s)
* they had their public key on the remote account's authorized_keys
* they had an ssh agent running on the client

This does not mean that mCollective runs as that user on the remote machine! I tried this with `whoami`, this said `root`...

The mCollective daemon runs as root on the remote servers, but verified the user's access using the ssh keys. After that, the user is using mCollective's privileges. 

This meant some complications for my Rundeck setup, since that would have to run as a service. I would need a single user on every machine, with the same name and public key. On the rundeck server, that user would need the private key. I would need a way to start the ssh agent when needed, and the user running rundeck must be able to su to that other user. 

I defined the user (I called him `mco`) with the keys in puppet and deployed this to a bunch of servers for testing. 

One shell script and some sudo config were needed on the Rundeck server and we were ready to go. 

Script `/usr/local/bin/mcowrapper`:

```bash
# !/bin/bash

cd /tmp

SSH_AUTH_SOCK=/home/mco/ssh.sock
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

The installation of rundeck was piece of cake using the puppet module. I defined some dummy project in puppet, which was created. The real customization had to wait until I had the integration part ready. 

## Integrating Rundeck and mCollective

Now the integration part! I had a simple test job set up (`uptime`). Now I wanted to know the uptime of all my servers of course ;-)

For the life of me, I could not see how to use the plugin (http://rundeck.org/plugins/2013/01/01/puppet-mc-nodes.html) so I decided to try build something myself. [if anyone cares to explain how I should use plugins like this, I would appreciate it]

### Node source

In a project's "simple configuration editor" you can choose between several node sources, one which is "script" (others include "url" and "file"). The output or content of the source can be xml or yaml.

I used `generate.rb` from [this repository](https://github.com/connaryscott/rundeck-mcollective-nodes) and altered it slightly to use my mco wrapper script instead. I specified this then as script for the node source, and behold, I now have a list of nodes with metadata in Rundeck!

### Node executor

Next step was the "node executor", which will allow Rundeck to actually execute commands on the remote servers. 

Here I started to get confused. The options were "ssh", "script" and "stub". Logical choice was "script", at which point I could specify a command line. I could use variables like `${node.hostname}`, `${node.username}` and `${exec.command}`. At this point I started realizing that I was not going to leverage mCollective for the parallel execution - Rundeck would be doing this by itself. Nevertheless I typed the command line, if only to verify that it worked. 

It worked: I could now have the uptime of all nodes that I selected. The `whoami` returned `root`, as expected. Great but I was left with the feeling that an opportunity was missed... 

I thought I could just as well use simple ssh for the remote execution, so I changed the command line:

`ssh -l mco -o SomeOpts ${exec.command}`

Great! Still works, but now `whoami` returned `mco` instead. Some playing around with sudoers on the remote servers, and`sudo whoami` also worked. But I now got rid of the complex setup where rundeck had to `su` to the `mco` user and have an ssh agent running. In fact, I could now even switch to Rundeck's default ssh plugin! I only needed to configure the default remote ssh user in `framework.properties` (and set some other sane defaults) and I was done:

Todo add config from puppet

## Integrating Rundeck and PuppetDB

The question kept nagging me: what was mCollective's added value here? It gives me a list of nodes with metadata. But the metadata actually comes from puppet and facter. Metadata that happened to be stored in the PuppetDB... 

So I did a quick search and found a solution: `puppetdb-rundeck`

## Things to look at

* https://github.com/opentable/puppetdb_rundeck
