# -*- mode: ruby -*-
# vi: set ft=ruby :

MISP_ENV = ENV['MISP_ENV'] || 'dev'

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.provision :shell, path: "bootstrap.sh", args: MISP_ENV.to_s

  config.vm.network :forwarded_port, guest: 80, host: 5000
  config.vm.network :forwarded_port, guest: 6666, host: 6666

  disabled = true
  vm_name = "MISP - Ubuntu 18.04"
  if MISP_ENV.to_s == "dev"
    disabled = false
    vm_name.concat(" - DEV")
  end
  config.vm.synced_folder "..", "/var/www/MISP",
                          owner: "www-data", group: "www-data", disabled: disabled

  config.vm.provider "virtualbox" do |vb|
    #   # Don't boot with headless mode
    #   vb.gui = true
    #
    #   # Use VBoxManage to customize the VM. For example to change memory:
    vb.customize ["modifyvm", :id, "--memory", "2048"]
    vb.customize ["modifyvm", :id, "--name", vm_name]
  end
end
