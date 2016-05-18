---
layout: post
title: "Rundeck and PuppetDB - use a gem"
date: "2016-05-02 13:14:20 +0200"
author: "Jo Vandeginste"
comments: true
tags:
- puppet
- puppetdb
- rundeck
---

After [deploying Rundeck]({% post_url 2016-04-29-puppet-mcollective-rundeck %}), I set out a few todo's for later. One of those was switching to the [puppetdb_rundeck gem](https://github.com/opentable/puppetdb_rundeck). After some manual testing, I found out that it actually worked as a drop-in replacement for the scripts that I had now. It even fixed the hostname issue. Only one drawback: it did not populate the tags automatically with the classes. On the other hand, that meant that I could customize the tags!

First things first: use the gem instead of the scripts I had. I could remove a lot of the code from my puppet profile for Rundeck. I only kept the Systemd unit file (slightly modified) and added a package requirement:

```puppet
$sinatra_application = 'puppetdb-rundeck'
$sinatra_entrypoint = '/usr/local/bin/puppetdb_rundeck'
$sinatra_parameters = '--pdbhost localhost --pdbport 8080 --port 8144'

file { "/etc/systemd/system/${sinatra_application}.service":
	ensure => file,
	content => template('profile/sinatra.service.erb');
}

service { $sinatra_application:
	ensure  => running,
	enable  => true,
	require => [File["/etc/systemd/system/${sinatra_application}.service"], Package['puppetdb_rundeck']],
}
```

The content of `templates/sinatra.service.erb`:

```puppet
[Unit]
Description=<%= @sinatra_application %> (sinatra)

[Service]
ExecStart=<%= @sinatra_entrypoint %> <%= @sinatra_parameters %>
ExecStop=/bin/kill -TERM $MAINPID
```

The new service was listening on the old service's port, but the url was slightly different. This was the new url to put as the Rundeck project's resource source: `http://localhost:8144/api/yaml`

Refreshing the node list gave me what I expected: the list of nodes, but without tags. Now providing some tags. In the same puppet module, I added a custom fact `tags`, which would be a comma-separated list of all the tags I wanted to have per node. I would use the classes like the old script did, and add some very specific ones. Since I use the "roles and profiles" pattern (and profiles mapped to classes), I wanted to add roles as tags. I went a little further with this, since I have also subroles, and servers have tiers too (test, quality and production). This is the full code:

File: `lib/facter/tags.rb`

```ruby
Facter.add(:tags) do
  setcode do
    begin
      Facter.hostname
    rescue
      Facter.loadfacts()
    end

    hostname = Facter.value('hostname')

    classes_txt = "/var/lib/puppet/state/classes.txt"

    if File.exists?(classes_txt) then
      class_tags = File.read(classes_txt).split("\n").map do |line|
        line = line.chomp.to_s
      end - ["settings", "#{hostname}"]
    else
      class_tags = []
    end

    auto_tags = [
      Facter.value(:tier),
      Facter.value(:role),
      [Facter.value(:role), Facter.value(:subrole)].join('/'),
    ].compact

    tags = (class_tags + auto_tags).uniq.sort.join(",")
    tags
  end
end
```

Every puppet node running the new code will now publish a list of tags as a fact, which will be picked up by Rundeck.
