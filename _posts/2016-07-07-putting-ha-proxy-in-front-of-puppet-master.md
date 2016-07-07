---
layout: post
title: "Putting HA Proxy in front of Puppet Master"
date: "2016-07-07 15:53:04 +0200"
author: jovandeginste
comments: true
tags:
- puppet
- haproxy
---

Another big todo can now be scratched off my list: have a load-balanced puppet master setup. We already had a high-available setup with failover via keepalived, but this didn't work "perfectly": in-place upgrading the puppet master didn't failover first, and HA doesn't balance the load...

I tried some time ago with Apache as a Reverse Proxy since I know Apache best, but I got caught up with the client certificates. I never got it really working, so I gave up then. Today I wanted to get it up and running again, this time with [haproxy](http://www.haproxy.org/). I based my configuration on [this blog post](http://www.balldawg.net/index.php/2010/12/haproxy-keepalived-puppet/), but changed some important parts.

We are still using keepalived for HA, and I don't like setting `net.ipv4.ip_nonlocal_bind=1`, so I have a different solution that I use for many setups (including my HA MySQL setup): I use `iptables` to port forward traffic from the keepalived-managed ip to server's fixed ip.

I also add an extra `hosts` entry on each cluster member to refer to his own and to the other members in a general way, intelligently named `this_puppet` and `other_puppet`. This means I can copy the `haproxy.cfg` between the cluster members without alteration as long as both those `hosts` entries are correctly set:

On clustermember1:
```
127.0.0.1 this_puppet
10.0.0.1 _my_service_ip_
10.0.0.2  other_puppet
```

On clustermember2:
```
127.0.0.1 this_puppet
10.0.0.2 _my_service_ip_
10.0.0.1  other_puppet
```

Why the difference between `this_puppet` and `_my_service_ip_`? Because the puppet master runs in Docker containers (multiple containers per cluster member) and forwarding to the "public" ip doesn't work that easy. Forwarding to `127.0.0.1` works just nice, but we also need to listen to the public ip on both members.

The configuration file `haproxy.cfg` has this then (partial):
```
#---------------------------------------------------------------------
# main frontend which proxys to the backends
#---------------------------------------------------------------------
frontend  puppet
  bind _my_service_ip_:8141
  mode tcp
  default_backend puppet0

#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend puppet0
    balance     roundrobin
    option ssl-hello-chk
    # container 1:
    server clustermember1 this_puppet:18140 check maxconn 5
    server clustermember2 other_puppet:18140 check maxconn 5
    # container 2:
    server clustermember1b this_puppet:18141 check maxconn 5
    server clustermember2b other_puppet:18141 check maxconn 5
    # container 3:
    server clustermember1c this_puppet:18142 check maxconn 5
    server clustermember2c other_puppet:18142 check maxconn 5
```

Now we have a haproxy on each cluster member listening on the server's own ip `_my_service_ip_`, port 8141, forwarding and balancing requests over 6 puppet masters (3 containers on each of two cluster members). We limit the number of requests per puppet master to 5 so we don't overload it.

The final part is the `keepalived` and `iptables` configuration, which are fairly simple:

The `keepalived` partial:

```
vrrp_instance puppet {
  interface eth1
  state EQUAL
  virtual_router_id 50
  priority 100
  nopreempt
  smtp_alert
  authentication {
    auth_type PASS
    auth_pass s3cr3t
  }
  virtual_ipaddress {
    10.0.0.10/24 # The ip address referred to as 'puppet'
  }
}
```

And an `iptables` rule:
```
-I PREROUTING -t nat -p tcp -d 10.0.0.10 --destination-port 8141 \
  -j DNAT --to-destination _my_service_ip_:8141
```

Now that everything is in place, I run `puppet agent --test --noop` on a bunch of servers in parallel to see if it works. The servers all give the expected results (some changes are pending), and I see the connections being balanced over all 6 containers. I found some pointers to verify this [on this great site](https://makandracards.com/makandra/36727-get-haproxy-stats-informations-via-socat). I wrote a little Ruby script show the relevant numbers:

```ruby
require 'socket'

while true
  socket = UNIXSocket.new("/var/lib/haproxy/stats")

  socket.puts("show stat")

  data = socket.read.split("\n")
  heading = data.shift.gsub(/^# /, '').split(',')

  relevant_keys = %w[status scur smax stot]

  system("clear")
  puts " " * 10 + "Updated at #{Time.now.to_s}"
  puts
  data.each do |line|
    info = Hash[heading.zip(line.split(','))]
    name = [info['pxname'], info['svname']].join('/')

    relevant_info = info.select{|key, value| relevant_keys.include?(key)}.map{|key, value| "#{key}: #{value}"}
    puts "#{name}: #{relevant_info.join(', ')}"
  end
  sleep 1
end
```

Run the script and restart some containers, start some puppet agents, etc. Great to see it happen :-)
