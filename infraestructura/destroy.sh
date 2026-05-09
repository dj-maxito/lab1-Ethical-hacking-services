#!/bin/bash

# ==========================================================
# SCRIPT DE LIMPIEZA - PROYECTO ETHICALHACKIN
# Este script elimina todos los recursos creados para evitar 
# cargos en AWS.
# ==========================================================

echo "Iniciando limpieza total de recursos ethicalHackin..."

# 1. OBTENER IDs BASADOS EN TAGS
echo "Buscando IDs de recursos..."
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ethicalHackin-webserver" "Name=instance-state-name,Values=running,pending,stopped" --query "Reservations[0].Instances[0].InstanceId" --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ethicalHackin" --query "Vpcs[0].VpcId" --output text)
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text)
VOL_ID=$(aws ec2 describe-volumes --filters "Name=tag:Name,Values=ethicalHackin-datos" --query "Volumes[0].VolumeId" --output text)

# 2. TERMINAR INSTANCIA
if [ "$INSTANCE_ID" != "None" ]; then
    echo "Terminando instancia: $INSTANCE_ID"
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    echo "Esperando a que la instancia se elimine por completo..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
fi

# 3. ELIMINAR VOLUMEN EBS
if [ "$VOL_ID" != "None" ]; then
    echo "Eliminando volumen EBS: $VOL_ID"
    aws ec2 delete-volume --volume-id $VOL_ID
fi

# 4. LIMPIEZA DE RED (VPC Y DEPENDENCIAS)
if [ "$VPC_ID" != "None" ]; then
    echo "Limpiando red de la VPC: $VPC_ID"

    # Desvincular y eliminar Internet Gateway
    if [ "$IGW_ID" != "None" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
    fi

    # Eliminar Subredes
    SUBREDES=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)
    for sub in $SUBREDES; do
        aws ec2 delete-subnet --subnet-id $sub
    done

    # Eliminar Security Groups (excepto el default)
    SGs=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
    for sg in $SGs; do
        aws ec2 delete-security-group --group-id $sg
    done

    # Finalmente eliminar la VPC
    aws ec2 delete-vpc --vpc-id $VPC_ID
fi

echo "=========================================================="
echo "LIMPIEZA COMPLETADA CON ÉXITO"
echo "Todos los recursos del proyecto ethicalHackin han sido eliminados."
echo "=========================================================="