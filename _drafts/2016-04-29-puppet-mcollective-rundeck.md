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

Todo: insert scripts

## Rundeck

The installation of rundeck was piece of cake using the puppet module. I defined some dummy project in puppet, which was created. The real customization had to wait until I had the integration part ready. 

## Integrating Rundeck and mCollective

Now the integration part! I had a simple test job set up (`uptime`). Now I wanted to know the uptime of all my servers of course ;-)

For the life of me, I could not see how to use the plugin (http://rundeck.org/plugins/2013/01/01/puppet-mc-nodes.html) so I decided to try build something myself. [if anyone cares to explain how I should use plugins like this, I would appreciate it]

### Node source

In a project's "simple configuration editor" you can choose between several node sources, one which is "script" (others include "url" and "file"). The output or content of the source can be xml or yaml.

I used `generate.rb` from [this repository](https://github.com/connaryscott/rundeck-mcollective-nodes) and altered it slightly to use my mco wrapper script instead. I specified this then as script for the node source, and behold, I now have a list of nodes with metadata in Rundeck!

### Node executor

Next step was the "node executor", which would make Rundeck actually execute commands on the remote servers. 