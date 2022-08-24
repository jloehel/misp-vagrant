# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.provision :shell, path: "bootstrap.sh"

  config.vm.network :forwarded_port, guest: 80, host: 5000
  config.vm.network :forwarded_port, guest: 6666, host: 6666

  disabled = false
  vm_name = "MISP - Ubuntu 21.04 - DEV"
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

  # TODO: Provision maridadb/mysql with ansible
  # TODO: Provision redis with ansible
  # TODO: Provision php & apache with ansible
  # TODO: Nginx or Apache2 setup
  # TODO: Add misp role + playbook
  # TODO: Switch version by checkout <version>
  # TODO: feature branch support
  # TODO: seperate files and configs to volume because it should not change when I switch to another
  # version or feature branch
  # TODO: Use a python virtual env for the python dependencies
  # TODO: Add tags to re-provision only parts
  # TODO: Switch OS by ENV:
  #       - Ubuntu
  #       - SUSE
  #       - CentOS
  # TODO: Re-Introduce non-dev env
  # TODO: Switch between different configuration easily
  # TODO: Lower the password policy for dev
  # TODO: Find out why PHP8.0 is not supported. So far it looks fine.
  #       https://php.watch/versions/8.0/xmlrpc < Why a experimental lib which
  #       is not maintained anymore? Same like that old cakephp.
  # TODO: Make it easier to switch between different php versions
  # TODO: Test different versions of the misp-modules
end
