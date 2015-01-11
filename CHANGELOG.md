# Changelog

## v0.2.2

* Updated instructions
* Make vm requirements a bit smaller, because even though I have a new laptop it doesn't have as much memory as my last one

## v0.2.1

* Configured syslog on compute nodes to send to controller
* Upped the compute nodes to 4096 and 4 cpus
* Added a modest flavor, 512MB and 10GB disk, 1 cpu
* Changed the "flatnet" to be part of the 192.168.99.0/24 network, instead of a small network within, limited to 192.168.99.40-60
* bugfix: mysql password in two spots


## v0.2

* Haproxy is "ssl-ifying" the frontend apis
* Reorg to remove controller-secondary, as changed focus from HA to simple controller + compute
* Added more ntp checks, configuration
* Setup variables in site.yml to make them a bit cleaner

## v0.1.1

* v0.1 with an updated README file


## v0.1

* First working version
