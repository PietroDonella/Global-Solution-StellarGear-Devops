# Stellar Gear API - Global Solution 2026/1

### 👥 Integrantes
*  **Enzo Vaz** – RM: 561702 
*  **Lucas Ryuji Fukuda**  – RM: 562152 
*  **Pietro Donella Salomão** – RM: 561722

## 🚀 Sobre o Projeto
O **Stellar Gear** é uma solução de monitoramento biométrico voltada para o turismo espacial e ambientes extremos. O sistema coleta dados de sinais vitais (simulados via IoT ESP32) e os ingere em uma API .NET de alta performance. Esta API é conteinerizada via Docker e se comunica com um banco de dados relacional Oracle, garantindo o armazenamento persistente e seguro das informações médicas dos passageiros.

## 🏗️ Arquitetura da Solução
A infraestrutura foi construída na Microsoft Azure utilizando *Infrastructure as Code*.

![Diagrama de Arquitetura](./diagrama-arquitetura.png)

---

## 🛠️ How-To: Guia de Execução Completo

Siga o passo a passo abaixo para reproduzir o ambiente desde a criação da infraestrutura na nuvem até a realização de requisições na API. Se ficar com dúvida, o arquivo `caminho.ipynb` fornece a ordem exata em que os comandos devem ser executados com inserção de dados de exemplo.

### Passo 1: Criação da Infraestrutura (criacaoGS)
Toda a infraestrutura é criada de forma automatizada. No portal do Azure, abra o **Cloud Shell** e execute o script de provisionamento (`criacaoGS`). 
Esse script vai criar o *Resource Group*, a *Virtual Network*, configurar o Firewall (NSG liberando portas 22, 8080 e 1521) e criar a Máquina Virtual Ubuntu. Ao final, ele já instala o Docker e sobe o container do Banco de Dados Oracle.

    chmod +x criacaoGS.sh
    sed -i 's/\r$//' criacaoGS.sh
    ./criacaoGS.sh

### Passo 2: Conectando na Máquina Virtual
Com a máquina virtual de pé, você precisará acessá-la remotamente para subir a aplicação. Utilize o terminal do seu computador (ou o próprio Cloud Shell) para conectar via SSH usando o IP público gerado no Passo 1.

    ssh admin_fiap@<IP_PUBLICO_DA_VM>

### Passo 3: Criação das Tabelas no Banco (Migrations)
Já dentro da máquina virtual, clone o repositório da API e aplique as migrations. Para não poluir o sistema operacional instalando o .NET, rodamos um container temporário do SDK que lê o nosso código e executa o `dotnet ef database update`. Esse comando cria as tabelas no Oracle exatamente como mapeado no C#.

    git clone https://github.com/EnzoVazz/StellarGear.API.git
    cd StellarGear.API
    
    cat <<EOF > StellarGear.API/appsettings.json
    {"Logging": {
        "LogLevel": {
          "Default": "Information",
          "Microsoft.AspNetCore": "Warning"}},
      "AllowedHosts": "*",
      "ConnectionStrings": {"OracleConnection": "Data Source=db_RM_561722:1521/XEPDB1;User Id=system;Password=Fiap_devops_SG;"}}
    EOF
    
    docker run --rm -it \
      -v $(pwd):/src \
      --network stellargear-network \
      -w /src \
      mcr.microsoft.com/dotnet/sdk:10.0 \
      bash -c "dotnet restore && dotnet tool install --global dotnet-ef && export PATH=\"\$PATH:/root/.dotnet/tools\" && dotnet ef database update --project StellarGear.Infrastructure --startup-project StellarGear.API"

### Passo 4: Inserção dos Dados
Com as tabelas criadas, precisamos popular o banco com os dados iniciais e as leituras biométricas. Conecte-se ao container do Oracle e execute o bloco PL/SQL.

    docker exec -it db_RM_561722 sqlplus system/"Fiap_devops_SG"@//localhost:1521/XEPDB1

    # Dentro do SQLPlus, cole o seu script DML (PL/SQL) que possui o laço FOR
    # para gerar os mais de 80 registros exigidos, e digite EXIT para sair.

### Passo 5: Criação do Dockerfile, Build e Subida da API
Agora vamos criar a imagem da nossa API. Criamos um arquivo chamado `Dockerfile` na raiz do projeto configurando um *Multi-stage build* (que deixa a imagem leve) e definindo um usuário não-root (`fiapuser`) por questões de segurança.

    cat <<EOF > Dockerfile
    FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
    WORKDIR /src
    COPY . .
    WORKDIR "/src/StellarGear.API"
    RUN dotnet restore "StellarGear.API.csproj"
    RUN dotnet build "StellarGear.API.csproj" -c Release -o /app/build
    RUN dotnet publish "StellarGear.API.csproj" -c Release -o /app/publish
    FROM mcr.microsoft.com/dotnet/aspnet:10.0
    WORKDIR /app
    RUN useradd -m fiapuser
    USER fiapuser
    COPY --from=build /app/publish .
    EXPOSE 8080
    ENV ASPNETCORE_URLS=http://+:8080
    ENV ASPNETCORE_ENVIRONMENT=Production
    ENTRYPOINT ["dotnet", "StellarGear.API.dll"]
    EOF

Com o Dockerfile criado, fazemos o build da imagem e subimos o container da API, conectando-o na mesma rede do banco de dados:

    docker build -t stellargear-api-image .
    docker run -d --name api_RM_561722 -p 8080:8080 --network stellargear-network stellargear-api-image

### Passo 6: Conectando e Testando via Postman
A API agora está rodando na nuvem! Abra o **Postman** na sua máquina local para interagir com o sistema.

**Exemplo de Requisição POST (Cadastrar Passageiro):**
* **Método:** POST
* **URL:** `http://<IP_PUBLICO_DA_VM>:8080/api/Passageiro`
* **Headers:** `Content-Type: application/json`
* **Body (raw):**

    {
      "nome": "Beatriz Viajante",
      "cpf": "222.222.222-22",
      "idade": 28,
      "statusMedico": "EM AVALIACAO"
    }

Após enviar, você receberá o status `201 Created`. Você também pode fazer um `GET` nessa mesma URL para listar todos os passageiros ou um `PUT` apontando para o ID gerado para atualizar o status médico.
