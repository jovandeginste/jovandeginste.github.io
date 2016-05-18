---
layout: post
title: "How to get an active-active MySQL setup back in sync after hard crash"
date: "2016-05-18 11:48:20 +0200"
author: jovandeginste
comments: true
tags:
- mysql
---

Yesterday one member of our active-active MySQL cluster experienced a hard power off. After getting the server back online, MySQL's binary logs (both the server's and the relay logs) turned out to be corrupted. For the sake of clarity, I will call the server that crashed 'node1', and the other server 'node2'. This post will explain how to get the cluster back in sync with a minimum of data loss.

## The current situation

On both servers, the replication has stopped. This is the relevant output on both nodes:

* node1:

```
              Master_Log_File: mysql-bin.000253
          Read_Master_Log_Pos: 569975131
               Relay_Log_File: relay-bin.000198
                Relay_Log_Pos: 179576569
        Relay_Master_Log_File: mysql-bin.000253
                   Last_Error: Relay log read failure: Could not parse relay log event entry. The
                               possible reasons are: the master's binary log is corrupted (you can
                               check this by running 'mysqlbinlog' on the binary log), the slave's
                               relay log is corrupted (you can check this by running 'mysqlbinlog'
                               on the relay log), a network problem, or a bug in the master's or
                               slave's MySQL code. If you want to check the master's binary log or
                               slave's relay log, you will be able to know their names by issuing
                               'SHOW SLAVE STATUS' on this slave.
          Exec_Master_Log_Pos: 419130498
```

* node2:

```
              Master_Log_File: mysql-bin.000234
          Read_Master_Log_Pos: 173841457
               Relay_Log_File: relay-bin.000197
                Relay_Log_Pos: 101852398
        Relay_Master_Log_File: mysql-bin.000234
          Exec_Master_Log_Pos: 173841457
                Last_IO_Error: Got fatal error 1236 from master when reading data from binary log:
                               'Client requested master to start replication from impossible position'
```

So basically, node1's binlogs and relaylogs were corrupted: two problems to fix.

## Fixing node2's syncing from node1

The binlog is easy. When starting, MySQL always starts writing to a new binlog file. We point node2 to the head of node1's newer binlog (`mysql-bin.000235` position `4`). Execute on node2:

```
mysql> stop slave;
Query OK, 0 rows affected (0.00 sec)

mysql> CHANGE MASTER TO MASTER_HOST='node1', MASTER_USER='user', MASTER_PASSWORD='pass',
            MASTER_LOG_FILE='mysql-bin.000235', MASTER_LOG_POS=4;
Query OK, 0 rows affected (0.00 sec)

mysql> start slave;
Query OK, 0 rows affected (0.00 sec)
```

Now check the status:

```
mysql> show slave status;
<...>
        Seconds_Behind_Master: 48988
<...>
```

Great - node2 is fetching node1's binary logs. Now the next problem: node1's relay logs are corrupt.

## Fixing node1's syncing from node2

The way to go is tell node1 to restart slaving from node2 from the position it failed: `mysql-bin.000253` position `419130498`

Again, nothing to hard if you know what you're doing :-)

```
mysql> stop slave;
Query OK, 0 rows affected (0.00 sec)

mysql> CHANGE MASTER TO MASTER_HOST='node1', MASTER_USER='user', MASTER_PASSWORD='pass', MASTER_LOG_FILE='mysql-bin.000253', MASTER_LOG_POS=419130498;
Query OK, 0 rows affected (0.01 sec)

mysql> start slave;
Query OK, 0 rows affected (0.00 sec)
```

Again, verify the status:

```
mysql> show slave status;
<...>
        Seconds_Behind_Master: 60590
<...>
```

Great, it works! Keep an eye on it for a while (`show slave status;`) until it reaches 0, and you're set again!
