---
layout: post
title: "My first custom puppet function"
date: "2016-04-20 14:05:11 +0200"
comments: true
tags:
- puppet
---

This experience turned out to be a lot harder than expected. Not writing some custom function - that is dead easy. Getting done what I wanted was very hard :-)

**What I had:** data in hiera in a nice to maintain way

**What I needed:** resources for a puppet module

**What I had to do:** convert the data from hiera to data useful as parameters for `create_resources` e.a.

While usually glueing hiera to puppet resources is not the most complex thing, I had a caveat: one particular `hiera_hash` had to be filtered and restructured and passed as a parameter for another Puppet resource.

## What I had (simplified)

```yaml
profile::firewalld::zones:
  internal:
    description: Interface for management
    short: Interface for management
  public:
    description: Interface for public access
    short: Interface for public access

profile::firewalld::rich_rules:
  allow_from_server_1
    zone: public
    family: ipv6
    source:
      address: $IP_FROM_SERVER_1
    port:
      portid: 1234
      protocol: tcp
    action:
      action_type: accept
  allow_from_server_2
    zone: public
    family: ipv6
    source:
      address: $IP_FROM_SERVER_2
    port:
      portid: 1234
      protocol: tcp
    action:
      action_type: accept
```

## What I needed

```yaml
profile::firewalld::zones:
  internal:
    description: Interface for management
    short: Interface for management
  public:
    description: Interface for public access
    short: Interface for public access
    rich_rules:
      - family: ipv6
        source:
          address: $IP_FROM_SERVER_1
        port:
          portid: 1234
          protocol: tcp
        action:
          action_type: accept
      - family: ipv6
        source:
          address: $IP_FROM_SERVER_2
        port:
          portid: 1234
          protocol: tcp
        action:
          action_type: accept
```

## What I had to do

The trick was thus for each `profile::firewalld::zone`, creating a copy of the `hiera_hash` `profile::firewalld::rich_rules` that:

* contains only the elements for that zone (based on the `zone` keys from the values)
* has not the `zone` keys from the values of `profile::firewalld::rich_rules`
* has not the key names (`allow_from_server_x`)

I tried with default Pupppet 3 manifest syntax but found no way to get it done. So I decided to build my first custom function (`rich_rules_for($zone)`) - I am well versed in Ruby, so technically this should be no problem. However, I found no clear information on how to retrieve any type of resources from inside a custom function, or how to return the results to be used in other resources. Thus I hit a few obstacles along the way.

First step was easy: extend the `manifests/firewalld/zone.pp` manifest:

```puppet
define profile::firewalld::zone (
  [...]
) {
  [...]
  $rich_rules = rich_rules_for($name)

  ::firewalld::zone { $name:
    [...],
    rich_rules => $rich_rules,
  }
}
```

I also created a class to get the rich rules from hiera and a definition to hold a rich rule.

The file `manifests/firewalld/rich_rules.pp`

```puppet
class profile::firewalld::rich_rules {
  $rich_rules = hiera_hash('profile::firewalld::rich_rules', {})

  create_resources('profile::firewalld::rich_rule', $rich_rules)
}
```

The file `manifests/firewalld/rich_rule.pp`

```puppet
define profile::firewalld::rich_rule (
  $zone,
  [...]
) {
  # Yes, the body of the definition is empty - it is meant purely as
  # a holder for data
}
```

Now finally the hard part. I will put comments inside the code to explain why I did some things.

The file `lib/puppet/parser/functions/rich_rules_for.rb`

```ruby
module Puppet::Parser::Functions
  newfunction(:rich_rules_for, :type => :rvalue) do |args|
    zone = args[0] # I expect a single parameter, the zone
    result = [] # This will contain the filtered and converted rules for the zone
    excludes = [:zone] # These are the keys to be removed from every item

    # To get all resources in the catalog, use catalog.resources
    # I did not find a way to get only resources of a specific type, so I had to
    # 'manually' filter all resources and select only the relevant ones. At the
    # same time, I could filter for the zone.
    catalog.resources.select{|r|
      r.type == 'Profile::Firewalld::Rich_rule' and
        r['zone'] == zone
    }.each do |rule|
      # We will build a new element to add to the results
      clean_rule = {}

      # We iterate over all the keys/values in the original element and decide
      # whether/how to add it to the new element. 'to_hash' gives you all the
      # properties from the manifest or from hiera as a hash:
      # {
      #    :key1 => valueA,
      #    :key2 => valueB,
      # }
      rule.to_hash.each do |key, value|
        # Here we get rid of unwanted keys
        unless excludes.include?(key)
          # And we need to convert the symbols from 'to_hash' to strings again,
          # otherwise the puppet provider gets confused (:key1 != 'key1')
          clean_rule["#{key}"] = value
        end
      end

      # Then we add the new element to the list of results
      result << clean_rule
    end

    # And finally, we return the list of results
    return result
  end
end
```

I hope anyone is saved a lot of research now - I found no clean cut examples to do something similar to this...
