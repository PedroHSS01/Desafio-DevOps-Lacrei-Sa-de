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

---

## 🛡️ Segurança e Gestão de Secrets

Este projeto implementa múltiplas camadas de segurança:

- **Gerenciamento de Credenciais:** GitHub Secrets com criptografia AES-256
- **Acesso aos Servidores:** Autenticação SSH por chave privada (rotação trimestral)
- **Proteção em Trânsito:** HTTPS obrigatório
- **Monitoramento:** CloudWatch com logs centralizados
- **Resposta a Incidentes:** Plano documentado para cenários críticos

📄 **Documentação completa:** [SECURITY.md](./SECURITY.md)

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

## ↩️ Estratégia de Rollback

Este projeto implementa **4 estratégias de rollback** com diferentes velocidades e níveis de segurança:

### 📊 Comparação de Estratégias

| Estratégia | Velocidade | Risco | Aplicabilidade |
|-----------|-----------|-------|-----------------|
| **GitHub Actions (Automático)** | 3 min | Baixo | Deploy com bug confirmado |
| **Git Revert (Manual)** | 3 min | Baixo | Quando automático falha |
| **Docker Manual** | 1 min | Médio | Problema no container |
| **Emergency Rollback** | 30 seg | Alto | Site fora do ar |

---

### ✅ Opção 1: Rollback Automático via GitHub Actions (RECOMENDADO)

**Melhor para:** Deploy com bug confirmado  
**Tempo:** ~2-3 minutos  
**Risco:** Baixo - Testes automáticos inclusos

**Procedimento:**

1. Vá para seu repositório → **Actions** → **Rollback Deployment**
2. Clique em **Run workflow**
3. Selecione o ambiente: `staging` ou `production`
4. Aguarde os health checks automáticos

```bash
# O workflow executará:
✓ Git revert do último commit
✓ Build e testes da imagem Docker
✓ Deploy automático
✓ Health checks
✓ Notificação de sucesso/falha
```

**Vantagens:**
- Rastreabilidade completa via Git
- Testes automáticos
- Health checks integrados
- Auditável

---

### 📝 Opção 2: Rollback Manual via Git

**Melhor para:** Controle total, quando automático falha  
**Tempo:** ~2-3 minutos  
**Risco:** Baixo

**Procedimento:**

```bash
# 1. Identifique o commit problemático
git log --oneline -n 10

# 2. Reverta via Git (RECOMENDADO)
git revert <commit-id>
git push origin main

# Ou faça reset (USE COM CUIDADO - altera histórico)
# git reset --hard HEAD~1
# git push origin main --force

# 3. GitHub Actions realizará deploy automaticamente
# Aguarde ~2 minutos
```

**Validar:**
```bash
curl -s https://54.159.81.199/status | jq .
```

---

### 🐳 Opção 3: Rollback Docker (Manual)

**Melhor para:** Problema no container detectado imediatamente  
**Tempo:** ~1 minuto  
**Risco:** Médio

**Procedimento:**

```bash
# 1. Conecte ao servidor
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199

# 2. Execute o script de rollback
chmod +x rollback.sh
./rollback.sh production

# 3. Confirme quando solicitado (digite 'yes')

# O script irá:
# - Mostrar status atual
# - Listar imagens disponíveis
# - Procurar backup automático
# - Parar container e iniciar backup
# - Executar health checks
# - Mostrar resultado final
```

**Vantagens:**
- Rápido
- Usa backup automático do Docker
- Health checks integrados
- Interativo com confirmação

---

### 🚨 Opção 4: Emergency Rollback (CRÍTICO APENAS)

**Melhor para:** EMERGÊNCIA - Site inativo  
**Tempo:** ~30 segundos  
**Risco:** Alto - Sem confirmações, apenas rollback imediato

**Procedimento:**

```bash
# 1. Conecte ao servidor
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199

# 2. Execute emergency rollback
chmod +x emergency-rollback.sh
./emergency-rollback.sh production

# 3. Confirme digitando: ROLLBACK (em maiúsculas)

# Rollback acontece em ~30 segundos
# ✓ Container é restaurado ao último backup
# ✓ Health check validado
```

---

### 📚 Documentação Completa

Para mais detalhes sobre rollback e cenários consulte: [**ROLLBACK.md**](./ROLLBACK.md)

Neste documento você encontrará:
- ✅ Procedimentos passo a passo
- 📋 Checklist de sucesso
- 🔍 Cenários específicos
- 🛠️ Fallback procedures
- ❓ FAQ

---

### 🔧 Verificação Pós-Rollback

Depois de realizar qualquer rollback, valide:

```bash
# 1. Endpoint /status retorna 200 OK
curl -i http://localhost:3000/status

# 2. Verifique o response JSON
curl -s http://localhost:3000/status | jq .

# Esperado:
{
  "status": "ok",
  "message": "Lacrei Saúde rodando com sucesso!",
  "environment": "production"
}

# 3. Verifique logs do container
docker logs lacrei-app-production --tail 20

# 4. Não há erros críticos nos logs
docker logs lacrei-app-production | grep ERROR

# Se tudo OK, rollback foi sucesso!
```
