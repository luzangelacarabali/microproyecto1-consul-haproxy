#!/bin/bash
set -e
NODE_NAME=$1
PORTS=("3000" "3001")

curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

sudo mkdir -p /opt/app
cat <<'EOF' | sudo tee /opt/app/server.js
const http = require('http');
const port = process.env.PORT || 3000;
const hostname = process.env.NODE_NAME || require('os').hostname();

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    res.end('OK');
    return;
  }

  const isWeb1 = hostname.startsWith('web1');
  const color = isWeb1 ? '#2563eb' : '#16a34a';
  const bgColor = isWeb1 ? '#eff6ff' : '#f0fdf4';

  const html = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Microproyecto 1 - Cluster Consul + HAProxy</title>
  <link rel="icon" href="data:,">
  <style>
    body {
      font-family: -apple-system, sans-serif;
      background-color: ${bgColor};
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background: white;
      border-radius: 16px;
      padding: 48px 64px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
      text-align: center;
      border-top: 8px solid ${color};
    }
    h1 {
      color: ${color};
      font-size: 3rem;
      margin: 0 0 8px 0;
    }
    p {
      color: #64748b;
      font-size: 1.1rem;
      margin: 4px 0;
    }
    .port {
      display: inline-block;
      background: ${color};
      color: white;
      padding: 4px 14px;
      border-radius: 20px;
      font-weight: bold;
      margin-top: 12px;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>${hostname}</h1>
    <p>Respuesta servida por este nodo</p>
    <span class="port">Puerto ${port}</span>
  </div>
</body>
</html>`;

  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(html);
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Servidor corriendo en ${hostname}:${port}`);
});
EOF

sudo mkdir -p /etc/consul.d

for PORT in "${PORTS[@]}"; do
  cat <<EOF | sudo tee /etc/systemd/system/webapp-${PORT}.service
[Unit]
Description=Node webapp on port ${PORT}
After=network.target

[Service]
Environment=NODE_NAME=$NODE_NAME
Environment=PORT=${PORT}
ExecStart=/usr/bin/node /opt/app/server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  cat <<EOF | sudo tee /etc/consul.d/webapp-${PORT}.json
{
  "service": {
    "id": "webapp-${NODE_NAME}-${PORT}",
    "name": "webapp",
    "port": ${PORT},
    "check": {
      "http": "http://localhost:${PORT}/health",
      "interval": "5s",
      "timeout": "1s"
    }
  }
}
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable webapp-${PORT}
  sudo systemctl restart webapp-${PORT}
done

sudo systemctl restart consul
