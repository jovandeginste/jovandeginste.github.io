---
layout: post
title: "Upgrade Mattermost to 3.0"
date: "2016-05-24 13:35:42 +0200"
author: jovandeginste
comments: true
published: false
tags:
- mattermost
---

Today I decided to upgrade our Mattermost setup from 2.x to 3.x.

icts:
user1=xxxxxx835fyj5eeutfxqyyyyyy
user2=xxxxxx1ro3dqjrjsi1f9yyyyyy
user3=xxxxxx57gpgo3gdpb1goyyyyyy

ceifnet:
user1=xxxxxx6uzffddxzis6u5yyyyyy
user2=xxxxxxc3xbgd9e9prjigyyyyyy
user3=xxxxxxaxmpfrme5smja9yyyyyy

#!/bin/bash

users="xxxxxx1ro3dqjrjsi1f9yyyyyy:xxxxxxc3xbgd9e9prjigyyyyyy xxxxxx57gpgo3gdpb1goyyyyyy:xxxxxxaxmpfrme5smja9yyyyyy"

for user in $users
do
        dest_id=$(echo $user | awk -F: '{print $1}')
        src_id=$(echo $user | awk -F: '{print $2}')

        cat <<- EOF
        ## Migrating: ${src_id} to ${dest_id}
        update IncomingWebhooks set userid='${dest_id}' where userid='${src_id}';
        update OutgoingWebhooks set creatorid='${dest_id}' where creatorid='${src_id}';

        update Posts set userid='${dest_id}' where userid='${src_id}';
        update ChannelMembers set userid='${dest_id}' where userid='${src_id}';

        update Channels set name = concat(left(name, 26), '__${dest_id}') where right(name, 26) = '${src_id}';
        update Channels set name = concat('${dest_id}__', right(name, 26)) where left(name, 26) = '${src_id}';
        update Channels set name = concat(right(name, 26), '__', left(name, 26)) where left(name, 26) > right(name, 26)
        ## Done with migration

        EOF
done

SELECT left(name, 26) > right(name, 26) FROM `Channels`

Conflict in private chats:

update Channels set name = concat('', right(name, 26)) where left(name, 26) = 'xxxxxxaxmpfrme5smja9yyyyyy';
MySQL said:

#1062 - Duplicate entry 'xxxxxx6uzffddxzis6u5yyyyyy-' for key 'Name'

xxxxxxinhtn4fykso4awyyyyyy xxxxxx835fyj5eeutfxqyyyyyy__xxxxxx57gpgo3gdpb1goyyyyyy
xxxxxxdse7nifd3k18nsyyyyyy xxxxxx57gpgo3gdpb1goyyyyyy__xxxxxx835fyj5eeutfxqyyyyyy

update Posts set channelid='xxxxxxdse7nifd3k18nsyyyyyy' where channelid='xxxxxxinhtn4fykso4awyyyyyy';

SELECT * FROM `Posts` where channelid = 'xxxxxxinhtn4fykso4awyyyyyy' ;
SELECT * FROM `ChannelMembers` where channelid = 'xxxxxxinhtn4fykso4awyyyyyy' ;
SELECT * FROM `Channels` where id = 'xxxxxxinhtn4fykso4awyyyyyy' ;

