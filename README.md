# Stellar Gear API - Global Solution 2026/1

### 👥 Integrantes
*  **Enzo Vaz** – RM: 561702 
*  **Lucas Ryuji Fukuda**  – RM: 562152 
*  **Pietro Donella Salomão** – RM: 561722

## 🚀 Sobre o Projeto
O **Stellar Gear** é uma solução de monitoramento biométrico voltada para ambientes extremos e turismo espacial. O sistema processa dados de sinais vitais coletados via IoT (simulados por ESP32), ingerindo-os em uma API .NET de alta performance, integrada a um banco de dados relacional robusto (Oracle XE) e conteinerizada para garantir portabilidade e segurança.

## 🏗️ Arquitetura da Solução
A arquitetura foi desenhada seguindo boas práticas de *Cloud Computing* e *DevOps*, utilizando isolamento de rede, containers Docker e persistência de dados.

![Diagrama de Arquitetura](./diagrama-arquitetura.png)

### Componentes de Infraestrutura:
* **Cloud Provider:** Microsoft Azure (Brazil South).
* **Compute:** Virtual Machine (Ubuntu 22.04 LTS).
* **Orquestração:** Docker Engine com redes isoladas (`stellargear-network`).
* **Backend:** .NET 10.0 (Segurança focada em Non-Root User).
* **Banco de Dados:** Oracle XE 21c (Volume Docker persistente).

---

## 🛠️ Guia de Implementação (Passo a Passo)

Este guia descreve como provisionar e executar o ambiente completo na nuvem.

### 1. Provisionamento de Infraestrutura
No Azure Cloud Shell, utilize o script `criacaoGS.sh` para provisionar os recursos:
1. Criar o Resource Group e VNet.
2. Definir regras de NSG (Portas: 22, 8080, 1521).
3. Subir a VM e inicializar o container do Oracle:
   ```
   docker run -d --name db_RM_561722 -p 1521:1521 \
     -v oracle-stellargear-data:/opt/oracle/oradata \
     --network stellargear-network \
     -e ORACLE_PASSWORD=Fiap_devops_SG gvenzl/oracle-xe
   ```
### 2. Configuração e Migrations

1. Dentro da Máquina Virtual (acesso via SSH): `Clone este repositório: git clone https://github.com/EnzoVazz/StellarGear.API.git`.
2. Ajuste o `appsettings.json` para conectar no container interno (db_RM_561722).
3. Execute a aplicação das migrations através de um container SDK .NET para garantir consistência:
  ```
      docker run --rm -it -v $(pwd):/src --network stellargear-network -w /src \
      [mcr.microsoft.com/dotnet/sdk:10.0](https://mcr.microsoft.com/dotnet/sdk:10.0) \
      bash -c "dotnet restore && dotnet tool install --global dotnet-ef && export PATH=\"\$PATH:/root/.dotnet/tools\" && dotnet ef database update --project StellarGear.Infrastructure --startup-project StellarGear.API"
  ```
### 3. Carga de Dados e Deploy da API
1. Execute o script DML.sql no banco para popular a massa de dados (80+ registros).
2. Construa a imagem e suba a API com segurança (usuário `fiapuser`):
  ```
    docker build -t stellargear-api-image .
    docker run -d --name api_RM_561722 -p 8080:8080 --network stellargear-network stellargear-api-image
  ```

---

### 🔗 Documentação da API (CRUD)
A API expõe os seguintes endpoints:
*  `GET /api/Passageiro`: Lista todos os passageiros.
*  `POST /api/Passageiro`: Cadastra um novo passageiro.
*  `PUT /api/Passageiro/{id}`: Atualiza dados de um passageiro.
*  `DELETE /api/Passageiro/{id}`: Remove um passageiro.
Exemplo de Payload (POST):
```
{
  "nome": "Beatriz Viajante",
  "cpf": "222.222.222-22",
  "idade": 28,
  "statusMedico": "EM AVALIACAO"
}
```

---

###🛡️ DevOps & Security Highlights
Para atender aos critérios rigorosos da Global Solution:
*  **Princípio do Menor Privilégio**: A API roda sob o usuário `fiapuser` (não-root), mitigando riscos de escalação de privilégios.
*  **Persistência de Dados**: Oracle Database configurado com Docker Volume, garantindo que os dados não sejam perdidos.
*  **Infraestrutura como Código**: Automação total via scripts Bash.
*  **Dockerfile Multi-stage**: Imagem otimizada para segurança e performance.
