# Configura o AWS como provedor
provider "aws" {
  region = "us-east-1"
}

# Variável para definir o nome do projeto
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

# Variável para o nome do candidato
variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}

# Criação da variável IP, para permitir acesso ao SSH apenas ao IP informado, aumentando a segurança
variable "ip" {
  description = "IP para acesso ao SSH"
  type        = string
}

# Criação de uma chave privada RSA
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Criação de um par de chaves AWS usando a chave pública gerada
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Criação de uma VPC (Virtual Private Cloud)
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

# Criação de uma subnet pública dentro da VPC
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

# Criação de um Internet Gateway para permitir acesso à internet
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}

# Criação de uma tabela de roteamento para a VPC
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}

# Associação da subnet com a tabela de roteamento
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}

# Criação de um grupo de segurança para controlar o tráfego de rede
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH do IP informado, HTTP e HTTPS"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada para permitir SSH do IP informado.
  ingress {
    description      = "Allow SSH from variable IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["${var.ip}/32"]
  }

  #Criado regra para permitir o tráfego HTTP
  ingress {
    description      = "Allow HTTP traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  
  }
  
  #Criado regra para permitir trafego HTTPS
  ingress {
    description      = "Allow HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  # Permitir de qualquer IP
  }

  # Regra de saída para permitir o tráfego para qualquer destino
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}

# Busca da AMI mais recente do Debian 12
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}

# Adição de um bucket S3 para o armazenamento de logs
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "${var.projeto}-${var.candidato}-logs"

  tags = {
    Name = "${var.projeto}-${var.candidato}-logs"
  }
}

# Configuração da criptografia para os logs
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Criação de uma instância EC2
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  # Configuração do volume raiz
  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  # Inseri os comandos para instalar, ativar e iniciar o nginx
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install nginx
              systemctl enable nginx
              systemctl start nginx
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

# Output para a chave privada
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

# Output para o IP público da instância EC2
output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
