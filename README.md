# # Ethical Hacking services (Laboratorio taller informatica)

# Services

**Autores:** Benjamin Uribe y Max Coñoman

Este repositorio contiene la solución de infraestructura
automatizada para el despliegue del portal **Ethical Hacking
Services**. El proyecto integra herramientas de AWS CLI y
administración avanzada de servidores Linux para garantizar
un entorno web persistente, seguro y escalable.

## ##  Arquitectura de Infraestructura

## (`deploy.sh`)

El script de automatización despliega un entorno completo en
la nube de AWS (región us-east-1) que incluye:

```
VPC & Networking:
Una VPC dedicada con direccionamiento 10.0.0.0/16.
Subredes públicas y privadas distribuidas en zonas de
disponibilidad us-east-1a y us-east-1b.
Internet Gateway y tablas de ruteo para el tráfico
externo.
Seguridad Perimetral:
Puerto 80 (HTTP): Habilitado para acceso público al
sitio web.
Puerto 22 (SSH): Restringido dinámicamente a la IP del
administrador.
Cómputo y Almacenamiento:
Instancia EC2 de tipo t3.micro.
Volumen EBS independiente de 8GB (gp3): Configurado
para datos críticos.
```
#### • ◦ ◦ ◦ • ◦ ◦ • ◦ ◦


## ##  Configuración del Servidor y

## Persistencia

Durante el arranque, el script realiza las siguientes
operaciones técnicas:

```
Gestión de Discos: Detecta el volumen de 8GB (/dev/
nvme1n1), lo formatea con ext4 y lo monta en /mnt/datos.
Optimización de Apache: Se configuró un enlace simbólico
(symlink) para que /var/www/html apunte directamente a /
mnt/datos.
Seguridad: Se aplican permisos 755 y propiedad al
usuario apache/www-data.
```
## ##  Guía de Despliegue

### ### 1. Preparación Local

### ### 2. Carga del Contenido Web (SCP)

### ### 3. Sincronización Final

#### 1.

#### 2.

#### 3.

```
chmod +x deploy.sh
chmod 400 nuevos.pem
./deploy.sh
```
```
scp -i nuevos.pem -r ./sitio-web/src/* ec2-user@3.227.16.224:/home/ec2-user/
```
```
ssh -i nuevos.pem ec2-user@3.227.16.
```
```
# Ejecutar dentro del servidor:
sudo mv /home/ec2-user/* /mnt/datos/
sudo chown -R apache:apache /mnt/datos
sudo chmod -R 755 /mnt/datos
sudo systemctl restart httpd
```

## ##  Acceso al Sitio

```
URL Pública: http://3.227.16.224/
```

