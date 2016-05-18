---
layout: post
title: "Add metadata tags to Jekyll blog posts"
date: "2016-05-18 18:08:41 +0200"
author: jovandeginste
comments: true
tags:
- jekyll
---

Short explanation of the steps taken to add metadata tags to Jekyll site (for SEO). This includes stuff for social share buttons.

### Authors

First make a datafile with authors. My `_data/authors.yml`:

```yaml
---
jovandeginste:
  name: Jo Vandeginste
  email: jo.vandeginste@gmail.com
  web: http://jovandeginste.github.io
  image: http://jovandeginste.github.io/foto.jpg
```

Then make sure every post had an author. For this particular post:

```yaml
---
layout: post
title: "Add metadata tags to Jekyll blog posts"
date: "2016-05-18 18:08:41 +0200"
author: jovandeginste
...
```

### Page metadata

Every page has it's metadata in the `<head>`; Based on Open Graph and other sources, I put these tags in `_includes/head.html`:

{% raw %}
```html
  <meta name="description" content="{% if page.excerpt %}{{ page.excerpt | strip_html | strip_newlines | truncate: 160 }}{% else %}{{ site.description }}{% endif %}">

  <meta property="og:site_name" content="{{ site.title }}">
  {% if page.title %}
  <meta property="og:title" content="{{ page.title }}">
  <meta property="og:type" content="article">
  <meta property="og:description" content="{{ page.excerpt | strip_html }}"/>
  {% else %}
  <meta property="og:title" content="{{ site.title }}">
  <meta property="og:type" content="website">
  <meta property="og:description" content="{{ site.description }}">
  {% endif %}
  {% if page.date %}
  <meta property="article:published_time" content="{{ page.date | date_to_xmlschema }}">
  <meta property="article:author" content="{{ site.url }}/about/">
  {% endif %}
  <meta property="og:url" content="{{ site.url }}{{ page.url }}" />
  {% if page.tags %}
  <meta itemprop="keywords" content="{{ page.tags | join: ',' }}" />
  {% for tag in page.tags %}
  <meta property="article:tag" content="{{ tag }}">
  {% endfor %}
  {% endif %}
  {% if author %}
  <meta property="article:author" content="{{ author.name }}" />
  {% endif %}
```
{% endraw %}


### Post metadata

Finally, I gave every post its own metadata (some visible, some hidden). My copy of `_layouts/post.html` starts with this:

{% raw %}
```jekyll
{% assign author = site.data.authors[page.author] %}
{% if page.date_modified %}
{% assign modified = page.date_modified %}
{% else %}
{% assign modified = page.date %}
{% endif %}

<article class="post" itemscope itemtype="http://schema.org/BlogPosting">

  <header class="post-header">
    <h1 class="post-title" itemprop="name headline">{{ page.title }}</h1>
    <p class="post-meta">
    <time datetime="{{ page.date | date_to_xmlschema }}" itemprop="datePublished">{{ page.date | date: "%b %-d, %Y" }}</time>
    <meta content="{{ modified | date_to_xmlschema }}" itemprop="dateModified" />
    {% if author %} •
    <span itemprop="author" itemscope itemtype="http://schema.org/Person">
      <span itemprop="name">{{ author.name }}</span>
      <meta itemprop="email" content="{{ author.email }}" />
      <meta itemprop="image" content="{{ author.image }}" />
      {% if author.email %}
      <a
        class="fa fa-envelope"
        title="contact me via e-mail"
        href="mailto:{{ site.email }}">&nbsp;</a>
      {% endif %}
    </span>
    <span itemprop="publisher" itemscope itemtype="http://schema.org/Organization">
      <meta itemprop="name" content="{{ site.name }}" />
      <span itemprop="logo" itemscope itemtype="http://schema.org/ImageObject">
        <meta itemprop="url" content="{{ site.url }}/favicon.png" />
        <meta itemprop="height" content="142" />
        <meta itemprop="width" content="128" />
      </span>
    </span>
    {% endif %}
    <meta itemprop="mainEntityOfPage" content="{{ site.url }}" />
    <span itemprop="image" itemscope itemtype="http://schema.org/ImageObject">
      <meta itemprop="url" content="{{ site.url }}/favicon.png" />
      <meta itemprop="height" content="142" />
      <meta itemprop="width" content="128" />
    </span>
    </p>
```
{% endraw %}
