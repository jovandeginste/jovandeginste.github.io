---
layout: post
title: Jenkins pipelines - Groovy classes
date: '2016-11-11 20:22:39 +0100'
author: jovandeginste
comments: true
tags:
  - jenkins
published: false
---

When writing your first Jenkinsfiles, you will probably realise very quickly that you are repeating many code parts. Since I'm allergic to this, I started looking at the options to reuse code.

## The solution

The obvious solution is to put your code in Groovy classes in a separate git repository and somehow access that repository from your Jenkins jobs.

The options I came up with, in order that I implemented them:

1. add the repository as a git submodule in your projects
2. add the repository as a Pipeline Library to the job
3. add the repository as a Global Pipeline Library in the Jenkins system configuration

Incidentally, they are also the order of less to more privileges needed on the Jenkins server.

Option 3 means you every pipeline job by default will have access to your library.

## Step 1: writing your first Groovy class

You don't need to be familiar with Java to get started with Groovy. In fact, in my opinion, it helps to forget most of your Java-specific knowledge. Groovy compiles to Java, which means that you may encounter some Java errors on the way (more about this later), but usually the stack traces will point to some error in some Groovy file.