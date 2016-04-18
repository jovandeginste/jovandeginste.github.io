---
layout: post
title:  "FirewallD doesn't handle xml correctly?"
categories: firewalld
comments: true
---

My direct rules for firewalld (stored in direct.xml) seemed not to be working as they should.
I generate the xml and tell firewalld to reload it's config. Apparently, I was too liberal...

```# cat /etc/firewalld/direct.xml```

```xml
<?xml version='1.0' encoding='UTF-8'?>
<direct>
  <rule ipv='ipv6' table='filter' chain='FORWARD_direct' priority='0'>
    -m set --match-set rabbitmq-iss-t-all src -m set --match-set
    rabbitmq-iss-t-local dst -j ACCEPT
  </rule>
</direct>
```

```
# firewall-cmd --direct --get-all-rules
ipv6 filter FORWARD_direct 0
```

Not ok...

The rule is not working :( Let's add it 'like it should', through firewall-cmd:

```
# firewall-cmd --permanent --direct --add-rule ipv6 filter FORWARD_direct 0 -m set --match-set rabbitmq-iss-t-all src -m set --match-set rabbitmq-iss-t-local dst -j ACCEPT
success
```

```# cat /etc/firewalld/direct.xml```

```xml
<?xml version="1.0" encoding="utf-8"?>
<direct>
  <rule priority="0" table="filter" ipv="ipv6" chain="FORWARD_direct">-m set --match-set rabbitmq-iss-t-all src -m set --match-set rabbitmq-iss-t-local dst -j ACCEPT</rule>
</direct>
```

Same rule, but the rule is entirely on a single line

```
# firewall-cmd --direct --get-all-rules
ipv6 filter FORWARD_direct 0 
ipv6 filter FORWARD_direct 0 -m set --match-set rabbitmq-iss-t-all src -m set --match-set rabbitmq-iss-t-local dst -j ACCEPT
```

This seems to work now - first line is probably still loaded from earlier since I didn't do full restart of firewalld.

Conclusion: the xml should be more strict. I updated the puppet module that generates the xml and told it that lines
can be 1000 characters long - safe for now :-)