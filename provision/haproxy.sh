#!/bin/bash
set -e

# --- Instalar HAProxy ---
sudo apt-get update -y
sudo apt-get install -y haproxy unzip curl
sudo setcap cap_net_bind_service=+ep /usr/sbin/haproxy

# --- Instalar Consul (modo client, se conecta al server en web1) ---
CONSUL_VERSION="1.19.2"
curl -O https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
sudo unzip -o consul_${CONSUL_VERSION}_linux_amd64.zip -d /usr/local/bin/
rm consul_${CONSUL_VERSION}_linux_amd64.zip

# --- Instalar consul-template ---
CT_VERSION="0.39.1"
curl -O https://releases.hashicorp.com/consul-template/${CT_VERSION}/consul-template_${CT_VERSION}_linux_amd64.zip
sudo unzip -o consul-template_${CT_VERSION}_linux_amd64.zip -d /usr/local/bin/
rm consul-template_${CT_VERSION}_linux_amd64.zip

# --- Página de "no disponible" ---
sudo mkdir -p /etc/haproxy/errors
cat <<'EOF' | sudo tee /etc/haproxy/errors/sorry.http
HTTP/1.1 503 Service Unavailable
Content-Type: text/html
Connection: close

<html>
<head><title>Servicio no disponible</title></head>
<body style="font-family: sans-serif; text-align:center; margin-top: 80px;">
<h1>Lo sentimos 😔</h1>
<p>En este momento ningún servidor está disponible para atender tu solicitud.</p>
<p>Por favor intenta de nuevo en unos minutos.</p>
</body>
</html>
EOF

# --- Plantilla de consul-template para generar haproxy.cfg ---
sudo mkdir -p /etc/consul-template.d
sudo cp /vagrant/haproxy/haproxy.cfg.ctmpl /etc/consul-template.d/haproxy.cfg.ctmpl

cat <<EOF | sudo tee /etc/consul-template.d/config.hcl
consul {
  address = "127.0.0.1:8500"
}

template {
  source      = "/etc/consul-template.d/haproxy.cfg.ctmpl"
  destination = "/etc/haproxy/haproxy.cfg"
  command     = "systemctl reload haproxy"
}
EOF

cat <<EOF | sudo tee /etc/systemd/system/consul-template.service
[Unit]
Description=Consul Template
After=network-online.target consul.service

[Service]
ExecStart=/usr/local/bin/consul-template -config=/etc/consul-template.d/config.hcl
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable haproxy
sudo systemctl enable consul-template
sudo systemctl restart consul-template
sudo systemctl restart haproxy
