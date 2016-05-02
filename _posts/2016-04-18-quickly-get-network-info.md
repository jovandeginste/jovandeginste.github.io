---
layout: post
title: Quickly get network trace information from a server
tags: network
comments: true
---

Today I was asked for some information concerning a server that could not reach its default gateway `fe80::1` over `eth1` (and the same for a working server).

Instead of searching for the same or similar commands every time, I will now document a oneliner :-)

```bash
ssh $server 'set -x;
	ip a show dev eth1;
	tcpdump -e -i any -nnnn -vv icmp6 &
	sleep 1;
	ping6 -c 2 fe80::1%eth1;
	sleep 1;
	kill %%'
```

Notes:

* I start tcpdump first in the background so the sequence of commands can continue, later I kill it
* the sleeps are probably not necessary, but included just in case there is a delay in the packets
* `set -x` prints out all commands before they are executed - good to copy/paste and mail it to someone since they will now know the parameters
* `ip a show dev eth1`: gets important starting data about `eth1` (ip addresses and mac address)
* tcpdump flags:
	* `-e`: show mac addresses and packet direction (In, Out)
	* `-i any`: capture traffic on any interface (verify for asymmetric routing)
	* `-nnnn`: don't resolve any ips (not really useful and potentially confusing for local stuff)
	* `-vv`: be more verbose
	* `icmp6`: I'm only intereseted in pings over ipv6
* ping flags:
  * `-c 2`: I send two pings out, kind of a control; don't leave the parameter out, because by default ping will ping forever
	* `fe80::1`: this is our (local) default gateway on any ipv6 network
	* `eth1`: I'm pinging a link-local address and want to diagnose traffic over `eth1`
		* if you didn't know about the 'ip%dev' syntax, Google it...

* There is more you may want to throw in, depending on the circumstances; these are useless for a link-local address:
	* `ip ro get $ip`: show the gateway and source ip that will be used to reach `$ip`
	* `traceroute -n $ip`: document the intermediate hops (gateways)

