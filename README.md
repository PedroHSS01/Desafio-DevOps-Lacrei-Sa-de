# Desafio DevOps - Lacrei Saúde 💚

Este repositório contém a solução para o Desafio DevOps da Lacrei Saúde, apresentando um pipeline CI/CD completo para deploy automatizado de aplicações Node.js na AWS.

## 🌟 Visão Geral

Implementação de uma infraestrutura escalável e segura utilizando **Docker**, **Nginx** e **GitHub Actions** para gerenciar ambientes de staging e produção com foco em observabilidade e automação.

---

## 📡 Ambientes Deployados

| Branch | Ambiente | URL | Status | Nota | 
| :--- | :--- | :--- | :--- | :--- |
| `staging` | 🧪 **Staging** | [https://54.226.194.208/status](https://54.226.194.208/status) | ✅ Ativo | SSL Autoassinado |
| `main` | 🚀 **Produção** | [https://54.159.81.199/status](https://54.159.81.199/status) | ✅ Ativo | SSL Autoassinado |

> **Nota:** Ambos os ambientes redirecionam automaticamente tráfego HTTP para HTTPS (Porta 80 → 443).

---

## 🌍 Separação de Ambientes

A infraestrutura foi projetada com **isolamento completo** entre staging e produção:

| Aspecto | Staging | Production |
|---------|---------|------------|
| **Branch Git** | `staging` | `main` |
| **Instância EC2** | `lacrei-staging` (54.226.194.208) | `lacrei-production` (54.159.81.199) |
| **Security Group** | `lacrei-app-sg` (isolado) | `lacrei-app-sg` (isolado) |
| **Container Docker** | `lacrei-app-staging` | `lacrei-app-production` |
| **NODE_ENV** | `staging` | `production` |
| **Deploy Trigger** | Push em `staging` | Push em `main` |
| **Propósito** | Validação e testes | Usuários reais |
| **Impacto de falhas** | Zero impacto em produção | Crítico |

### Processo para staging

1. **Desenvolvimento**: Commit e push na branch `staging`
```bash
   git checkout staging
   git add .
   git commit -m "feat: nova funcionalidade"
   git push origin staging
```

2. **Validação Automática**: GitHub Actions executa:
   - Build da imagem Docker
   - Testes de integridade
   - Deploy em staging (54.226.194.208)

3. **Testes Manuais**: Validar endpoint `/status` em staging

4. **Processo para Produção**:
```bash
   git checkout main
   git merge staging
   git push origin main
```

5. **Deploy em Produção**: GitHub Actions replica o processo para production

### Benefícios do Isolamento

✅ **Nenhuma mudança afeta produção sem passar por staging**  
✅ **Rollback em staging não impacta usuários**  
✅ **Testes de carga podem ser feitos em staging**  
✅ **Credenciais separadas (GitHub Secrets diferentes)**
---

## 🏗️ Arquitetura da Solução
<img src="https://github.com/PedroHSS01/Desafio-DevOps-Lacrei-Sa-de/blob/main/img/download.png">

### 🚀 Tecnologias Utilizadas

**Infraestrutura:**
* **AWS EC2 (t3.micro):** Instâncias isoladas para Staging e Produção.
* **Docker:** Containerização para consistência entre ambientes.
* **Nginx:** Atuando como Reverse Proxy e terminação SSL/TLS.
* **GitHub Actions:** Orquestração de CI/CD.

**Segurança & Monitoramento:**
* **AWS CloudWatch:** Centralização de logs e métricas.
* **GitHub Secrets:** Gerenciamento seguro de variáveis e chaves SSH.
* **Security Groups:** Regras de firewall restritivas (Least Privilege).

---

## 🔄 Pipeline CI/CD

O fluxo de automação é acionado a cada `push` nas branches principais.

### Fluxo Automatizado:
1.  **Trigger:** Push para `main` ou `staging`.
2.  **Build:** Criação da imagem Docker utilizando o commit SHA como tag.
3.  **Testes:** Validação da integridade do container e Health Checks.
4.  **Deploy:** Atualização automática do ambiente correspondente via SSH.
5.  **Validação:** Verificação pós-deploy da disponibilidade da URL.

### Estrutura do Workflow:
* `build-and-test`: Job universal de integração.
* `deploy-staging`: Executado exclusivamente na branch `staging`.
* `deploy-production`: Executado exclusivamente na branch `main`.

---

## 🔒 Checklist de Segurança Implementado

* [x] **Gerenciamento de Credenciais:** Uso estrito de GitHub Secrets; chaves SSH não expostas.
* [x] **Proteção de Infraestrutura:** Security Groups limitados às portas 80, 443 e 22 (IP restrito).
* [x] **Segurança em Trânsito:** HTTPS obrigatório com HSTS.
* [x] **Observabilidade:** Coleta ativa de métricas de sistema e logs de aplicação.

---

## 📊 Monitoramento com CloudWatch

Configurado para coletar dados críticos através do CloudWatch Agent:

* **Métricas de Performance:** CPU (User/System), Memória (Utilizada/Disponível), Disco e conexões TCP.
* **Logs Centralizados:**
    * `nginx/access.log` & `nginx/error.log`
    * Logs dos containers Docker.
    * Logs da API Node.js e `syslog` do Ubuntu.

---
## Melhorias posteriores

* **Alocar Elastic IPs na AWS:** Associar cada Elastic IP a uma instância. Os IPs serão permanentes mesmo após parar/iniciar.

## ↩️ Processo de Rollback

### Opção 1: Rollback via Git (Recomendado)
Para garantir a rastreabilidade, reverta o commit problemático na branch:
```bash
git revert <commit-id>
git push origin main
