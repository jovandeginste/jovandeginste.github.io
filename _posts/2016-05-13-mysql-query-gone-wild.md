---
layout: post
title: "MySQL query gone wild"
date: "2016-05-13 10:17:28 +0200"
author: "Jo Vandeginste"
comments: true
tags:
- mysql
---

Today I came to work to find a MySQL database non-responsive (for websites). Many many queries were queued, some were executing for more than 30.000 seconds(!).

Restarting the database solved the queues, everything was back to normal. Post-mortem: someone added a `OR sleep(5)` in the query, and executed this query many times (with some variations)

Try this for yourself:

* create a table with a single column:
  `create table sleeptest (myint tinyint(1));`
* add a few entries (eg. 3):
  `insert into sleeptest (myint) values (1),(2),(3);`
* query all entries without `WHERE` clause:
  `select * from sleeptest;`
* query all entries with `WHERE sleep(5)` clause:
  `select * from sleeptest where sleep(5);`

See the difference? Hint: it's the last line :-)

I did a few variations on the `WHERE` part, here are the results (query + last line). Most results are obvious:

```mysql
mysql> select * from sleeptest where true or sleep(5);
3 rows in set (0.00 sec)

mysql> select * from sleeptest where sleep(5) or true;
3 rows in set (0.00 sec)

mysql> select * from sleeptest where true and sleep(5);
Empty set (15.00 sec)

mysql> select * from sleeptest where false or sleep(5);
Empty set (14.99 sec)

mysql> select * from sleeptest where sleep(5) and myint=1;
Empty set (5.00 sec)

mysql> select * from sleeptest where myint=1 and sleep(5);
Empty set (5.00 sec)

mysql> select * from sleeptest where sleep(5) or myint=1;
1 row in set (15.00 sec)

mysql> select * from sleeptest where myint=1 or sleep(5);
1 row in set (10.00 sec)
```

I guess MySQL uses some form of optimizations ...
