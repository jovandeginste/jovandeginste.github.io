---
layout: post
title: "Upgrade Mattermost to 3.0"
date: "2016-05-24 13:35:42 +0200"
author: jovandeginste
comments: true
tags:
- mattermost
---

Today I decided to upgrade our Mattermost setup from 2.x to 3.x. The procedure was not too hard and our test-setup went without a problem. However, on our test-setup we have only one "team"... Production was a different matter :-)

During the upgrade procedure, the script told me it renamed some users to prefix them with the non-default team. We have one general Mattermost team ("default-team"), and one team for a specific set of users which I will call "other-team". Some members of other-team were also part of default-team). The duplicate user 'user1' on the other-team were now called 'other-team.user1' (etc).

Those users did want their old user names back :-) The users on the other-team used the same user names on both teams, which made merging easier and harder at the same time.

I have to say I was lucky with the merging being fairly straight forward. I recommend anyone verifying every step by hand and obviously make some backups before upgrading and during the procedure. You may have a lot of custom work remaining until someone writes a real bullet proof migration script.

Also, I obfuscated all ids and replaced the first and last 6 characters by 'x' and 'y'. User names are not real either :-)

## The big merge

I started by collecting the relevant user ids for those users, on both teams. I will limit this example to a set of three users:

User ids per Mattermost team:

```yaml
default-team:
  user1: xxxxxx835fyj5eeutfxqyyyyyy
  user2: xxxxxx1ro3dqjrjsi1f9yyyyyy
  user3: xxxxxx57gpgo3gdpb1goyyyyyy

other-team:
  user1: xxxxxx6uzffddxzis6u5yyyyyy
  user2: xxxxxxc3xbgd9e9prjigyyyyyy
  user3: xxxxxxaxmpfrme5smja9yyyyyy
```

After investigating the database schema and experimenting with a single user, I found a set of commands that seemed to do a good job at merging the users. I decided to use their users in default-team as the final (`destination`) user, and therefore move anything from other-team that could be merged to the default-team. Some settings would be lost, but the users could live with that.

```bash
#!/bin/bash

# The list of users in form destination_id:source_id, space separated:
users="xxxxxx1ro3dqjrjsi1f9yyyyyy:xxxxxxc3xbgd9e9prjigyyyyyy xxxxxx57gpgo3gdpb1goyyyyyy:xxxxxxaxmpfrme5smja9yyyyyy"

for user in $users
do
  # Get the destination_id
  dest_id=$(echo $user | awk -F: '{print $1}')
  # Get the source_id
  src_id=$(echo $user | awk -F: '{print $2}')

  # Echo the needed SQL commands to stdout, so I can run them interactively:
  cat <<- EOF
  ## Migrating: ${src_id} to ${dest_id}

  # This will copy the incoming and outgoing webhooks to the final user
  update IncomingWebhooks set userid='${dest_id}' where userid='${src_id}';
  update OutgoingWebhooks set creatorid='${dest_id}' where creatorid='${src_id}';

  # This will change the author of the posts
  # NOTE: this includes private conversations
  update Posts set userid='${dest_id}' where userid='${src_id}';

  # This will change membership of channels
  # NOTE: if the final user had already joined the same channel since the merge,
  # this may throw some errors. The SQL code could be improved here to skip those...
  # NOTE: this includes 'membership' to private channels and private conversations
  update ChannelMembers set userid='${dest_id}' where userid='${src_id}';

  # Now private conversations need to be renamed. The names have the forms of
  # "userid1__userid2", so we will rename two different cases:
  # - src_id is first userid
  # - src_id is last userid
  # NOTE: if these users have talked to each other on multiple teams, we have a problem here.
  # We will have to do some more complicated merges. I did not have a problem here (...)
  update Channels set name = concat(left(name, 26), '__${dest_id}') where right(name, 26) = '${src_id}';
  update Channels set name = concat('${dest_id}__', right(name, 26)) where left(name, 26) = '${src_id}';

  # Here we need to switch the channel name according to the algorithm in Mattermost
  # userid1 < userid2, so we switch them where userid1 > userid2
  # NOTE: (...) but I had a problem here! The users talked to each other on different channels,
  # but the order of the user ids switched. I had both private conversations user1__user2 and user2__user1
  # I resolved this later by hand.
  update Channels set name = concat(right(name, 26), '__', left(name, 26)) where left(name, 26) > right(name, 26)
  ## Done with migration

  EOF
done
```

Just for sanity, we can check if all channels have been renamed:

```sql
SELECT left(name, 26) > right(name, 26) FROM `Channels`
```

## A single problem ...

This gave me the one remaining private chat between two users that had talked to each other on different channels. Reiterating the issue, I had both private conversations `user1__user2` and `user2__user1`. The error MySQL threw me was:

`#1062 - Duplicate entry 'xxxxxx6uzffddxzis6u5yyyyyy-' for key 'Name'`

I queried the list of channels to get the channel ids for both private conversations:

```sql
select id, name from Channels where name is 'xxxxxx57gpgo3gdpb1goyyyyyy__xxxxxx835fyj5eeutfxqyyyyyy' or name is 'xxxxxx835fyj5eeutfxqyyyyyy__xxxxxx57gpgo3gdpb1goyyyyyy';
```

The result:

```
xxxxxxinhtn4fykso4awyyyyyy xxxxxx835fyj5eeutfxqyyyyyy__xxxxxx57gpgo3gdpb1goyyyyyy
xxxxxxdse7nifd3k18nsyyyyyy xxxxxx57gpgo3gdpb1goyyyyyy__xxxxxx835fyj5eeutfxqyyyyyy
```

It is not visible because of my obfuscation, howver `xxxxxx57gpgo3gdpb1goyyyyyy < xxxxxx835fyj5eeutfxqyyyyyy`, so the private conversation to keep was the one with channel id `xxxxxxdse7nifd3k18nsyyyyyy`; the query to move all posts from the obsolete conversation to the final one:

```sql
update Posts set channelid='xxxxxxdse7nifd3k18nsyyyyyy' where channelid='xxxxxxinhtn4fykso4awyyyyyy';
```

Now cleanup the obsolete private conversation (and its members):

```sql
DELETE FROM `ChannelMembers` where channelid = 'xxxxxxinhtn4fykso4awyyyyyy' ;
DELETE FROM `Channels` where id = 'xxxxxxinhtn4fykso4awyyyyyy' ;
```

When this was finished, I disabled the users from other-team so they would not accidentally log in and do things. This was done through Mattermost's admin panel, and not in the database.

## What was left

There were still some things left after these steps. Most notably, a user had pasted an image from clipboard directly into a channel, and this image was now tagged with his user id. The url had this form:

```
https://mymattermostdomain/api/v3/teams/xxxxxxbxqibtfr3u97diyyyyyy/files/get/xxxxxxnjd3ffpm83nbtcyyyyyy/xxxxxx6uzffddxzis6u5yyyyyy/xxxxxxehobb8xx6tadctyyyyyy/Image%20Pasted%20at%202016-0-19%2015-03.png
```

Instead of figuring out how to change this, the user posting this noted it was no longer relevant and just deleted it. Some problems are easier to fix than others ;-)

## Conclusiong

I was not prepared for the amount of work ahead, but all in all the migration went well. I sincerely hope not every major upgrade will have this level of involvement from me (or my successor)...
