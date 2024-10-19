## Introdução

- O arquivo `main.tf` original foi renomeado para `main.old`
- O arquivo com as melhorias adicionadas agora é o `main.tf`

# Análise Técnica do Código Terraform

1. Provedor AWS: Configura a região "us-east-1"

2. Variáveis: Define duas variáveis, "projeto" e "candidato" que serão utilizadas para nomear os recursos de forma dinâmica

3. Gera uma chave privada usando o algorítmo RSA de 2048 bits que será utilizada no proximo passo, é com ela que fazemos a autenticação no SSH

4. Cria um par de chaves AWS utilizando uma chave pública derivada da chave privada gerada anteriormente, esse par de chaves é essencial para segurança da autencicação

5. Cria uma VPC, ativando suporte a DNS, resolução dos hostnames e definindo o bloco CIDR para 10.0.0.0/16

6. Cria uma Subnet, definindo o bloco CIDR para 10.0.1.0/24, define a disponibiliadde em "us-east-1a", a mesma usada na configuração do provedor

7. Cria o Internet Gateway e o associa à VPC, permite o acesso à internet

8. Cria a Tabela de Roteamento para permitir o tráfego entre a VPC e a internet por meio do Gateway

9. Associa a Subnet à tabela de roteamento do passo anterior

10. Cria um Grupo de Segurança, que é semelhante a um firewall, onde se cria regras, no código fornecido permite entrada de qualquer ip de origem na porta 22 e saída para qualquer destino

11. Busca a imagem do Debian 12 mais recente, no filtro name está restringido a busca para arquitetura amd64, o filtro virtualization-type restringe a imagens que usam HVM como tipo de virtualização

12. Cria a instância

- Utiliza a AMI do Debian 12 que foi definida no passo anterior.
- Associada à subnet e ao grupo de segurança criados.
- Atribui um IP público.
- Configura um volume raiz de 20GB do tipo gp2.
- delete_on_termination serve para excluir o volume ao encerrar a instância.
- Executa um script de inicialização para atualizar o sistema.

13. Fornece a saída dos dados, a chave privada criada no item 3 e o endereço de IP para acesso ao SSH, a chave privada é marcada como sensivel para ocultação no terminal

<br>

# Melhorias Implementadas

### 1. Grupo de Segurança

- **Restringir o aceso ao SSH:** O acesso SSH (porta 22) foi limitado a um IP específico, para isso criei uma varíavel "ip" obrigatória. A restrição do acesso SSH a um único IP melhora a segurança pois teremos um controle de acesso restrito.

- **Liberar o acesso ao HTTP e HTTPS:** Criei 2 novas regras para permitir o tráfego **HTTP** e **HTTPS**, (portas 80 e 443) essenciais para o funcionamento do **Nginx**.

### 2. Criptografia do Disco

- Com `encrypted = true` em root_block_device, ativamos a criptografia do disco, o que aumenta ainda mais a segurança.

### 3. Instalação Automática do Nginx

- **Comandos inseridos**:
  ```
  apt-get install -y nginx
  systemctl enable nginx
  systemctl start nginx
  ```
  Modificação feita no user_data agora inclui a instalação e inicialização automática do Nginx.

## Alterações

- Retirado as tags no aws_route_table_association, pois estava gerando o erro "tags is not expected here"

- Na aws_instance modifiquei para buscar o security group pelo id, pois ao fazer um apply estava obtendo erro quando estava usando o nome.

<br>

# Instruções de Uso

- Clone este repositório com `git clone https://github.com/ataidefcjr/vexpenses-teste`
- Instale o Terraform de acordo com o link: `https://www.terraform.io`
- Instale o AWS-CLI para autenticação, ou atualize o campo providers em `main.tf` inserindo suas credenciais AWS.
- Navegue até o diretório contendo o arquivo `main.tf`
- Execute os seguintes comandos:

```
terraform init
terraform plan -out="tfplan.out" -var "ip=0.0.0.0"
terraform apply "tfplan.out"
```

- Subsitua o 0.0.0.0 pelo seu IP
- Anote o IP do EC2 e o acesse a partir de um browser para confirmar que está funcional.
- Para salvar a chave privada de acesso ao SSH: `terraform output private_key > terraform_pkey.pem && chmod 400 terraform_pkey.pem`
- Acesse o SSH com: `ssh -i terraform_pkey.pem admin@[IP FORNECIDO NO FINAL DO APPLY]`
