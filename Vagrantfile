Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # --- Web server 1 (agente Consul server + Node.js) ---
  config.vm.define "web1" do |web1|
    web1.vm.hostname = "web1"
    web1.vm.network "private_network", ip: "192.168.56.11"
    web1.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    web1.vm.provision "shell", path: "provision/consul-server.sh", args: ["192.168.56.11"]
    web1.vm.provision "shell", path: "provision/webapp.sh", args: ["web1"]
  end

  # --- Web server 2 (agente Consul client + Node.js) ---
  config.vm.define "web2" do |web2|
    web2.vm.hostname = "web2"
    web2.vm.network "private_network", ip: "192.168.56.12"
    web2.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    web2.vm.provision "shell", path: "provision/consul-client.sh", args: ["192.168.56.12", "192.168.56.11"]
    web2.vm.provision "shell", path: "provision/webapp.sh", args: ["web2"]
  end

  # --- Balanceador HAProxy (agente Consul client + HAProxy + consul-template) ---
  config.vm.define "haproxy" do |lb|
    lb.vm.hostname = "haproxy"
    lb.vm.network "private_network", ip: "192.168.56.10"
    lb.vm.network "forwarded_port", guest: 8404, host: 8404  # dashboard de stats
    lb.vm.network "forwarded_port", guest: 80, host: 8080     # entrada de tráfico
    lb.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    lb.vm.provision "shell", path: "provision/consul-client.sh", args: ["192.168.56.10", "192.168.56.11"]
    lb.vm.provision "shell", path: "provision/haproxy.sh"
  end
end
