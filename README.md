# Ansible OpenStack Juno

This playbook will, at some point, install a basic highly availalble (HA) configuration of OpenStack Juno. Now, HA can mean a lot of different things to a lot of different people, but I do have some guiding principles:

* This is for testing, not production
* The virtual machines should be available and working if the controller(s) go down, thus a multi-host configuration
* Active/Passive
* The switchover from one controller to another will be manual in terms of running the final command, but otherwise automated
* As simple as possible, but not simpler
* No live migration, only controller HA in an active/passive type setup

## Getting started

Requirements:

* Vagrant
* Base trusty box

```bash
curtis$ vagrant box add ubuntu/trusty64
```

## OpenStack Ansible modules

I use these great modules.

```bash
curtis$ mkdir library
curtis$ cd library
curtis$ git clone https://github.com/openstack-ansible/openstack-ansible-modules.git
```
Then install OpenStack clients client.

```bash
curtis$ sudo apt-get install python-dev
curtis$ sudo pip install python-novaclient
```
