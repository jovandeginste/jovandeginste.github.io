---
layout: post
title: "Turning on ACL's in our Consul cluster"
date: "2016-05-04 18:14:19 +0200"
comments: true
tags:
- consul
---

For a long time, having ACL's in our Consul cluster was on my todo-list. Now I can finally scratch it off!

We have been running Consul for about a year now. The first few weeks I screwed it up from time to time, and sometimes it was on purpose (eg. when I enabled gossip encryption - another necessary step). This time I managed to screw up our quality cluster (which is not a big issue), but the production cluster had not a moment of downtime or (unwanted) diminished usability. Unwanted, because the whole plan was to diminish the usability by limiting access :-)

Steps taken:

1. enable ACL's in general, but be permissive
2. give "Anonymous" the necessary access so that current applications will not be hindered
3. generate some tokens for specific applications that will need extra rights (and configure those applications to use the tokens)
4. switch to default policy "deny"

### Step 1: enable ACL's

This was the most risky thing - it involved changing crucial configuration and restarting all Consul servers. This has proven to be a hazard in the past, so I proceeded with great care. My screwing up the quality cluster was entirely my own fault, by the way. I was really not careful here. I learned my lesson again :-)

Easiest way to turn on ACLS turned out to be: add a new json file in Consul's data dir. We have the datadir in `/usr/share/consul/`, so I let Puppet add a file `/usr/share/consul/master.json`:

```json
{
  "acl_datacenter":"mydc",
  "acl_default_policy":"allow",
  "acl_down_policy":"allow",
  "acl_master_token":"398073a8-5091-4d9c-871a-bbbeb030d1f6"
}
```

The master token was self-generated, using Linux's `uuidgen` (I generated a new one for this post, by the way ;-))

When all servers had this config file, I restarted the Consul server on each server separately and verified that it came back and joined the cluster. The ACL's only kicked in when the last server was restarted, and then I got no longer the "ACL's are disabled" message on `http://consul.service.consul:8500/ui/#/mydc/acls`, but a `Access Denied`.

Now I added the master ACL token in the field at `http://consul.service.consul:8500/ui/#/mydc/settings`, clicked back to ACL and behold!

### Step 2. give "Anonymous" the necessary access

This meant first learning about the syntax and workings of [HashiCorp's Configuration Language](https://www.consul.io/docs/internals/acl.html). But the basics were simple. I decided to leave service registration open and start limiting the kv store. I allowed read access to everyone, and anonymous write access only to a few specific toplevel keys:

```
key "" {
  policy = "read"
}
key "lock/" {
  policy = "write"
}
key "cronsul/" {
  policy = "write"
}
key "docker-swarm/" {
  policy = "write"
}
service "" {
  policy = "write"
}
```

I could copy those rules over to the production cluster when I started with those servers.

### Step 3. generate some tokens

Ok, truth be told I did not have many applications that I could convert to use tokens. I did have one, which manages the firewall rules between Docker containers, so that would be the test case.

I also generated management tokens for trusted colleagues, so that if something went very wrong, they could handle the first problems themselves.

### Step 4. switch to default policy "deny"

Now was the big moment. I changed the puppet configuration to "deny" instead of "allow", which basically resulted in this file: `/usr/share/consul/master.json`:

```json
{
  "acl_datacenter":"mydc",
  "acl_default_policy":"deny",
  "acl_down_policy":"deny",
  "acl_master_token":"398073a8-5091-4d9c-871a-bbbeb030d1f6"
}
```

Again, I restarted every server and verified that it joined the cluster. Then I verified that all "normal" functions continued working: services were registering, and small some scripts that wrote data in the kv store (eg. `cronsul`) kept working. Great. Now the firewall-management tool. I had not added anything about it in the Anonymous rules, so read access remained. I verified this by running the `show_firewall` script. This shows what is currently stored in the kv store, and worked.

Next step, I explicitely denied Anonymous access to the key `firewall-rules`. Rerun the script and I got "Permission Denied". Perfect!

What I was after was allow reading of, but limit writing to `firewall-rules/*`. So I re-allowed Anonymous read access, and now added the (obvious) rule to the token that I had generated earlier:

```
key "firewall-rules/" {
  policy = "write"
}
```

At this point, I tried if I was effectively blocked from changing the firewall rules in the kv store. I added a nonsense rule and tried to apply it, and was denied access. Good.

The firewall management script uses the `Faraday` gem to do the REST queries, so I added the token as a instance variable in the library and used it in the necessary places:

```ruby
class ConsulFirewallManager
	<...>

  def conn
    @conn ||= Faraday.new(:url => self.consul_server)
  end

  def delete_rules(rules)
    rules.map do |key, value|
      response = conn.delete(
        [
          "/v1/kv",
          self.root_key,
          key,
        ].join("/") + "?token=#{self.acl_token}"
      ).body
      response
    end
  end

  def set_rules(rules)
    rules.map do |key, value|
      response = conn.put(
        [
          "/v1/kv",
          self.root_key,
          key,
        ].join("/") + "?token=#{self.acl_token}", value
      ).body
      response
    end
  end

  def fetch_rules
    response = conn.get { |req|
      req.url [
        "/v1/kv",
        self.root_key,
      ].join("/"), :recurse => 1, :token => self.acl_token
    }.body
    return nil unless response
    return JSON.parse(response)
  end

	<...>
end
```

(`fetch_rules` was not really necessary, since the world had read access for now, but I might want to change this in the future)

I passed the token to the library, and behold! I could change the firewall rules again. Mission accomplished.
