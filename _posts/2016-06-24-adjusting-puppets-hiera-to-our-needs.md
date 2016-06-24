---
layout: post
title: "Adjusting Puppet's hiera to our needs"
date: "2016-06-24 16:59:59 +0200"
author: jovandeginste
comments: true
tags:
- puppet
- hiera
- vault
- eyaml
---

Last week I attended HashiConf EU, and if I had one take-away, it was that we needed to start using Vault. So I immediately started by learning Vault's interface, and trying to use `hiera-vault`. However, I hit quickly hit some obstacles that appeared hard to overcome. Then I learned to write my first hiera-backend (and got a bit carried away...)

## The problem

The problem is essentially explained by [this github issue on hiera-vault](https://github.com/jsok/hiera-vault/issues/22). In short:
* some backends are fast, and some are slow, and Vault is a slow one
* every hiera lookup essentially goes to every backend *(string lookups are special)*
* every hiera lookup is usually done for every entry in the `:hierarchy:` *(string lookups are special)*
* not only explicit calls to the `hiera` functions trigger lookups *(see [this useful feature called "automatic parameter lookup"](https://docs.puppet.com/hiera/3.1/puppet.html#automatic-parameter-lookup), it also happens for every class parameter.)*

Vault is a slow backend, because every lookup to Vault is a separate REST call including SSL verification and some form of authentication.

I did a count on the total number of lookups via hiera for a number of our servers (different roles), and had an average of >600 separate lookups. We have at this time about 30 lines in our `:hierarchy:` (complicated situation), which means for one server on average 18000 queries may happen per hiera backend. Just adding Vault to our list of backends (without even having data yet) increased the catalog computation time from about 20 seconds to about 10 minutes. I don't think anybody would think this is a reasonable timing...

## The solution

First (obvious) solution was to continue to use `eyaml` as our secret backend. It had worked for us, but it does have its drawbacks. And we really wanted to try out Vault :-)

[An other solution](https://github.com/jsok/hiera-vault/pull/10) being worked on in the hiera-vault project was to replace `hiera*` function calls by `hiera_vault*`, and disable automatic lookup to Vault. This means you have to change your Puppet manifests, and was no solution for Puppet's automatic parameter lookup.

I thought it should be possible to determine for any key at lookup time where it should be found. In my mind, I thought it might even be more clear to have the first backend (yaml files) explicitly state that the value for some key was somewhere else. Basically, specify in the yaml files where a value can be found (if not in the yaml files).

So we started looking into hiera's [interpolation methods](https://docs.puppet.com/hiera/3.1/variables.html), but sadly [they were frozen](https://github.com/puppetlabs/hiera/blob/master/lib/hiera/interpolate.rb#L22:L27). Simply extending or overriding them seemed not possible, and PR's were probably going to be tricky. A somewhat different approach was to do something similar to hiera-eyaml: retrieve the value from the yaml file, and [if it matches some regex](https://github.com/TomPoulton/hiera-eyaml/blob/master/lib/hiera/backend/eyaml_backend.rb#L93-L95), do something with it before returning it.

So we created a new hiera backend that would first retrieve the value from the yaml file. If the value matches `backend[somestring]`, it would defer the lookup call to the hiera-backend `somestring`. We mimicked parts of hiera, parts of hiera-eyaml, and after some experimentation we had a working setup with multiple "secundary" backends that were only called when referred to from the yaml files. We called this the `hiera-router` (code is on [github](https://github.com/jovandeginste/hiera-router) and on [rubygems](https://rubygems.org/gems/hiera-router))

## Something more

When I implemented our solution in our production Puppet setup, I realized that I could fix something else that had been bothering me for a long time: access to encrypted secrets when testing the Puppet setup. Or rather: no access to those secrets, but to something "equivalent". I run a large number of tests on our Puppet setup before promoting any changes to production, and the last chapter of tests is compiling actual catalogs for some real servers (without deploying them). This catches many logical errors that simple syntax checking would not detect, or mismatches in data type (eg. between Puppet and hiera).

With eyaml, the solution for this was easy: switch to yaml, and you will get the encrypted string as a result (which should be fine in most cases). With Vault this became a different thing: I could/should not access the production Vault data, so my options were:
* set up a separate Vault cluster with a parallel data structure
* set up a parallel data structure in the production Vault at a different path (with a different token)
* disable the Vault backend in hiera

Options 1 and 2 were a lot of work and maintenance (every new secret had to be added twice). Option 3 meant I would have to have a dummy entry for every secret in the yaml files too. What I really needed was a way to automatically return valid data when a lookup occurred. So we created a [mock backend](https://github.com/jovandeginste/hiera-mock) for hiera: it would optionally have a single yaml file as source, and would render random strings for lookups that didn't find a match in the single yaml file. It would respond accordingly to the different resolution types by generating a hash or array of random strings, and would prefix every string with "mocked-" so that it was obvious in Puppet's diff output what happened.

The mock backend could be substituted for every other backend, but was especially useful in combination with the hiera-router. Only a slight issue there: you wrote the name of the backend in the yaml files at every location where you would want to do a lookup to the backend. This would mean that to replace `vault` by `mock`, you would have to do a big `sed` across all your yaml files

Basically:

```
find hieradata/ -type f -name '*.yaml' -exec sed 's/backend\[vault\]/backend\[mock\]/' {} +
```

This was not what I wanted, so I added some special functionality to the hiera-router: it now supports "renaming" of backends. You refer to any backend in the yaml files by using a name of your choice, and define in the hiera-router configuration for each backend what it really is. You can omit this definition, at which point the router will assume the name is the correct name.

This means I no longer need to `sed` every yaml file, but I can simply change my `hiera.yaml` config and have something like this:

```yaml
:router:
  :datadir: ./hieradata/
  :backends:
    - vault
  :vault:
    :backend_class: vault
:mock:
  :datafile: ./tests/mockdata.yaml
:vault:
  :ssl_verify: false
  :addr: https://active.vault.service.consul:8200
  :token: my-token
  :mounts:
    :generic:
      - secret/puppet
```

This will call `hiera-vault` for value `backend[vault]`, but when I change the single line `:backend_class: vault` to `:backend_class: mock`, it will call `hiera-mock` and thus return random data.

Obviously this is not a perfect solution, but it suits most of my needs. I'm open for (constructive) feedback on this (eg. you can open issues on both projects)
