---
layout: post
title: "Add a cookie-notification for EU compliance"
date: "2016-06-12 11:29:15 +0200"
author: jovandeginste
comments: true
tags:
- cookies
- jekyll
---

## EU cookie law

Recently I was looking at my analytics and saw references from http://law-enforcement-ff.xyz. I had no idea what it was, so I visited the site. Funny page :-) More about this below. First, it actually made me wonder whether or not the cookie-law applied to my small blog as well, and apparently it may do!

So I had some fun looking at the requirements and examples, and decided to a) have a cookie-page and b) explicitly inform users of cookies. (b) is not a requirement per the law, as long as you implicitly inform them: a link to a cookie policy page might be enough.

This [free javascript generator](https://silktide.com/tools/cookie-consent/download/) was the first one I encountered and I was charmed with the simplicity of it. It was quickly added to my site using an `include` in the `head`.

I had a little more work with a no-nonsense page about the policy: I specifically cared not to scare users that my site might become unusable if they didn't allow cookies. Feel free to copy (and/or improve) if it suits your case.

All in all a simple change to comply with a strange law.

## Spammer?

Next up was finding out more about http://law-enforcement-ff.xyz. On the Internet, I found a [page explaining about this type of sites](https://www.ohow.co/what-is-cookie-law-enforcement-bb-xyz-referral-google-analytics/). It also lists other similar domains:
* cookie-law-enforcement-**.xyz
* eu-cookie-law-enforcement-*.xyz
* law-enforcement-**.xyz

The phenomenon is apparently called [Ghost Spam](https://www.ohow.co/all-the-answers-about-the-spam-in-google-analytics/#What-is-Ghost-Spam). Apparently I will need to take some steps (explained on the first site) to clean up my analytics now! And there I was thinking my blog was popular ... :-/
