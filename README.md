# Microproyecto 1 — Cluster Consul + Balanceador HAProxy + Artillery

Computación en la Nube — Universidad Autónoma de Occidente

## Arquitectura

3 máquinas virtuales Vagrant (VirtualBox), en red privada `192.168.56.0/24`:

- **web1** (`192.168.56.11`) — agente Consul en modo *server* (bootstrap del clúster) + 2 réplicas de una app Node.js (puertos 3000 y 3001)
- **web2** (`192.168.56.12`) — agente Consul en modo *client* + 2 réplicas de la misma app Node.js (puertos 3000 y 3001)
- **haproxy** (`192.168.56.10`) — agente Consul en modo *client* + HAProxy + consul-template

HAProxy no tiene los backends escritos a mano: **consul-template** consulta el catálogo de Consul en tiempo real y regenera `haproxy.cfg` automáticamente cada vez que aparece o desaparece una instancia sana del servicio `webapp`.

## Cómo levantarlo

```bash
vagrant up
```

Tarda varios minutos la primera vez (descarga la box e instala Consul, Node.js, HAProxy y consul-template en cada VM). Todo el aprovisionamiento es automático vía shell scripts (`provision/*.sh`), sin intervención manual.

## Verificación

- Ver el clúster de Consul: `vagrant ssh web1` → `consul members`
- Ver el balanceo en el navegador: `http://192.168.56.10/`
- Dashboard de estadísticas de HAProxy: `http://192.168.56.10:8404/stats`
- Probar con curl: `curl http://192.168.56.10`

## Requisitos cumplidos

1. **Cluster Consul**: 3 nodos (1 server + 2 client), verificado con `consul members`.
2. **Aprovisionamiento automático**: Vagrant + shell provisioners.
3. **Escalabilidad**: 2 réplicas por VM web (4 backends totales), registradas en Consul con IDs únicos; HAProxy las adopta automáticamente vía consul-template sin tocar su configuración.
4. **Página de disculpas**: si ningún backend está disponible, HAProxy responde con un `503` y una página personalizada (`haproxy/sorry.html`).
5. **Pruebas de carga con Artillery**: `artillery/load-test.yml` con 4 fases (5, 20, 50 req/s estables, y una rampa de 50 a 500 req/s). El sistema se mantiene sin errores hasta ~50 req/s; el punto de quiebre (timeouts) aparece entre 150-230 req/s.

## Estructura del proyecto
├── Vagrantfile
├── provision/ # scripts de aprovisionamiento por rol
├── app/ # código de la app Node.js
├── consul/ # definición de servicio para Consul
├── haproxy/ # plantilla de HAProxy y página de error
└── artillery/ # escenarios de prueba de carga
