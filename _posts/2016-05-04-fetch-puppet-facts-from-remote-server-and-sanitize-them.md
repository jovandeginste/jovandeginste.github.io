---
layout: post
title: "Fetch (puppet) facts from remote servers, sanitize them and store them locally"
date: "2016-05-04 13:26:58 +0200"
comments: true
tags:
- ruby
- puppet
- facter
---

This code will fetch `facter` facts from a list of remote servers (in parallel), and save them as yaml files in a local directory. The facts that happen to change are either stripped or set to some fixed value.

Requires the gem `parallel`

```ruby
#!/usr/bin/env ruby

require 'yaml'
require 'parallel'

user = ENV['USER']

domain = 'my.domain.org'
fact_root = './facts-per-server'

ssh_user = 'root'

servers = File.read('servers').split("\n").compact.map{|s| s.gsub(/#.*/, "")}.map(&:strip).reject(&:empty?)

# Some facts always change and are probably useless in a static dump
bad_facts = %w[
  swapfree_mb swapfree memoryfree_mb memoryfree
  uptime uptime_seconds uptime_hours uptime_days system_uptime
]

Parallel.each(servers, :progress => "Updating facts for #{servers.size} servers") do |server|
  fqdn_server = "#{server}.#{domain}"
  server_file = "#{fact_root}/#{server}.yaml"

  # We request the puppet facts from the remote server (exported as yaml)
  raw = %x[ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q -tt -l #{ssh_user} #{fqdn_server} 'sudo facter -p -y 2> /dev/null']
  facts = YAML.load(raw)

  # Get rid of the bad facts
  facts.reject!{ |k| bad_facts.include?(k) }

  # Get rid of some extra facts containing 'veth' (Docker...)
  facts.reject!{ |k| k.match(/^(macaddress|mtu)_veth/) }

  facts.update(facts){ |k, v|
    # Get rid of veth-interfaces (Docker...)
    if v.respond_to?(:gsub) and v.match(/veth/)
      v = v.gsub(/,veth\h+/, "").gsub(/^veth\h+,/, "")
    end
    # Also fix docker0's mac address, since this changes every time the daemon is restarted
    if k == "macaddress_docker0"
      v = "aa:11:22:33:44:55"
    end
    # Trim double quotes
    v.inspect.sub(/^"/, '').sub(/"$/, '')
  }

  File.write(server_file, facts.to_yaml)
end

# For some reason, the terminal is screwed when returning; this will fix this:
%x[stty sane]
```
