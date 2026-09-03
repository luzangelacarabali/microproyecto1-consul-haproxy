#!/bin/bash
set -e
IP=$1

sudo apt-get update -y
sudo apt-get install -y unzip curl jq

CONSUL_VERSION="1.19.2"
curl -O https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
sudo unzip -o consul_${CONSUL_VERSION}_linux_amd64.zip -d /usr/local/bin/
rm consul_${CONSUL_VERSION}_linux_amd64.zip

sudo mkdir -p /etc/consul.d /var/consul
sudo useradd --system --home /var/consul --shell /bin/false consul || true
sudo chown -R consul:consul /var/consul

cat <<EOF | sudo tee /etc/consul.d/server.json
{
  "server": true,
  "bootstrap_expect": 1,
  "datacenter": "dc1",
  "data_dir": "/var/consul",
  "bind_addr": "$IP",
  "client_addr": "0.0.0.0",
  "ui_config": { "enabled": true }
}
EOF

cat <<EOF | sudo tee /etc/systemd/system/consul.service
[Unit]
Description=Consul
After=network-online.target

[Service]
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
Restart=on-failure
User=consul

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable consul
sudo systemctl restart consul
