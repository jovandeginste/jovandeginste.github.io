---
layout: post
title: "Migrating internal documentation from MediaWiki to Gollum"
date: "2016-05-29 18:26:54 +0200"
comments: true
published: false
tags:
- MediaWiki
- Gollum
---

I like MediaWiki and WikiPedia as a consumer. I used to like it as a producer when I started documenting procedures at my job - let's say about 10 years ago now. But very quickly, I started avoiding it for documentation, and the result was that my documentation was lacking and/or all over the place (depending on the project). As a proof of concept, I wanted to deploy a [Gollum](https://github.com/gollum/gollum) site and see how feasible it is to migrate our current MediaWiki content to it.

For extra credits, I wanted to preserve the change history in the documentation. I would try to create git history as if every wiki revision was a single commit. Input for Gollum could be the source `wiki`, or either `reStructuredText` or `Markdown` (not decided yet).

Instead of a big bang attempt, I prepared some migration steps:

1. export MediaWiki (including all revisions) to a single xml file using its built-in tool
2. extract the single xml into separate yaml files per revision
3. convert the Wiki syntax in the yaml files to `html` and save it in a new yaml file
4. convert the `html` files to `rst` and `md` and save them in a new yaml file
5. generate `git commit` from every 2nd step yaml file in chronological order.
   a. overwrite the respective file with the new content
   b. commit with author's name and mail address, using the comment from the revision as commit message
6. load the constructed git repository into a clean Gollum installation (using Docker of course)
7. remarks

I uploaded the relevant scripts to a [Github repository](https://github.com/jovandeginste/mediawiki_to_gollum)

## 1. export MediaWiki (including all revisions) to a single xml file using its built-in tool

MediaWiki has a helpful tool to export the whole set of articles to a single xml file. I used it and let it include file metadata along the way:

```bash
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

The big xml was - well, big: >700 MB. This means that parsing it as xml takes a while. I wrote a small Ruby script [xml2yaml](https://github.com/jovandeginste/mediawiki_to_gollum/blob/master/xml2yaml.rb) to extract the necessary information from `wikidump.xml` and write it to separate yaml files `./yaml/wiki/year/month/mday/timestamp_projectid_revisionid.yaml`.

## 3. convert the Wiki syntax in the yaml files to `html` and save it in a new yaml file

Next, I wrote another small Ruby script [wiki2html.rb](https://github.com/jovandeginste/mediawiki_to_gollum/blob/master/wiki2html.rb) to convert the wiki syntax to `html`. I had to sanitize the input text to maximize the chance of usable output. The result was again saved in a similar structure, but with `./yaml/html/` at the root.

The script takes any number of source yaml files and converts them sequentially. I then ran the script in parallel using gnu's parallel:

```bash
find yaml/wiki/ -type f -name '*.yaml' | parallel -N20 --gnu ruby wiki2html.rb
```

This will launch the Ruby script once for each cpu core that I have, with 20 source yaml files each time (to reduce the startup overhead). This phase took way longer than step 2, even given that it ran in parallel. For the heck of it I wrote a quick and naive [progress](https://github.com/jovandeginste/mediawiki_to_gollum/blob/master/progress) script:

Run it:

```bash
watch -n 10 ./progress
```

## 4. convert the `html` files to `rst` and/or `md` and save them in a new yaml file

The next step seemed to be easier. Given that most work was in converting to `html`, the conversion to `rst` or `md` was a lot more straight forward! I wrote a single script [html2any](https://github.com/jovandeginste/mediawiki_to_gollum/blob/master/html2any.rb) that could do both (and other) conversions depending on the first parameter:

## 5. generate `git commit` from every 2nd step yaml file in chronological order.

Now that all data was safely stored in a useful format with the necessary metadata, we can start sending it to `git`. Again a simple ruby script [any2git.rb](https://github.com/jovandeginste/mediawiki_to_gollum/blob/master/any2git.rb)

## 6. load the constructed git repository into a clean Gollum installation (using Docker of course)

First challenge proved to be finding a reasonable Docker image. Not a too big surprise given the state of the image ecosystem, and the fact that the keywords were very widely used :-)

I settled on [this Dockerfile](https://github.com/suttang/docker-gollum/blob/master/Dockerfile) with a slight change: I added `wikicloth` to the list of gems.

Run the image:

```bash
docker run -p 4567:4567 --rm -ti -v "$(pwd)/repo:/root/wikidata/:ro" gollum --base-path /gollum --show-all
```

(Note: `--base-path /gollum` was because I started it behind a Reverse Proxy)

## 7. remarks

First, the conversion from wiki to other formats is - though straight forward - far from perfect. Some more `gsub`'s might do the trick finally, but I will probably have to settle on some manual work for some pages. Using `markdown_github` over `markdown` seemed to solve many issues. I will continue to update my code in the repository.

Hyperlinks to sub-wiki-pages (pages containing `/`) is also prone to errors, but also very predictable and thus fixable.

Next, Gollum has no state at all. This means it starts very fast, but serves quite slow when the repository is big. Mine was 28000 git commits (= wiki page revisions) and 2900 pages. Experimenting with formats seemed to point out that using `.wiki` files was slower than .md` files, and that less commits was faster. On the other hand, it could be useful to have a SQL database with metadata for some parts.

The search function in Gollum was always very fast... Not sure why this was so fast, while rendering a single page was not. I will try to find out more on this, maybe try to improve Gollum (or find an alternative).
