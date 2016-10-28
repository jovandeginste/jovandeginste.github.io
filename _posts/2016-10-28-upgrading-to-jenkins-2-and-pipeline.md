---
layout: post
title: Upgrading to Jenkins 2 and pipelines
date: '2016-10-28 10:34:37 +0200'
author: jovandeginste
comments: true
tags:
  - jenkins
published: false
---

We've been running Jenkins for our automatic testing for more than a year now, using Jenkins Job Builder as a way to automate the creation and updating of the many jobs. While the scale was still reasonably small (order of 100 jobs), I often encountered problems managing the job definitions this way.

I had long been going for some Travis-like way to configure your job from your repo, and give the power back to the developer.

Earlier this year, Jenkins 2 was released, which included exactly this thing: Jenkinsfiles. This is a single file you put at the root of your code repository, which is then parsed by Jenkins. This feature was a continuation of the "workflow" suit of plugins, renamed to "pipelines" and included in the core install of Jenkins.

The Jenkinsfile is written in a DSL on top of Groovy, and has the potential to contain the complete job definition as you would have done before through the Web UI. Support for pipelines has to be implemented in every other plugin (if relevant), so adoption took some time.

## Our migration

Since plugins have to support pipelines to be usable this way, this can be a delaying factor for adoption. You can look for alternative plugins that replace the functionality (and do support pipelines), reimplement the functionality yourself by writing some Groovy classes, or maybe help the maintainer and donate some time to create a PR.

Today, all plugins essential to our setup support pipelines, so we can actually migrate all our jobs to pipeline jobs. Since I was using the Jenkins Job Builder before, most jobs are based on one of a small set of templates, and therefore I only had to convert those templates to Groovy classes included with every job.

The converted templates where never identical, so extensive testing of the new job by the code owner was obviously necessary. Against my expectations, most developers were actually very responsive to this major change in their workflow and were very cooperative. Some actually helped write part of the Groovy classes and fixed some bugs for me (I suspect they were really just happy to take a break from their usual projects).

After the first week, half of the jobs (mostly my own) were converted. After the second week, about 75% was running pipelines. The remaining jobs are still in the process of slowly being tested and converted at a slow pace.