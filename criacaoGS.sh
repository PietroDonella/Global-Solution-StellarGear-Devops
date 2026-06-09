#!/bin/bash
GRUPO="stellargear"
LOCATION="brazilsouth"
USER="admin_fiap"
PASSWORD="Fiap_devops_SG"
RG="rg-$GRUPO"
VNET="vnet-$GRUPO"
SUBNET="subnet-$GRUPO"
NSG="nsg-$GRUPO"
VM="vm-$GRUPO"

echo "1. Criando Resource Group e Redes..."
az group create --name $RG --location $LOCATION --tags owner=$GRUPO environment=gs cost-center=fiap
az network vnet create --resource-group $RG --name $VNET --address-prefix 10.10.0.0/16 --subnet-name $SUBNET --subnet-prefix 10.10.1.0/24

echo "2. Criando Regras de Firewall (NSG)..."
az network nsg create --resource-group $RG --name $NSG
az network nsg rule create --resource-group $RG --nsg-name $NSG --name allow-ssh --protocol Tcp --priority 1000 --destination-port-range 22 --access Allow
az network nsg rule create --resource-group $RG --nsg-name $NSG --name allow-8080 --protocol Tcp --priority 1001 --destination-port-range 8080 --access Allow
az network nsg rule create --resource-group $RG --nsg-name $NSG --name allow-1521 --protocol Tcp --priority 1002 --destination-port-range 1521 --access Allow
az network vnet subnet update --resource-group $RG --vnet-name $VNET --name $SUBNET --network-security-group $NSG

echo "3. Criando a Maquina Virtual Linux..."
az vm create --resource-group $RG --name $VM --image Ubuntu2204 --admin-username $USER --admin-password $PASSWORD --authentication-type password --size Standard_E2s_v3 --vnet-name $VNET --subnet $SUBNET --nsg $NSG

echo "4. Instalando Docker e Subindo o Banco Oracle..."
az vm run-command invoke --resource-group $RG --name $VM --command-id RunShellScript --scripts '
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git nano

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

sudo usermod -aG docker admin_fiap

sudo docker network create stellargear-network
sudo docker volume create oracle-stellargear-data

sudo docker run -d --name db_RM_561722 \
  -p 1521:1521 \
  -v oracle-stellargear-data:/opt/oracle/oradata \
  --network stellargear-network \
  -e ORACLE_PASSWORD="Fiap_devops_SG" \
  gvenzl/oracle-xe
'