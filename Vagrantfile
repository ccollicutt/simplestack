# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

boxes = [
    {
        :name => :controller01,
        :pubip => '192.168.10.11',
        :intip => '10.1.10.11',
        :flatip => '192.168.99.11',
        :box => 'ubuntu/trusty64',
        :vbox_config => [
            { '--memory' => '2048' }
        ],
    },
    {
        :name => :compute01,
        :pubip => '192.168.10.21',
        :intip => '10.1.10.21',
        :flatip => '192.168.99.21',
        :box => 'ubuntu/trusty64',
        :vbox_config => [
            {
              '--memory' => '2048',
              '--nicpromisc4' => 'allow-all'
            }
        ],
    },
    {
        :name => :compute02,
        :pubip => '192.168.10.22',
        :intip => '10.1.10.22',
        :flatip => '192.168.99.22',
        :box => 'ubuntu/trusty64',
        :vbox_config => [
            {
              '--memory' => '2048',
              '--nicpromisc4' => 'allow-all'
            }
        ],
    },
]

Vagrant.configure("2") do |config|

    Vagrant.require_version ">= 1.5.0"

    if Vagrant.has_plugin?("vagrant-cachier")
        config.cache.scope = :machine
    end

    boxes.each do |opts|
        config.vm.define opts[:name] do |config|
            # Box basics
            config.vm.hostname = opts[:name]
            config.vm.box = opts[:box]
            config.vm.network :private_network, ip: opts[:pubip]
            config.vm.network :private_network, ip: opts[:intip]
            config.vm.network :private_network, ip: opts[:flatip]
            config.ssh.forward_agent = true

            # VirtualBox customizations
            unless opts[:vbox_config].nil?
                config.vm.provider :virtualbox do |vb|

                    # vboxmanage
                    opts[:vbox_config].each do |hash|
                        hash.each do |key, value|
                            vb.customize ['modifyvm', :id, key, value]
                        end
                    end
                end
            end
        end
    end
end
