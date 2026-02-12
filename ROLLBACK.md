# 🔄 Estratégia de Rollback - Lacrei Saúde

Este documento descreve as estratégias implementadas para realizar rollback em caso de deploy problemático ou falhas em produção.

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Opção 1: Rollback Automático via GitHub Actions](#opção-1-rollback-automático-via-github-actions)
3. [Opção 2: Rollback Manual via Git](#opção-2-rollback-manual-via-git)
4. [Opção 3: Rollback Docker (Manual)](#opção-3-rollback-docker-manual)
5. [Opção 4: Emergency Rollback (Rápido)](#opção-4-emergency-rollback-rápido)
6. [Fluxograma de Decisão](#fluxograma-de-decisão)
7. [Cenários e Procedimentos](#cenários-e-procedimentos)

---

## Visão Geral

O projeto implementa **4 estratégias de rollback** com diferentes níveis de risco e velocidade:

| Estratégia | Velocidade | Risco | Uso Recomendado |
|-----------|-----------|-------|-----------------|
| **Automática (GitHub)** | Média | Baixo | Deploy com bug confirmado |
| **Git Manual** | Média | Baixo | Quando automática falha |
| **Docker Manual** | Rápido | Médio | Container com problema |
| **Emergency** | Muito Rápido | Alto | Situação crítica |

---

## Opção 1: Rollback Automático via GitHub Actions ✅ Recomendado

**Quando usar:** Deploy com bug confirmado, downtime planejado

**Vantagens:**
- Rastreabilidade completa via Git
- Testes automáticos
- Health checks
- Reversível facilmente
- Auditable

**Procedimento:**

### Step 1: Acesse GitHub Actions

1. Vá para seu repositório no GitHub
2. Clique em **Actions** → **Rollback Deployment**

### Step 2: Dispare o Workflow

1. Clique em **Run workflow**
2. Selecione o ambiente:
   - `staging` - Para ambiente de testes
   - `production` - Para ambiente de produção
3. Clique em **Run workflow**

### Step 3: Monitore o Rollback

```bash
# GitHub Actions executará automaticamente:
1. ✓ Checkout do código
2. ✓ Git revert do último commit
3. ✓ Push da revert (trigger deploy)
4. ✓ Health checks automáticos
5. ✓ Notificação de sucesso/falha
```

### Step 4: Validar Rollback

```bash
# Verificar status do endpoint
curl -s https://54.226.194.208/status | jq .

# Esperado:
{
  "status": "ok",
  "message": "Lacrei Saúde rodando com sucesso!",
  "environment": "staging"
}
```

---

## Opção 2: Rollback Manual via Git 

**Quando usar:** Automático falhou, ou controle total sobre reverter

**Procedimento:**

### Step 1: Identifique o commit problemático

```bash
# Ver histórico de commits
git log --oneline -n 10

# Exemplo de output:
# a1b2c3d (HEAD -> main) Fix: issue with API response
# 4e5f6g7 Feat: new feature
# 8h9i0j1 Hotfix: database connection
```

### Step 2: Reverta o commit

```bash
# Opção A: Revert (RECOMENDADO - cria novo commit)
git revert a1b2c3d
git push origin main

# Opção B: Reset (USE COM CUIDADO - altera histórico)
git reset --hard HEAD~1
git push origin main --force
```

### Step 3: GitHub Actions deployará automaticamente

O push trigger o workflow de deploy:
```bash
1. Build da imagem Docker
2. Testes
3. Deploy automático
4. Health checks
```

### Step 4: Validar

```bash
# Aguarde ~2 minutos e verifique
curl -s https://54.159.81.199/status | jq .
```

---

## Opção 3: Rollback Docker (Manual)

**Quando usar:** Problema detectado imediatamente pós-deploy, sem esperar automation

**Procedimento:**

### Step 1: Conecte ao servidor

```bash
# Staging
ssh -i lacrei-devops-key.pem ubuntu@54.226.194.208

# Production  
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
```

### Step 2: Execute o script de rollback

```bash
# Rollback interativo (com confirmação)
cd /home/ubuntu
chmod +x rollback.sh
./rollback.sh staging

# Ou production
./rollback.sh production
```

### Step 3: O script executará:

```bash
1. Mostrar status atual
2. Listar imagens disponíveis
3. Procurar backup automático
4. Pedir confirmação
5. Parar container atual
6. Iniciar container com backup
7. Validar com health checks
8. Limpar imagens antigas
```

---

## Opção 4: Emergency Rollback (Rápido)

**Quando usar:** CRÍTICO - Sistema indisponível

**⚠️ APENAS EM EMERGÊNCIAS - Sem confirmações, rollback imediato**

**Procedimento:**

### Step 1: Conecte ao servidor

```bash
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
```

### Step 2: Execute emergency rollback

```bash
chmod +x emergency-rollback.sh
./emergency-rollback.sh production

# Você será solicitado a confirmar digitando: ROLLBACK
```

### Step 3: Resultado imediato

- ⏱️ Rollback em < 30 segundos
- ✓ Container restaurado ao backup automático
- ✓ Health check validado
- 🔔 Você deve documentar o incidente depois

---

## Fluxograma de Decisão

```
┌─────────────────────────────┐
│  Problema detectado         │
└──────────────┬──────────────┘
               │
         Qual é a gravidade?
               │
      ┌────────┼────────┐
      │        │        │
   CRÍTICO  ALTO    NORMAL
      │        │        │
      ▼        ▼        ▼
 EMERGENCY  DOCKER   GIT
 ROLLBACK   MANUAL   REVERT
      │        │        │
      └────────┼────────┘
               │
        ✅ Sistema restaurado
```

## Cenários e Procedimentos

### Cenário 1: Deploy quebrou a API

**Sintomas:** `/status` retorna 500 error

**Ação:** Git Revert (Opção 2)

```bash
# 1. Identificar commit problemático
git log --oneline -n 5

# 2. Revert
git revert a1b2c3d
git push origin main

# 3. Esperar ~2 minutos pelo deploy automático
```

---

### Cenário 2: Imagem Docker corrompida ou lenta

**Sintomas:** Container inicia mas responde lento ou não responde

**Ação:** Docker Manual (Opção 3)

```bash
# 1. SSH para o servidor
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199

# 2. Executar script
./rollback.sh production

# 3. Confirmar com 'yes'
```

---

### Cenário 3: Site completamente DOWN - Emergência

**Sintomas:** Nenhuma resposta HTTP, nginx down, container crash

**Ação:** Emergency Rollback (Opção 4)

```bash
# 1. SSH imediato
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199

# 2. Emergency rollback
./emergency-rollback.sh production

# 3. Confirmar com 'ROLLBACK' (em CAPS)

# 4. Levantar logs de incidente
docker logs lacrei-app-production > /tmp/incident-$(date +%s).log

# 5. Documentar o ocorrido
```

---

### Cenário 4: Rollback falhou, container não sobe

**Ação:** Investigação manual

```bash
# 1. Verificar logs
docker logs lacrei-app-production

# 2. Verificar imagens disponíveis
docker images | grep lacrei-app

# 3. Verificar saúde do servidor
df -h          # Disco
free -h        # Memória
ps aux         # Processos

# 4. Se nenhuma imagem está saudável:
# - Fazer deploy manual de uma versão conhecida
# - Ou entrar em contato com DevOps
```

---

## Histórico de Rollback

Mantenha um registro de todos os rollbacks para auditoria:

```bash
# Log de rollbacks (criar arquivo)
cat > /home/ubuntu/rollback-history.log << 'EOF'
[2025-02-10 10:30] Staging - Git Revert - Bug em /status - Sucesso
[2025-02-09 15:45] Production - Docker Manual - Imagem corrompida - Sucesso
EOF

# Adicionar novo rollback ao histórico
echo "[$(date)] $ENVIRONMENT - $METHOD - $REASON - $STATUS" >> /home/ubuntu/rollback-history.log
```

---

## Checkpoints para Sucesso

Antes de fazer rollback, verifique:

- [ ] Backup de imagem existe: `docker images | grep backup`
- [ ] Branch está limpa: `git status`
- [ ] Conectividade SSH é estável
- [ ] Você tem as chaves SSH corretas

Depois de rollback:

- [ ] Endpoint `/status` retorna 200
- [ ] `curl -s http://localhost:3000/status | jq .`
- [ ] Logs não mostram erros: `docker logs lacrei-app-*`
- [ ] Health check passou

---

## Fallback (Se nada funcionar)

Se todos os rollbacks falharem:

1. **Document the incident** - Crie um arquivo com logs e timestamps
2. **Contact DevOps team** - Escalate para análise profunda
3. **Manual infrastructure rebuild** - Último recurso

```bash
# Coletar informações para debugging
docker ps -a > /tmp/debug-containers.txt
docker images > /tmp/debug-images.txt
docker logs lacrei-app-production > /tmp/debug-logs.txt
systemctl status docker > /tmp/debug-docker-service.txt
```