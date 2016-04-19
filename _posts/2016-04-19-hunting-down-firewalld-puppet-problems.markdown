---
layout: post
title: "Hunting down FirewallD/puppet problems"
date: "2016-04-19 21:15:04 +0200"
comments: true
categories: puppet
---

Today I lost a lot of time hunting for an issue between FirewallD and the Puppet module I use to manage FirewallD. The real weird issue was that it actually worked, but running puppet agent threw an annoying warning, and triggerd a full reload of FirewallD every time.

Yesterday evening everything worked (I think). I was working on setting up a docker swarm via puppet, and had a working setup. Today I was finishing the setup and making a new implementation for a real use case. Then I started refactoring the code to simplify the parameterization via Hiera. One thing I wanted to accomplish was to simplify the firewall-part (firewalld). I seemed to make progress, but some annoying error kept popping up:

```
Warning: Found IPTables is not consistent with firewalld's zones, we will reload firewalld to attempt to restore consistency.  If this doesn't fix it, you must have a bad zone XML
Error: Could not prefetch firewalld_zonefile provider 'zoneprovider': Bad zone XML found, check your zone configuration
```

At first I didn't care - I was in the flow, struggling with the limitations of puppet (v3 - manipulation of hashes and arrays in a manifest). When at last I conceded and created a custom function, I started looking at the error above.

While trying to get the error fixed (I was sure I hadn't the issue yesterday!) I eventually reverted **EVERYTHING**:

* I undid all my changes of today
* I reverted back to yesterday's version of the FirewallD puppet module
* I reinstalled the test server I was working on

Nothing worked. All those reverts took up most of today (in between other stuff that had to be done). While driving home in the evening, I was obviously still pondering what I could have missed. I had sent out a mail to the maintainer of the puppet module for his thoughts, and during dinner I already had a reply. In order not to lose to much time, I sent him some information back, and not before long, the answer became obvious: **IPv6**

The only thing I had not reverted where the *real* ip addresses of the servers that had to access the docker containers, which were ipv6. My first trials with the setup was over v4, but when all worked and I switched to v6, I must have missed the errors. Or rather, the error probably only appeared the second time I ran puppet, which was this morning. The error was thrown by some consistency check done by the module, which compared the actual iptables rules and the entries in the firewalld xmls, and had not fully taken into account ipv6 rules.

Now that I know where the issue lies (and even more or less which lines in the puppet module), I can go to sleep and tomorrow try to fix the module and make a PR. Unless the maintainer already fixed it of course :-)

Thanks for your time, Adam!

### Update

I looked at the code and saw the potential for a quick fix. Not an hour later the PR was submitted! Gonna have a good night's sleep after all :-)
