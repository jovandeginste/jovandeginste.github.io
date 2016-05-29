---
layout: post
title: "Migrating internal documentation from MediaWiki to ReadTheDocs"
date: "2016-05-29 18:26:54 +0200"
comments: true
published: false
tags:
- MediaWiki
- ReadTheDocs
---

I like MediaWiki and WikiPedia as a consumer. I used to like it as a producer when I started documenting procedures at my job - let's say about 10 years ago now. But very quickly, I started avoiding it for documentation, and the result was that my documentation was lacking and/or all over the place (depending on the project). As a proof of concept, I wanted to deploy a ReadTheDocs site and see how feasible it is to migrate our current MediaWiki content to it.

For extra credits, I wanted to preserve the change history in the documentation. I would try to create git history as if every wiki revision was a single commit. Input for ReadTheDocs would be `reStructuredText` or `Markdown` (not decided yet).

Instead of a big bang attempt, I prepared some migration steps:

1. export MediaWiki (including all revisions) to a single xml file using its built-in tool
2. extract the single xml into separate yaml files per revision
3. convert the Wiki syntax in the yaml files to `rst` or `md` and save it in a new yaml file
4. generate `git commit` from every 2nd step yaml file in chronological order.
   a. overwrite the respective file with the new content
   b. commit with author's name and mail address, using the comment from the revision as commit message
5. load the constructed git repository into a clean ReadTheDocs installation (using Docker of course)

## 1. export MediaWiki (including all revisions) to a single xml file using its built-in tool

MediaWiki has a helpful tool to export the whole set of articles to a single xml file. I used it and let it include file metadata along the way:

```
php dumpBackup.php --full --include-files > ~/wikidump.xml
```

This took a while, but had a clear progress. When the dump was complete, it was time to see what we got!

The structure of this xml is easy. First there are the `pages` at the highest level:

```xml
<mediawiki ...>
  <siteinfo>...</siteinfo>
  <page>...</page>
  <page>...</page>
  ...
</mediawiki>
```

Every page had some metadata, and a number of revisions each with its own metadata:

```xml
<page>
  <title>Main Page</title>
  <ns>0</ns>
  <id>1</id>
  <revision>...</revision>
  <revision>...</revision>
</page>
```

```xml
<revision>
  <id>1</id>
  <timestamp>2008-08-01T12:58:22Z</timestamp>
  <contributor>
    <username>TheUsername</username>
    <id>0</id>
  </contributor>
  <comment>Replacing page with '...'</comment>
  <text xml:space="preserve" bytes="911">
    ...
  </text>
  <sha1>theSha1</sha1>
  <model>wikitext</model>
  <format>text/x-wiki</format>
</revision>
```

The text inside every revision contained the whole text after that revision. The user names where just that, no metadata on the user (which was reasonable). I wanted the full name and mail addresses of the users, so I launched a query in the MySQL database behind our MediaWiki and created a `yaml` file:

```sql
select concat(user_name, ':\n  name: ', user_real_name, '\n  mail: ', user_email) from wiki.wiki_user where user_email != '';
```

Launch it like this to have it ready in a `yaml` file:

```bash
mysql -u root -p -s -r -N -e "select concat(user_name, ':\n  name: ', user_real_name, '\n  mail: ', user_email) from wiki.wiki_user where user_email != '';" > users.yaml
```

This will give you a file with this structure:

```yaml
user1:
  name: User Name1
  mail: User.Name1@domain.com
user2:
  name: User Name2
  mail: User.Name2@domain.com
```

This allows me to lookup users from revisions on the fly.

## 2. extract the single xml into separate yaml files per revision

The big xml was - well, big: >700 MB. This means that parsing it as xml takes a while. I wrote a small Ruby script (`xml2yaml.rb`) to extract the necessary information from `wikidump.xml` and write it to separate yaml files `./yaml/mw/year/month/mday/timestamp_projectid_revisionid.yaml`:

```ruby
require 'xmlsimple'
require 'yaml'
require 'fileutils'

userfile = 'users.yaml'
file = 'wikidump.xml'

users = YAML.load(File.read(userfile))
puts "Got info for #{users.size} users."

puts "Parsing file '#{file}' ..."
hash = XmlSimple.xml_in(file)
puts "Done. Writing revisions..."

class NilClass
  def first
    nil
  end
end

hash['page'].each do |page|
  title = page['title'].first
  page_id = page['id'].first

  page['revision'].each do |revision|
    revision_id = revision['id'].first
    contributor = revision['contributor'].first['username'].first
    date = DateTime.parse(revision['timestamp'].first)
    text = revision['text'].first['content'] || ""
    comment = revision['comment'].first

    if u = users[contributor]
      contributor = "#{u['name']} <#{u['mail']}>"
    end

    data = {
      page_id: page_id,
      revision_id: revision_id,
      title: title,
      comment: comment,
      contributor: contributor,
      timestamp: date.to_time.to_i,
      text: text,
    }

    year = date.year.to_s
    month = date.month.to_s.rjust(2, '0')
    day = date.day.to_s.rjust(2, '0')

    filename = date.to_time.strftime("%F_%H-%M-%S") + "_p#{page_id}_r#{revision_id}.yaml"

    full_filename = File.join(['yaml', 'mw', year, month, day, filename])

    FileUtils.mkdir_p(File.dirname(full_filename))
    File.write full_filename, data.to_yaml
  end
end
```

## 3. convert the Wiki syntax in the yaml files to `rst` or `md` and save it in a new yaml file

Next, I wrote another small Ruby script (`mw2rst.rb`) to convert the wiki syntax to `rst`. I used as much as possible from existing projects, but had to hack some modules in a "try this then thas" way because no module could parse everything, apparently... The result was again saved in a similar structure, but with `./yaml/rst/` at the root:

```ruby
require 'yaml'
require 'fileutils'
require 'marker'
require 'wikicloth'
require 'pandoc-ruby'

class String
  def mw_to_html
    begin
      WikiCloth::Parser.new(:data => self).to_html
    rescue
      Marker.parse(self).to_html
    end
  end

  def html_to_rst
    PandocRuby.convert(self, :from => :html, :to => :rst)
  end

  def mw_to_rst
    begin
      PandocRuby.convert(self, :from => :mediawiki, :to => :rst)
    rescue
      result = self.mw_to_html.html_to_rst
      header = /\[`edit <\?section\=(?:[^\]]*)\] /
      result.gsub(header, '')
    end
  end
end

ARGV.each do |file|
  data = YAML.load(File.read(file))

  date = Time.at(data[:timestamp])
  page_id = data[:page_id]
  revision_id = data[:revision_id]

  year = date.year.to_s
  month = date.month.to_s.rjust(2, '0')
  day = date.day.to_s.rjust(2, '0')

  filename = date.to_time.strftime("%F_%H-%M-%S") + "_p#{page_id}_r#{revision_id}.yaml"

  full_filename = File.join(['yaml', 'rst', year, month, day, filename])
  unless File.exist?(full_filename)
    puts file

    text = data[:text]
    text.force_encoding("UTF-8")
    text = text.mw_to_rst
    data[:text] = text

    FileUtils.mkdir_p(File.dirname(full_filename))
    File.write full_filename, data.to_yaml
  end
end
```

The script takes any number of source yaml files and converts them sequentially. I then ran the script in parallel using gnu's parallel:

```bash
find yaml/mw/ -type f -name '*.yaml' | parallel -N20 --gnu ruby mw2rst.rb
```

This will launch the Ruby script once for each cpu core that I have, with 20 source yaml files each time (to reduce the startup overhead). This phase took even longer than step 2, even given that it ran in parallel. For the heck of it I wrote a quick and naive `progress` script:

```bash
#!/bin/bash

function progress ()
{
        m=$1
        n=$2
        u=$3
        echo "$m $u / $n $u ($(echo "100 * $m / $n" | bc)%)"
}

echo "Progress in files: $(progress $(find yaml/rst/ -type f | wc -l) $(find yaml/mw/ -type f | wc -l) "files")"
echo "Progress in size: $(progress $(du -ms yaml/rst/ | awk '{print $1}') $(du -ms yaml/mw/ | awk '{print $1}') MB)"
echo

ps o start_time,time,args | grep -v grep | grep ruby | cut -c 1-120
```

Run it:

```bash
watch -n 10 ./progress
```

The same script but outputs markdown instead:

```ruby
require 'yaml'
require 'fileutils'
require 'marker'
require 'wikicloth'
require 'pandoc-ruby'

class String
  def mw_to_html
    begin
      WikiCloth::Parser.new(:data => self).to_html
    rescue
      Marker.parse(self).to_html
    end
  end

  def html_to_md
    PandocRuby.convert(self, :from => :html, :to => :markdown)
  end

  def mw_to_md
    begin
      PandocRuby.convert(self, :from => :mediawiki, :to => :markdown)
    rescue
      result = self.mw_to_html.html_to_md
      header = /\[\[edit\]\(\?section\=(?:.*)\)\] /
      result.gsub(header, '')
    end
  end
end

ARGV.each do |file|
  data = YAML.load(File.read(file))

  date = Time.at(data[:timestamp])
  page_id = data[:page_id]
  revision_id = data[:revision_id]

  year = date.year.to_s
  month = date.month.to_s.rjust(2, '0')
  day = date.day.to_s.rjust(2, '0')

  filename = date.to_time.strftime("%F_%H-%M-%S") + "_p#{page_id}_r#{revision_id}.yaml"

  full_filename = File.join(['yaml', 'md', year, month, day, filename])

  unless File.exist?(full_filename)
    puts file

    text = data[:text]
    text.force_encoding("UTF-8")
    text = text.mw_to_md
    data[:text] = text

    FileUtils.mkdir_p(File.dirname(full_filename))
    File.write full_filename, data.to_yaml
  end
end
```

## 4. generate `git commit` from every 2nd step yaml file in chronological order.

### a. overwrite the respective file with the new content

### b. commit with author's name and mail address, using the comment from the revision as commit message

## 5. load the constructed git repository into a clean ReadTheDocs installation (using Docker of course)

First challenge proved to be finding a reasonable Docker image. Not a too big surprise given the state of the image ecosystem, and the fact that the keywords were very widely used :-)

I settled on this container: [suanmeiguo/readthedocs](https://hub.docker.com/r/suanmeiguo/readthedocs/) for the Proof-of-concept.
