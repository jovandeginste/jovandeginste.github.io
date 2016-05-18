---
layout: post
title: "Add a tag cloud to my Jekyll site"
date: "2016-05-04 11:29:16 +0200"
author: "Jo Vandeginste"
comments: true
tags:
- jekyll
---

As a matter of cosmetic improvement, I wanted my list of tags per post to be more like the tag clouds. I also wanted a page with all tags in a cloud. I let myself be inspired by [these](http://vvv.tobiassjosten.net/jekyll/jekyll-tag-cloud/) [examples](https://superdevresources.com/tag-cloud-jekyll/) and (in my opinion) improved them.

What was missing? Those examples based themselves on a wrong ratio: the size of each tag X was calculated as:

`min + factor * (occurences of tag X) / (total number of unique tags)`

What I wanted was:

`min + factor * (occurences of tag X) / (total number of tags)`

Subtle difference, but I thought it was important enough...

I created an includeable snippet:

[_includes/tagcloud.html](https://github.com/jovandeginste/jovandeginste.github.io/blob/master/_includes/tagcloud.html):

{% raw %}
```html
{% capture site_tags %}{% for tag in site.tags %}{{ tag | first }}{% unless forloop.last %},{% endunless %}{% endfor %}{% endcapture %}
{% assign site_tags = site_tags | split: ',' %}

{% assign tag_count = 0 %}
{% for tag in site_tags %}
{% assign tag_count = tag_count | plus: site.tags[tag].size %}
{% endfor %}

{% for tag in tags %}
{% assign rel_tag_size = site.tags[tag].size | times: 4.0 | divided_by: tag_count | plus: 1 %}
<span style="white-space: nowrap; font-size: {{ rel_tag_size }}em; padding: 0.6em;">
	<a href="{{ site.baseurl }}/tags/{{ tag | slugize }}" class="tag">{{ tag | slugize }}
		<span>({{ site.tags[tag].size }})</span>
	</a>
</span>
{% endfor %}
```
{% endraw %}

This expects a variable ```tags``` to be set to the list of tags to show and "cloudify". I can include it for the general tag page and for the individual post page.

[tags.html](https://github.com/jovandeginste/jovandeginste.github.io/blob/master/tags.html):

{% raw %}
```html
---
layout: default
title: Tags
permalink: /tags/
---

<div class="home">
	<h1 class="page-heading">All tags</h1>

	<p class="post-meta" style="text-align: justify;">
	{% capture site_tags %}{% for tag in site.tags %}{{ tag | first }}{% unless forloop.last %},{% endunless %}{% endfor %}{% endcapture %}
	{% assign tags = site_tags | split:',' | sort %}
	{% include tagcloud.html %}
	</p>
</div>
```
{% endraw %}

[_layouts/post.html](https://github.com/jovandeginste/jovandeginste.github.io/blob/master/_layouts/post.html):

{% raw %}
```html
---
layout: default
---
<article class="post" itemscope itemtype="http://schema.org/BlogPosting">

	<header class="post-header">
		<h1 class="post-title" itemprop="name headline">{{ page.title }}</h1>
		<p class="post-meta"><time datetime="{{ page.date | date_to_xmlschema }}" itemprop="datePublished">{{ page.date | date: "%b %-d, %Y" }}</time>{% if page.author %} • <span itemprop="author" itemscope itemtype="http://schema.org/Person"><span itemprop="name">{{ page.author }}</span></span>{% endif %}</p>
		<p class="post-meta" style="text-align: justify;">
		Tags:
		{% assign tags = page.tags | sort %}
		{% include tagcloud.html %}
		</p>
	</header>

	<div class="post-content" itemprop="articleBody">
		{{ content }}
	</div>

	{% include disqus.html %}
</article>
```
{% endraw %}
