#!/bin/bash

# Región configurada
REGION="us-east-1"
AZ1="us-east-1a"
AZ2="us-east-1b"
aws configure set default.region $REGION

echo "Iniciando despliegue de infraestructura para ethicalHackin en la región: $REGION..."

# 2. CREAR LA VPC
echo "Creando VPC..."
export VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=ethicalHackin
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

echo "VPC creada: $VPC_ID"

# 3. CREAR SUBRED PÚBLICA
echo "Creando subred pública..."
export SUBNET_PUB=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 --availability-zone $AZ1 \
  --query 'Subnet.SubnetId' --output text)

aws ec2 create-tags --resources $SUBNET_PUB --tags Key=Name,Value=ethicalHackin-subred-publica
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUB --map-public-ip-on-launch

echo "Subred Pública creada: $SUBNET_PUB"

# 4 CREAR SUBRED PRIVADA
echo "Creando subred privada..."
# Corregido: variable VPC_ID
export SUBNET_PRV=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 --availability-zone $AZ2 \
  --query 'Subnet.SubnetId' --output text)

aws ec2 create-tags --resources $SUBNET_PRV --tags Key=Name,Value=ethicalHackin-subred-privada

echo "Subred Privada creada: $SUBNET_PRV"

# 5. INTERNET GATEWAY
echo "Creando Internet Gateway..."
export IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=ethicalHackin-igw
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

echo "Internet Gateway conectado: $IGW_ID"

# 6. TABLA DE RUTEO
echo "Creando tabla de ruteo..."
export RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=ethicalHackin-rt

aws ec2 create-route --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET_PUB

echo "Tabla de Ruteo configurada: $RT_ID"

# 7. SECURITY GROUP
echo "Creando Security Group..."
export SG_ID=$(aws ec2 create-security-group --group-name "ethicalHackin-sg" \
  --description "Security Group para aplicacion ethicalHackin" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)

aws ec2 create-tags --resources $SG_ID --tags Key=Name,Value=ethicalHackin-sg

aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

IP_PUBLICA=$(curl -s -4 ifconfig.me)
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 22 --cidr ${IP_PUBLICA}/32

echo "Security Group configurado: $SG_ID"

# 8. LANZAR INSTANCIA EC2
echo "Lanzando instancia EC2..."
export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0a29987e14ae814db \
  --instance-type t3.micro \
  --key-name nuevos \
  --subnet-id $SUBNET_PUB \
  --security-group-ids $SG_ID \
  --associate-public-ip-address \
  --user-data '#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
while [ ! -b /dev/nvme1n1 ] && [ ! -b /dev/xvdf ]; do sleep 5; done
if [ -b /dev/nvme1n1 ]; then DISCO="/dev/nvme1n1"; else DISCO="/dev/xvdf"; fi
mkfs -t ext4 $DISCO
mkdir -p /mnt/datos
mount $DISCO /mnt/datos
echo "<h1>Bienvenido al sistema ethicalHackin</h1>" > /mnt/datos/index.html
rm -rf /var/www/html
ln -s /mnt/datos /var/www/html' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=ethicalHackin-webserver

echo "Lanzando instancia EC2: $INSTANCE_ID..."

# 9. ESPERAR A QUE LA INSTANCIA ESTÉ LISTA
echo "Esperando a que la instancia se inicialice..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# 10. CREAR Y ADJUNTAR VOLUMEN EBS
echo "Creando volumen EBS de 8GB..."
export VOL_ID=$(aws ec2 create-volume --size 8 --volume-type gp3 \
  --availability-zone $AZ1 --query 'VolumeId' --output text)

aws ec2 create-tags --resources $VOL_ID --tags Key=Name,Value=ethicalHackin-datos

echo "Esperando a que el volumen esté disponible..."
aws ec2 wait volume-available --volume-ids $VOL_ID

echo "Adjuntando volumen..."
aws ec2 attach-volume --volume-id $VOL_ID --instance-id $INSTANCE_ID --device /dev/sdf

echo "Volumen $VOL_ID adjuntado."

# 11. VERIFICACIÓN FINAL
export PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "=========================================================="
echo "DESPLIEGUE EXITOSO"
echo "Dirección IP Pública: $PUBLIC_IP"
echo "URL del sitio: http://$PUBLIC_IP"
echo "=========================================================="