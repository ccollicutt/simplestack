# SimpleStack - OpenStack Juno installed with Ansible

For now this playbook sets up a small OpenStack system with:

* 1x controller
* 2x compute nodes

You could add more compute nodes easily, but not more controllers.

It does not use Neutron, so "legacy" nova-network, and uses flat dhcp. Cinder is not installed either, nor Horizon. About the only extra thing is the fact that haproxy is setup to front the nova and glance apis with ssl.

## Vagrant

Requirements:

* Two or three servers (usuall vagrant virtual machines)
* Trusty 14.04

```bash
curtis$ vagrant box add ubuntu/trusty64
```

I'm using the ```vagrant-cachier``` plugin, but you don't have to; could comment it out in the vagrant file.

## Setup OpenStack

### Clone this repo

```bash
curtis$ git clone git@github.com:ccollicutt/simplestack.git
```

### Edit files

There are some variable files to edit. Make changes as you see fit.

* ```group_vars/all```
* ```group_vars/compute```
* ```group_vars/controller```

There is also a section in the ```site.yml``` file that sets a couple of ansible facts that simplify variables. But they reference the controller hosts interfaces, so would likely need to be changed if you are not using Vagrant.

### Install OpenStack Ansible modules

I use [these great modules](https://github.com/openstack-ansible). I've never been comfortable with git submodules and the like, so they have to be manually installed.

I had to make one small change to the glance module so that is why I'm pulling from my own repo as opposed to the official one. I hope to push that change back upstream as soon as I can find out if it's a good change.

```bash
curtis$ cd simplestack
curtis$ mkdir library
curtis$ cd library
curtis$ git clone https://github.com/ccollicutt/openstack-ansible-modules.git
```

### Run the playbook

```bash
curtis$ vagrant up
# wait...
curtis$ ansible-playbook site.yml
# wait...
```

### Setup OpenStack

With the basic infrastructure up, we can add the Cirros image, configure the default network, etc.

First, download the Cirros image to the root of the playbook.

```bash
curtis$ wget http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
```

Now that we have the Cirros image, we can run the short setup playbook. This will install the Cirros image via glance, add some ssh keys (not really needed though), and a default network called "flatnet" (which sounds mathematical).

```bash
curtis$ ansible-playbook setup.yml
```

### Boot instances

Finally, we can login to the controller and start an instance. You don't have to login to the controller, but I have put the ```adminrc``` and ```testrc``` files there to easily source an the OpenStack variables.

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
* [Why does nova need a public interface?](http://askubuntu.com/questions/118408/why-does-nova-need-a-public-interface)
