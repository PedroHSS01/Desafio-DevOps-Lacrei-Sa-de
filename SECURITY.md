# 🔒 Política de Segurança

Este documento descreve as práticas de segurança implementadas no projeto para proteger dados sensíveis e garantir a integridade da infraestrutura.

---

## 🔐 Gerenciamento de Secrets

### Secrets Utilizados

O projeto utiliza **GitHub Secrets** para armazenar todas as credenciais sensíveis:

| Secret | Descrição | Onde é Usado | Rotação |
|--------|-----------|--------------|---------|
| `SSH_PRIVATE_KEY` | Chave privada SSH para acesso aos servidores | Deploy staging e production | A cada 90 dias |
| `STAGING_HOST` | IP público do servidor staging | Deploy staging | Quando instância é recriada |
| `STAGING_USER` | Usuário SSH staging (ubuntu) | Deploy staging | Nunca (padrão AWS) |
| `PRODUCTION_HOST` | IP público do servidor production | Deploy production | Quando instância é recriada |
| `PRODUCTION_USER` | Usuário SSH production (ubuntu) | Deploy production | Nunca (padrão AWS) |

### Como os Secrets São Protegidos

✅ **Nunca commitados no código**
- Arquivo `.gitignore` bloqueia arquivos sensíveis (`.env`, `*.pem`)
- Chaves SSH armazenadas APENAS localmente e no GitHub Secrets

✅ **Criptografados em repouso**
- GitHub Secrets usa criptografia AES-256
- Acessíveis APENAS durante execução de workflows

✅ **Princípio do Menor Privilégio**
- Chaves SSH têm acesso APENAS ao necessário
- Permissões `chmod 400` nas chaves privadas

✅ **Separação por Ambiente**
- Staging e Production usam credenciais DIFERENTES
- Vazamento em staging NÃO compromete production

---

## 🛡️ Segurança em Trânsito

### HTTPS/TLS Obrigatório

**Implementação:**
- Nginx configurado como reverse proxy
- Certificados SSL autoassinados (válidos por 365 dias)
- Redirecionamento automático HTTP → HTTPS

**Configuração:**
```nginx
# Redirecionar HTTP para HTTPS
server {
    listen 80;
    return 301 https://$host$request_uri;
}

# HTTPS com TLS
server {
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
}
```

**Validação:**
```bash
curl -I http://54.159.81.199
# Resposta: HTTP/1.1 301 Moved Permanently
# Location: https://54.159.81.199/
```

---

## 🚪 Controle de Acesso

### Security Groups (AWS)

**Regras Implementadas:**

| Porta | Protocolo | Origem | Justificativa |
|-------|-----------|--------|---------------|
| 22 | SSH | 0.0.0.0/0 | GitHub Actions usa IPs dinâmicos |
| 80 | HTTP | 0.0.0.0/0 | Redirecionamento para HTTPS |
| 443 | HTTPS | 0.0.0.0/0 | Acesso público à aplicação |
| 3000 | TCP | 0.0.0.0/0 | Porta da aplicação (exposta para testes) |

**Justificativa SSH público:**
- GitHub Actions usa IPs dinâmicos globais
- Autenticação por chave SSH (não senha) mantém segurança
- Alternativa seria usar GitHub-hosted runners com IPs fixos (custo adicional)

### Permissões de Arquivos

**Chaves SSH:**
```bash
chmod 400 lacrei-devops-key.pem
# Permissões: -r-------- (somente leitura pelo dono)
```

**Containers Docker:**
```bash
# Containers executam com usuário não-root
# Restart policy: unless-stopped (não reinicia automaticamente se parado manualmente)
```

---

## 🔍 Monitoramento e Auditoria

### Logs de Acesso

**Nginx Access Logs:**
```bash
tail -f /var/log/nginx/access.log
# Registra: IP, timestamp, método, URL, status, user-agent
```

**Logs da Aplicação:**
```javascript
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});
```

**Logs do Docker:**
```bash
docker logs lacrei-app-production
# Acesso a todos os logs stdout/stderr do container
```

### CloudWatch (AWS)

**Métricas Coletadas:**
- CPU: user, system, idle
- Memória: used, available
- Disco: used, free
- Rede: conexões TCP ativas

**Logs Enviados:**
- `/var/log/nginx/access.log`
- `/var/log/nginx/error.log`
- `/var/log/syslog`
- Logs dos containers Docker

---

## 🚨 Plano de Resposta a Incidentes

### Cenário 1: Chave SSH Comprometida

**Resposta:**
1. Gerar novo par de chaves SSH imediatamente
2. Atualizar GitHub Secret `SSH_PRIVATE_KEY`
3. Adicionar nova chave pública aos servidores (`~/.ssh/authorized_keys`)
4. Remover chave antiga dos servidores
5. Auditar logs de acesso (`/var/log/auth.log`)

**Prevenção:**
- Rotação trimestral de chaves SSH
- Nunca compartilhar chaves privadas
- Armazenar apenas em máquinas confiáveis

### Cenário 2: IP dos Servidores Exposto

**Impacto:**
- IPs já são públicos (necessário para HTTPS)
- Security Groups limitam acesso a portas específicas
- Autenticação SSH por chave (não senha)

**Mitigação:**
- Usar Elastic IPs (IPs permanentes)
- Implementar fail2ban (bloquear IPs com tentativas falhas)

### Cenário 3: Container Comprometido

**Resposta:**
1. Parar container imediatamente: `docker stop lacrei-app-production`
2. Analisar logs: `docker logs lacrei-app-production > incident.log`
3. Fazer rollback para versão anterior (ver seção Rollback no README)
4. Investigar imagem Docker comprometida
5. Rebuildar imagem do zero

---

## ✅ Checklist de Segurança Implementado

- [x] Secrets gerenciados via GitHub Secrets
- [x] Chaves SSH com permissões 400
- [x] HTTPS obrigatório com TLS 1.2+
- [x] Redirecionamento HTTP → HTTPS
- [x] Security Groups restritivos
- [x] Logs centralizados (CloudWatch)
- [x] Containers com restart policy configurado
- [x] Separação completa staging/production
- [x] Princípio do menor privilégio aplicado
- [x] Documentação de resposta a incidentes

---

## 🔄 Rotação de Credenciais

### Calendário de Rotação

| Credencial | Frequência | Último | Próximo |
|------------|------------|--------|---------|
| Chaves SSH | 90 dias | 2025-02-10 | 2025-05-10 |
| Certificados SSL | 365 dias | 2025-02-10 | 2026-02-10 |

### Processo de Rotação de Chaves SSH
```bash
# 1. Gerar novo par de chaves
ssh-keygen -t rsa -b 4096 -C "lacrei-devops" -f lacrei-devops-key-new.pem

# 2. Adicionar nova chave nos servidores
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199 'cat >> ~/.ssh/authorized_keys' < lacrei-devops-key-new.pem.pub

# 3. Testar nova chave
ssh -i lacrei-devops-key-new.pem ubuntu@54.159.81.199 'echo "OK"'

# 4. Atualizar GitHub Secret
# Settings → Secrets → SSH_PRIVATE_KEY → Update

# 5. Remover chave antiga dos servidores
ssh -i lacrei-devops-key-new.pem ubuntu@54.159.81.199 'sed -i "/OLD_KEY_CONTENT/d" ~/.ssh/authorized_keys'
```

---