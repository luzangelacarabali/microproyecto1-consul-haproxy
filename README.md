# Microproyecto 1 — Cluster Consul + Balanceador HAProxy + Artillery

**Computación en la Nube — Universidad Autónoma de Occidente**

Este proyecto monta un mini "service mesh" con Hashicorp Consul, un balanceador de carga HAProxy que descubre sus backends automáticamente a través de Consul (sin IPs escritas a mano), y pruebas de carga con Artillery para caracterizar cómo responde el sistema bajo distintos niveles de tráfico.

Todo corre sobre 3 máquinas virtuales levantadas y configuradas automáticamente con Vagrant — nada se instala ni se configura a mano dentro de las VMs.

---

## Qué vas a encontrar aquí

- Un clúster de Consul con 3 nodos, cada uno registrando un servicio web.
- HAProxy balanceando tráfico hacia esos servicios, con su configuración generada dinámicamente (no estática) gracias a `consul-template`.
- Una página de disculpas personalizada que aparece automáticamente si todos los servidores caen.
- Escenarios de carga con Artillery que muestran hasta qué punto el sistema aguanta tráfico sin degradarse.

---

## Estructura del proyecto

```
.
├── Vagrantfile           # define las 3 VMs, sus IPs y qué scripts corre cada una
├── provision/            # scripts de aprovisionamiento, uno por rol
│   ├── consul-server.sh
│   ├── consul-client.sh
│   ├── webapp.sh
│   └── haproxy.sh
├── app/
│   └── server.js         # servidor Node.js que responde con su hostname y puerto
├── consul/
│   └── webapp-service.json
├── haproxy/
│   ├── haproxy.cfg.ctmpl  # plantilla que consul-template resuelve dinámicamente
│   └── sorry.html         # página de disculpas para cuando no hay servidores
└── artillery/
    └── load-test.yml      # escenarios de prueba de carga
```

---

## Antes de empezar: lo que necesitas instalado

Este proyecto asume que trabajas sobre Linux (Ubuntu/Debian). Si tu máquina ya tiene VirtualBox, Vagrant y Git instalados, puedes saltar directo a la sección "Clonar y levantar el proyecto". Si no, aquí va cómo instalarlos desde cero.

### 1. VirtualBox

```bash
sudo apt-get update -y
sudo apt-get install -y virtualbox
```

Verifica que quedó instalado:

```bash
VBoxManage --version
```

**Importante:** tu usuario necesita pertenecer al grupo `vboxusers` para poder controlar las máquinas virtuales sin errores de permisos. Agrégate al grupo y **reinicia tu sesión o la máquina** (los cambios de grupo no se aplican hasta que vuelvas a iniciar sesión):

```bash
sudo usermod -aG vboxusers $USER
```

Después de reiniciar, confirma que el grupo ya aparece:

```bash
groups
```

Deberías ver `vboxusers` en la lista.

### 2. Vagrant

```bash
sudo apt-get install -y vagrant
```

Verifica:

```bash
vagrant --version
```

### 3. Git

```bash
sudo apt-get install -y git
```

Verifica:

```bash
git --version
```

---

## Clonar y levantar el proyecto

### 1. Clona el repositorio

```bash
git clone https://github.com/luzangelacarabali/microproyecto1-consul-haproxy.git
cd microproyecto1-consul-haproxy
```

### 2. Levanta las 3 máquinas virtuales

```bash
vagrant up
```

Este comando hace todo el trabajo pesado: crea las 3 VMs (`web1`, `web2`, `haproxy`), les asigna IPs fijas en una red privada, y corre los scripts de aprovisionamiento (`provision/*.sh`) que instalan y configuran Consul, Node.js, HAProxy y consul-template en cada una — sin que tengas que entrar a ninguna VM a mano.

La primera vez tarda varios minutos, porque descarga la imagen base de Ubuntu y todos los binarios necesarios. Vas a ver mucho texto de `apt-get` corriendo — es normal, déjalo terminar.

Si en algún momento necesitas volver a correr solo el aprovisionamiento (por ejemplo, después de editar un script) sin recrear las VMs desde cero:

```bash
vagrant provision web1 web2 haproxy
```

O si prefieres reaprovisionar solo una VM puntual:

```bash
vagrant provision haproxy
```

### 3. Confirma que las 3 VMs están corriendo

```bash
vagrant status
```

Deberías ver `web1`, `web2` y `haproxy`, los tres en estado `running`.

---

## Verificando que todo funciona, paso a paso

### Paso 1 — El clúster de Consul se formó correctamente

Entra a `web1` por SSH:

```bash
vagrant ssh web1
```

Y una vez dentro, pregúntale a Consul quiénes son sus miembros:

```bash
consul members
```

Deberías ver una tabla con los 3 nodos (`web1`, `web2`, `haproxy`), todos en estado `alive`. `web1` aparece como `server` (el que hace bootstrap del clúster) y los otros dos como `client`.

Sal de la VM cuando termines:

```bash
exit
```

### Paso 2 — HAProxy generó su configuración solo, a partir de Consul

Entra a la VM de `haproxy`:

```bash
vagrant ssh haproxy
```

Revisa el archivo de configuración que HAProxy está usando de verdad:

```bash
cat /etc/haproxy/haproxy.cfg
```

En el backend `webapp_back` deberías ver líneas `server` con las IPs de `web1` y `web2` — pero **tú nunca las escribiste a mano**. Ese archivo lo genera automáticamente `consul-template`, consultando a Consul en tiempo real. Puedes confirmarlo mirando la plantilla original, que sí está en el repo:

```bash
cat /vagrant/haproxy/haproxy.cfg.ctmpl
```

Ahí vas a ver algo como `{{range service "webapp"}}` en vez de IPs fijas — esa sintaxis es la que consul-template resuelve dinámicamente.

### Paso 3 — El balanceo de carga funciona

Sigues dentro de `haproxy` (o puedes hacerlo desde tu máquina anfitriona apuntando a la misma IP). Prueba varias veces seguidas:

```bash
curl http://192.168.56.10
curl http://192.168.56.10
curl http://192.168.56.10
curl http://192.168.56.10
```

Vas a ver la respuesta alternando entre las distintas instancias (`web1`, `web2`, y sus réplicas) — esa rotación es HAProxy repartiendo el tráfico con el algoritmo `roundrobin`.

Para verlo de forma más visual, abre esto en tu navegador (desde tu máquina anfitriona, no desde dentro de una VM):

```
http://192.168.56.10/
```

Vas a ver una tarjeta con el nombre del nodo y el puerto que respondió, cambiando de color según sea `web1` (azul) o `web2` (verde). Si refrescas y no ves cambios, prueba con `Ctrl+Shift+R` (recarga forzada sin caché) o abre una pestaña nueva — algunos navegadores reutilizan la conexión y no siempre disparan una petición nueva con un simple F5.

### Paso 4 — El dashboard de estadísticas de HAProxy

Desde tu navegador:

```
http://192.168.56.10:8404/stats
```

Ahí vas a ver el estado de cada servidor del backend (`UP` en verde si está sano), cuántas sesiones ha atendido cada uno, y estadísticas de tráfico en tiempo real — todo accesible desde tu máquina anfitriona, sin entrar a ninguna VM.

### Paso 5 — Escalabilidad: réplicas de los servidores web

El proyecto ya viene configurado con 2 réplicas por cada VM web (`web1` corre en los puertos 3000 y 3001, igual `web2`), registradas en Consul con IDs únicos pero bajo el mismo nombre de servicio (`webapp`). Eso le permite a HAProxy verlas como 4 backends independientes sin que tú hayas tocado su configuración.

Verifícalo entrando a cualquiera de las VMs web:

```bash
vagrant ssh web1
curl -s http://localhost:8500/v1/health/service/webapp?pretty
```

Vas a ver las 4 instancias listadas (`webapp-web1-3000`, `webapp-web1-3001`, `webapp-web2-3000`, `webapp-web2-3001`), todas con estado `passing` en su health check.

### Paso 6 — La página de disculpas cuando no hay servidores disponibles

Para provocar este escenario, apaga las 4 instancias de la aplicación. Entra a `web1`:

```bash
vagrant ssh web1
sudo systemctl stop webapp-3000
sudo systemctl stop webapp-3001
exit
```

Y a `web2`:

```bash
vagrant ssh web2
sudo systemctl stop webapp-3000
sudo systemctl stop webapp-3001
exit
```

Espera unos 10-15 segundos (el health check de Consul revisa cada 5 segundos, y consul-template necesita un momento para reaccionar al cambio). Después prueba:

```bash
curl -i http://192.168.56.10
```

Deberías ver un `HTTP/1.1 503 Service Unavailable` junto con el HTML de una página de disculpas personalizada, en vez de un error genérico de conexión.

Para volver todo a la normalidad, reactiva las 4 instancias:

```bash
vagrant ssh web1
sudo systemctl start webapp-3000
sudo systemctl start webapp-3001
exit

vagrant ssh web2
sudo systemctl start webapp-3000
sudo systemctl start webapp-3001
exit
```

Confirma que volvió a responder:

```bash
curl http://192.168.56.10
```

### Paso 7 — Pruebas de carga con Artillery

Artillery corre desde tu máquina anfitriona (no desde ninguna VM), porque simula tráfico llegando "desde afuera" hacia el balanceador — igual que clientes reales lo harían.

Si no lo tienes instalado, necesitas Node.js 20 o superior en tu máquina anfitriona:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
```

Con Node 20+ confirmado, instala Artillery globalmente:

```bash
sudo npm install -g artillery
artillery --version
```

Y corre el archivo de escenarios que ya viene en el repo:

```bash
artillery run artillery/load-test.yml
```

Esto ejecuta 4 fases de tráfico creciente: 5, 20 y 50 peticiones por segundo (estables, 30 segundos cada una), y después una rampa que sube de 50 a 500 peticiones por segundo en 60 segundos. Al final vas a ver un resumen (`Summary report`) con el total de peticiones, tasa de error, y estadísticas de latencia (`min`, `mean`, `p95`, `p99`).

**Lo que deberías observar:** el sistema se mantiene sólido (0% de errores, latencias de pocos milisegundos) hasta aproximadamente 50 peticiones por segundo. A partir de ahí, en la fase de rampa, empiezan a aparecer errores `ETIMEDOUT` — ese es el punto real de saturación del sistema, donde los 4 procesos Node.js (cada uno single-threaded) ya no logran atender la demanda a tiempo.

---

## Apagar o eliminar el entorno

Si quieres apagar las VMs sin borrarlas (para prenderlas de nuevo más rápido después):

```bash
vagrant halt
```

Para volver a prenderlas:

```bash
vagrant up
```

Si quieres destruir todo por completo (por ejemplo, para reconstruir desde cero si algo quedó en mal estado):

```bash
vagrant destroy -f
```

Y para volver a levantarlo desde cero:

```bash
vagrant up
```

---

## Requisitos del enunciado — checklist

1. **Cluster Consul**: 3 nodos (1 server + 2 client), verificado con `consul members`.
2. **Aprovisionamiento automático**: Vagrant + shell provisioners, sin intervención manual.
3. **Escalabilidad**: 2 réplicas por VM web (4 backends totales), registradas en Consul con IDs únicos; HAProxy las adopta automáticamente vía consul-template sin tocar su configuración.
4. **Página de disculpas**: si ningún backend está disponible, HAProxy responde con un `503` y una página personalizada (`haproxy/sorry.html`).
5. **Pruebas de carga con Artillery**: 4 escenarios que caracterizan el sistema desde tráfico bajo hasta el punto de quiebre real (entre 150-230 req/s).
