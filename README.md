# Ansible OpenStack Juno

For now this playbook sets up a small OpenStack system with:

* 1x controller
* 2x compute nodes

It does not use Neutron, so "legacy" nova-network, and uses flat dhcp networking.

## Getting started

Requirements:

* Vagrant
* Base trusty box

```bash
curtis$ vagrant box add ubuntu/trusty64
```
## Vagrant

I'm using the ```vagrant-cachier``` plugin, but you don't have to; could comment it out in the vagrant file.

My home workstation is fairly powerful, with 8 cores and 32GB of main memory, as well as an SSD. A smaller host might have trouble with multiple virtual machines, but probably not.

## Clone this repo

```bash
curtis$ git clone git@github.com:ccollicutt/ansible-openstack-juno.git
```

## OpenStack Ansible modules

I use [these great modules](https://github.com/openstack-ansible).

```bash
curtis$ cd ansible-openstack-juno
curtis$ mkdir library
curtis$ cd library
curtis$ git clone https://github.com/openstack-ansible/openstack-ansible-modules.git
```

Then install OpenStack clients client locally.

```bash
curtis$ sudo apt-get install python-dev
curtis$ sudo pip install python-novaclient
curtis$ sudo pip install python-glanceclient
```

## Run!

```bash
curtis$ vagrant up
# wait...
curtis$ ansible-playbook site.yml
# wait...
```

Now that the basic infrastructure is up, we can add the cirros image and a couple other things.

```bash
curtis$ wget http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
```

Now that we have the cirros image, we can run the short setup playbook. This will install the cirros image via glance, add some ssh keys (not really needed though), and a default network called "flatnet" (which sounds mathematica).

```bash
curtis$ ansible-playbook setup.yml
```

Finally we can login to the controller and start an instance. You don't have to login to the controller, but I have put the ```adminrc``` and ```testrc``` files there to easily source an the OpenStack variables.

```bash
curtis$ ssh 10.1.10.11 # need to setup your .ssh/config to use the right user and private key
vagrant@controller01:~$ . adminrc
vagrant@controller01:~$ nova net-list # if you ran setup.yml the output should be similar, though with a different ID
+--------------------------------------+---------+------------------+
| ID                                   | Label   | CIDR             |
+--------------------------------------+---------+------------------+
| d45ac34d-aa9e-435f-b2cc-ef24464627d9 | flatnet | 192.168.99.32/27 |
+--------------------------------------+---------+------------------+
vagrant@controller01:~$ nova boot --flavor m1.tiny --image Cirros demo-instance1
```

Setup default rules, allow ssh and icmp so you can ping and ssh into the cirros instance.

```bash
vagrant@controller01:~$ nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
vagrant@controller01:~$ nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
```

If everything goes well, a vm should start up. As shown below, I've started a couple in the test tenant.

```bash
vagrant@controller01:~$ nova list
+--------------------------------------+----------------+--------+------------+-------------+-----------------------+
| ID                                   | Name           | Status | Task State | Power State | Networks              |
+--------------------------------------+----------------+--------+------------+-------------+-----------------------+
| 51e3af43-7495-42f3-9c4a-7c531d9bd66c | test-instance1 | ACTIVE | -          | Running     | flatnet=192.168.99.35 |
| f7a4ab73-d2b8-4a3c-b1ad-1e05779321f0 | test-instance2 | ACTIVE | -          | Running     | flatnet=192.168.99.38 |
+--------------------------------------+----------------+--------+------------+-------------+-----------------------+
```

With two or more compute nodes the instances should be scheduled across them.

```bash
vagrant@controller01:~$ sudo nova-manage vm list | tr -s " " |  cut -f 1,2 -d " "
instance node
demo-instance1 compute02
demo-instance2 compute01
```

Finally we can try sshing in. I'm going from my workstation's command line.

```bash
curtis$ ssh cirros@192.168.99.34
cirros@192.168.99.34's password:
$ ifconfig eth0
eth0      Link encap:Ethernet  HWaddr FA:16:3E:3D:96:A4  
          inet addr:192.168.99.34  Bcast:192.168.99.63  Mask:255.255.255.224
          inet6 addr: fe80::f816:3eff:fe3d:96a4/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:444 errors:0 dropped:0 overruns:0 frame:0
          TX packets:331 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:57008 (55.6 KiB)  TX bytes:36968 (36.1 KiB)
```

These instances can't ping out to the Internet at this time just due to the way the virtualbox network is configured. I'll fix that later. For now I feel like everything is working, though there is some ssl-ifying to do on everything but keystone.

```bash
$ ping -c 1 -w 1 192.168.99.1
PING 192.168.99.1 (192.168.99.1): 56 data bytes
64 bytes from 192.168.99.1: seq=0 ttl=64 time=1.600 ms

--- 192.168.99.1 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 1.600/1.600/1.600 ms
```

## SSL and Haproxy

<span style="color:red">NOTE: You'll have to use ```--insecure``` with nova, glance, and keystone commands.</span>

Haproxy is fronting most of the services. Keystone has it's own SSL for now, though that's not what one would do in production, so it's listening on its commonly used port number. I hope to eventually front all the necessary services with SSL.

I'm using some funny ports:

* 10000 = glance api
* 10001 = glance registry
* 10002 = nova api
* 10003 = novnc proxy

## Multihost FlatDHCP Network

Oof, that is a mouthful. To be honest I haven't found a great description of this setup. It's working, but the one thing I'm wondering about is how the gateway is working on each compute node. For example, each compute node is responding to ```192.168.99.33``` but that is not pingable from the controller. On one hand it makes sense and is working, but on the other I can't find it documented anywhere clearly.

Mirantis has a [good description](https://software.mirantis.com/refdoc-fuelweb3/flatdhcp-manager-multi-host-scheme/) of a "Multihost Flat Network" in OpenStack.

>The main idea behind the flat network manager is to configure a bridge (i.e. br100) on every compute node and have one of the machine’s host interfaces connect to it. Once the virtual machine is launched its virtual interface will connect to that bridge as well. The same L2 segment is used for all OpenStack projects, and it means that there is no L2 isolation between virtual hosts, even if they are owned by separated projects. For this reason it is called Flat manager.

There are a few other write ups of the flat network:

* [OpenStack Havan Flat Networking](http://behindtheracks.com/2013/12/openstack-havana-flat-networking/)
* The [example architecture document](http://docs.openstack.org/openstack-ops/content/example_architecture.html) kinda gets into it
* A [nova.conf configuration example](http://docs.openstack.org/juno/config-reference/content/section_compute-config-samples.html)

## OpenStack Services

First, note this is a limited install. We're only running a few core services.

Main apis:

* Keystone
* Nova
* Glance
* No cinder
* No neutron

nova_controller_services:

* nova-api
* nova-cert
* nova-consoleauth
* nova-scheduler
* nova-conductor
* nova-novncproxy

nova_compute_services:

* nova-compute
* nova-network
* nova-api-metadata
* nova-conductor

Other controller services:

* Rabbitmq
* MySQL

Listening ports on controller:

```bash
vagrant@controller01:~$ sudo lsof -i -P | grep LISTEN | grep -v sshd
rpcbind     777     root    8u  IPv4   8011      0t0  TCP *:111 (LISTEN)
rpcbind     777     root   11u  IPv6   8014      0t0  TCP *:111 (LISTEN)
rpc.statd   831    statd    8u  IPv4   8113      0t0  TCP *:34749 (LISTEN)
rpc.statd   831    statd   10u  IPv6   8119      0t0  TCP *:43333 (LISTEN)
keystone-  1125 keystone    6u  IPv4  10369      0t0  TCP *:35357 (LISTEN)
keystone-  1125 keystone    7u  IPv4  10370      0t0  TCP *:5000 (LISTEN)
glance-re  1129   glance    4u  IPv4  10284      0t0  TCP *:9191 (LISTEN)
glance-ap  1135   glance    4u  IPv4  10337      0t0  TCP *:9292 (LISTEN)
nova-api   1201     nova    6u  IPv4  10338      0t0  TCP *:8773 (LISTEN)
nova-api   1201     nova    7u  IPv4  10680      0t0  TCP *:8774 (LISTEN)
nova-api   1201     nova    9u  IPv4  10929      0t0  TCP *:8775 (LISTEN)
nova-novn  1213     nova    3u  IPv4  10068      0t0  TCP *:6080 (LISTEN)
epmd       1241 rabbitmq    3u  IPv6   9503      0t0  TCP *:4369 (LISTEN)
mysqld     1288    mysql   10u  IPv4   9823      0t0  TCP *:3306 (LISTEN)
beam       1355 rabbitmq    6u  IPv4  10064      0t0  TCP *:41639 (LISTEN)
beam       1355 rabbitmq   14u  IPv6  10966      0t0  TCP *:5672 (LISTEN)
glance-re  1600   glance    4u  IPv4  10284      0t0  TCP *:9191 (LISTEN)
glance-ap  1632   glance    4u  IPv4  10337      0t0  TCP *:9292 (LISTEN)
nova-api   1634     nova    6u  IPv4  10338      0t0  TCP *:8773 (LISTEN)
keystone-  1638 keystone    6u  IPv4  10369      0t0  TCP *:35357 (LISTEN)
keystone-  1639 keystone    6u  IPv4  10369      0t0  TCP *:35357 (LISTEN)
keystone-  1640 keystone    6u  IPv4  10369      0t0  TCP *:35357 (LISTEN)
keystone-  1640 keystone    7u  IPv4  10370      0t0  TCP *:5000 (LISTEN)
keystone-  1641 keystone    6u  IPv4  10369      0t0  TCP *:35357 (LISTEN)
keystone-  1641 keystone    7u  IPv4  10370      0t0  TCP *:5000 (LISTEN)
nova-api   1689     nova    6u  IPv4  10338      0t0  TCP *:8773 (LISTEN)
nova-api   1689     nova    7u  IPv4  10680      0t0  TCP *:8774 (LISTEN)
nova-api   1729     nova    6u  IPv4  10338      0t0  TCP *:8773 (LISTEN)
nova-api   1729     nova    7u  IPv4  10680      0t0  TCP *:8774 (LISTEN)
nova-api   1729     nova    9u  IPv4  10929      0t0  TCP *:8775 (LISTEN)
```

## Securing novnc

Should probably be fronted by haproxy + ssl.

*Ask OpenStack - [How to setup haproxy with novnc](https://ask.openstack.org/en/question/45966/how-to-properly-setup-haproxy-novnc/)
