# Ansible OpenStack Juno

For now this playbook sets up a small OpenStack system with:

* 1x controller
* 2x compute nodes

It uses flat networking.

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

## OpenStack Ansible modules

I use [these great modules](https://github.com/openstack-ansible).

```bash
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
# wait
curtis$ ansible-playbook site.yml
# wait...
```

Now that the basic infrastructure is up, we can add the cirros image and a couple other things.

```bash
curtis$ wget http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
curtis$ ansible-playbook setup.yml
```

Finally we can login to the controller and start a vm. You don't have to login to the controller, but I have put the ```adminrc``` and ```testrc``` files there to easily source an the OpenStack variables.

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
