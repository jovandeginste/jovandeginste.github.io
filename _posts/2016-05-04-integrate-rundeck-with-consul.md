---
layout: post
title: "Integrate Rundeck with Consul"
date: "2016-05-04 09:38:40 +0200"
comments: true
tags:
- rundeck
- consul
- ruby
---

Last week I [deployed Rundeck]({% post_url 2016-04-29-puppet-mcollective-rundeck %}) and this week I [integrated it with PuppetDB]({% post_url 2016-05-02-rundeck-and-puppetdb-use-a-gem %}). I'm not sure yet if it will be very useful, but as a proof of concept if nothing else I wanted to integrate Rundeck with Consul. This meant having Consul as a node resource for Rundeck, so I could select nodes based on the Consul services and tags they were offering.

A quick search revealed [this Github project](https://github.com/saymedia/rundeck-consul-resource-model), which more or less worked. However, I had to provide a service as paramter, while what I wanted was a full list of nodes with their tags. Couldn't be too hard, so I set off in Ruby - Golang, while nice and everything, was not the right tool for a PoC.

Two Consul REST entrypoints are important:

1. `/v1/catalog/nodes`: gives a list of all nodes with some metadata
2. `/v1/catalog/node/$server`: gives the same metadata plus all services and tags for one node

I could iterate over the nodes from the first entrypoint, and for every node get the list of all services using the second entrypoint.

For every node, a list of tags was built combining each service on that node with the tags for that service, and adding a tag-less service. Eg. if node  `nodeX` had service `serviceA` with no tags, and service `serviceB` with tags `t1` and `t2`, this would result in the following list of Rundeck tags:

```yaml
nodeX:
  tags:
  - serviceA
  - serviceB
  - serviceB:t1
  - serviceB:t2
```

The node's hostname would be it's Consul `address` field.

For the output, I decided to give a choice between yaml and json (and forget about xml).

The resulting code: [Github Gist](https://gist.github.com/jovandeginste/4c7da1392e52bc985c75ef4f872c7843)

```ruby
# !/usr/bin/env ruby

require 'getoptlong'
require 'net/http'
require 'json'

server = 'localhost:8500'
format = 'yaml'

opts = GetoptLong.new(
        [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
        [ '--server', '-s', GetoptLong::REQUIRED_ARGUMENT ],
        [ '--format', '-f', GetoptLong::REQUIRED_ARGUMENT ],
)

opts.each do |opt, arg|
        case opt
        when '--help'
                puts <<-EOF
Usage: #{$0} [--server|-s server[:port]] [--format|-f yaml|json]

Defaults:
        server: #{server}
        format: #{format}

                EOF
                exit
        when '--format'
                case arg
                when 'yaml', 'json'
                        format = arg
                else
                        exit 1
                end
        when '--server'
                server = arg
        end
end

class Object
        def downcase_keys
                self
        end
end

class Hash
        def downcase_keys
                self.inject({}) do |hash, kv|
                        key, value = kv
                        hash[key.downcase] = value.downcase_keys
                        hash
                end
        end
end


def get_nodes(server)
        nodes_url = "http://#{server}/v1/catalog/nodes"
        uri = URI(nodes_url)
        return JSON.parse(Net::HTTP.get(uri)).map(&:downcase_keys)
end

def get_node(server, node)
        node_url = "http://#{server}/v1/catalog/node/#{node}"
        uri = URI(node_url)
        return JSON.parse(Net::HTTP.get(uri)).downcase_keys
end

result = {}

get_nodes(server).each do |node|
        name = node['node']
        node_data = get_node(server, name)
        result[name] = node
        result[name]['hostname'] = node['address']
        result[name]['services'] = node_data['services']
        result[name]['tags'] = node_data['services'].collect{|key, value|
                s = value['service']
                tags = value['tags'] || []
                [s] + tags.map do |tag|
                        "#{s}:#{tag}"
                end
        }.flatten.compact.uniq.sort
end

case format
when 'yaml'
        require 'yaml'
        puts result.to_yaml
when 'json'
        puts result.to_json
end
```
