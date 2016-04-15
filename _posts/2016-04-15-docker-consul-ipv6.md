---
layout: post
title: "Docker, consul, network and ipv6"
date: 2016-04-15 16:29:23 +0200
categories: docker consul ipv6
comments: true
---
We run all our containers on ipv6 routable ips. Some time ago I figured
out Docker started too soon, and ipv6 was not yet up-and-running when
Docker started the containers. This caused the containers to fail
because they could not reach the internet (and their container friends
on other hosts) over ipv6.

Solution to this was creating a script "wait-for-network" that would
ping a well-known ip address over ipv6 and the service interface until
it was reachable. Add the script as ExecStartPre and Docker was working
better!

Today I noticed that consul agents started behaving similarly. It's also
connected over ipv6 to the consul servers, and sometimes it starts too
soon. No problem per se because it will be restarted by SystemD, but our
registrator-consul service that 'requires' consul would fail and *not*
be restarted.

I took the following steps:
* I made the 'wait-for-network' script into an independent rpm
* I added the rpm as a dependency for our consul rpm
* I added the ExecStartPre to the consul SystemD unit file

This should delay the consul agent from starting until the network is up
and useable. The registrator should wait for the consul agent too.

