---
layout: post
title: "Learning to use Docker Swarm"
date: "2016-04-18 18:50:30 +0200"
comments: true
categories: docker
---

Today I set out to finally learn to use (read: correctly deploy) Docker Swarm. It had to be repeateable (puppet!) and scaleable.

After learning that there are ipv6-related bugs in our version (1.9.1), I used ipv4 connections. Firewall had to be opened (slaves connect to master and vice versa) and then I saw the cluster!

Next step was putting it in puppet. Thangs to Gareth, this was easy: <https://github.com/garethr/puppet-docker-swarm-example>

I only needed to make some profiles and couple them to nodes. Then abstrahate the data in hiera. I use the following keys:

```yaml
profile::docker::swarm::cluster_name: ...
profile::docker::swarm::docker_port: ...
profile::docker::swarm_manager::cluster_name: ...
profile::docker::swarm_manager::swarm_manager_port: ...
```

This enables me to use our single Consul cluster to coordinate any number of Swarm clusters by setting the `cluster_name` key.

After having everything in Puppet, I could use ipv6 because I didn't need to specify any ip's anymore (puppet opened the ports correctly and made sure the swarm configuration was in sync). For this I had to allow the docker ipv6 ranges (and not the host's ipv6 port).
