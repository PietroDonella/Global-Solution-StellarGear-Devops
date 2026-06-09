# Stellar Gear API - Global Solution 2026/1

### 👥 Integrantes
*  **Enzo Vaz** – RM: 561702 
*  **Lucas Ryuji Fukuda**  – RM: 562152 
*  **Pietro Donella Salomão** – RM: 561722

## 🚀 Sobre o Projeto
O **Stellar Gear** é uma solução de monitoramento biométrico voltada para o turismo espacial e ambientes extremos (como mineração e usinas). O sistema coleta sinais vitais via IoT (simulados via Wokwi/ESP32) e os envia para a nuvem. Nossa API .NET atua como o backend de alta performance que ingere, processa e persiste esses dados em um banco de dados relacional Oracle, garantindo a segurança e o monitoramento da saúde dos passageiros.

## 🏗️ Arquitetura Macro da Solução
A infraestrutura foi construída na nuvem seguindo a abordagem de *Infrastructure as Code (IaC)* e princípios de *Cloud Native*.

![Diagrama de Arquitetura](./diagrama-arquitetura.png)

### Componentes:
* **Cloud Provider:** Microsoft Azure (Brazil South).
* **Virtual Network:** Rede isolada com Network Security Group (NSG) filtrando tráfego.
* **Compute:** Máquina Virtual Ubuntu 22.04 LTS.
* **Container Engine:** Docker orquestrando a aplicação e o banco em uma rede *bridge* interna (`stellargear-network`).
* **Database:** Oracle XE 21c com persistência de dados em *Docker Volume*.
* **API Backend:** ASP.NET Core 10.0 rodando sob usuário restrito (Non-root).

---

## 🛠️ How-To: Guia de Execução (Do Zero à Nuvem)

Este tutorial descreve como subir o projeto completo, desde a criação da infraestrutura até a execução e testes da API.

### Passo 1: Infraestrutura e Banco de Dados (Azure Cloud Shell)
Provisione os recursos na nuvem e inicie o banco de dados Oracle com um volume persistente para evitar perda de dados.

    az group create --name rg-stellargear --location brazilsouth
    az network vnet create --resource-group rg-stellargear --name vnet-stellargear --address-prefix 10.10.0.0/16 --subnet-name subnet-stellargear --subnet-prefix 10.10.1.0/24
    az network nsg create --resource-group rg-stellargear --name nsg-stellargear
    az network nsg rule create --resource-group rg-stellargear --nsg-name nsg-stellargear --name allow-ssh --protocol Tcp --priority 1000 --destination-port-range 22 --access Allow
    az network nsg rule create --resource-group rg-stellargear --nsg-name nsg-stellargear --name allow-8080 --protocol Tcp --priority 1001 --destination-port-range 8080 --access Allow
    az network nsg rule create --resource-group rg-stellargear --nsg-name nsg-stellargear --name allow-1521 --protocol Tcp --priority 1002 --destination-port-range 1521 --access Allow
    az network vnet subnet update --resource-group rg-stellargear --vnet-name vnet-stellargear --name subnet-stellargear --network-security-group nsg-stellargear

    # Após criar a VM e instalar o Docker, crie a rede e suba o banco:
    docker network create stellargear-network
    docker volume create oracle-stellargear-data
    docker run -d --name db_RM_561722 -p 1521:1521 -v oracle-stellargear-data:/opt/oracle/oradata --network stellargear-network -e ORACLE_PASSWORD="Fiap_devops_SG" gvenzl/oracle-xe

### Passo 2: Clonagem e Migrations (Terminal da VM)
Acesse sua Máquina Virtual via SSH. Clone este repositório e aplique a estrutura do banco usando o Entity Framework dentro de um container efêmero (para manter o servidor limpo).

    git clone https://github.com/SEU_GITHUB_AQUI/StellarGear.API.git
    cd StellarGear.API

    # Configurar appsettings.json apontando para o container interno:
    # "OracleConnection": "Data Source=db_RM_561722:1521/XEPDB1;User Id=system;Password=Fiap_devops_SG;"

    docker run --rm -it -v $(pwd):/src --network stellargear-network -w /src mcr.microsoft.com/dotnet/sdk:10.0 bash -c "dotnet restore && dotnet tool install --global dotnet-ef && export PATH=\"\$PATH:/root/.dotnet/tools\" && dotnet ef database update --project StellarGear.Infrastructure --startup-project StellarGear.API"

### Passo 3: Deploy da Aplicação
Faça o build da imagem Docker utilizando nosso *Dockerfile multi-stage* e execute o container da API.

    docker build -t stellargear-api-image .
    docker run -d --name api_RM_561722 -p 8080:8080 --network stellargear-network stellargear-api-image

---

## 🔗 Endpoints e Testes do CRUD
Após a API estar em execução, você pode testar o CRUD completo enviando requisições HTTP para o IP Público da sua VM na porta `8080` (ex: `http://IP_DA_VM:8080/api/Passageiro`).

* **GET `/api/Passageiro`**: Retorna a lista de todos os passageiros cadastrados.
* **POST `/api/Passageiro`**: Cria um novo passageiro.
* **PUT `/api/Passageiro/{id}`**: Atualiza informações (como o status médico) de um passageiro.
* **DELETE `/api/Passageiro/{id}`**: Remove um passageiro do sistema.

**Exemplo de Payload (POST - Cadastro de Passageiro):**

    {
      "nome": "Aron Turista",
      "cpf": "111.111.111-11",
      "idade": 34,
      "statusMedico": "APTO"
    }

---

## 🛡️ DevOps & Critérios de Avaliação Atendidos
Esta entrega foi arquitetada para demonstrar pleno domínio técnico em práticas de DevOps:

1. **Princípio do Menor Privilégio (Segurança):** O Dockerfile foi construído criando e utilizando um usuário não-root (`fiapuser`). Se o container da API for comprometido, o invasor não terá privilégios administrativos no sistema operacional.
2. **Persistência de Dados (Resiliência):** O Oracle Database está atrelado a um `Docker Volume` dedicado. Reiniciar ou recriar o container do banco não causará perda das leituras biométricas armazenadas.
3. **Isolamento de Rede (Networking):** O banco de dados e a API comunicam-se de forma segura através da rede bridge isolada `stellargear-network`.
4. **Otimização de Imagem (Multi-stage Build):** O Dockerfile separa as dependências de compilação (SDK) do ambiente de execução (Runtime), gerando uma imagem de produção extremamente leve e rápida.
