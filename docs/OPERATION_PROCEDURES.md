# 📋 Procedimentos Operacionais - Implementação de Rollback

## 🎯 Objetivo

Documentar os procedimentos operacionais para uso efetivo da estratégia de rollback do projeto Lacrei Saúde.

---

## 📁 Estrutura de Arquivos Criada

```
.
├── .github/workflows/
│   └── rollback.yml                 # GitHub Actions workflow de rollback automático
├── scripts/
│   ├── rollback.sh                  # Script manual de rollback interativo
│   ├── emergency-rollback.sh        # Script de rollback de emergência
│   ├── test-rollback.sh             # Script para testar rollback em staging
│   └── post-rollback-check.sh       # Script de validação pós-rollback
├── docs/
│   └── QUICK_ROLLBACK.md            # Quick reference de rollback
├── ROLLBACK.md                       # Documentação completa de rollback
└── README.md                         # Atualizado com seção de rollback
```

---

## 🔧 Setup Inicial

### Pré-requisitos

```bash
# 1. Clone o repositório
git clone <repo-url>
cd Desafio-DevOps-Lacrei-Sa-de

# 2. Torne os scripts executáveis
chmod +x scripts/rollback.sh
chmod +x scripts/emergency-rollback.sh
chmod +x scripts/test-rollback.sh
chmod +x scripts/post-rollback-check.sh

# 3. Verifique as permissões
ls -la scripts/
# Esperado: -rwxr-xr-x para todos os scripts
```

### Preparar Instâncias EC2

```bash
# 1. SSH para cada servidor
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199

# 2. Clone os scripts no servidor
git clone <repo-url>
cd Desafio-DevOps-Lacrei-Sa-de/scripts

# 3. Torne executáveis
chmod +x *.sh

# 4. Verifique que os backups existem
docker images | grep lacrei-app
```

---

## 📚 Guias de Procedimento

### Procedimento 1: Rollback Normal (Recomendado)

**Situação:** Deploy com bug confirmado, sistema funcionando parcialmente

**Passos:**

```bash
# Opção A: Via GitHub Actions (RECOMENDADO)
1. Acesse: https://github.com/seu-repo/actions
2. Clique: "Rollback Deployment"
3. Run workflow → Selecione environment
4. Aguarde ~2-3 minutos
5. Verifique: Health checks passaram?

# Opção B: Via Git manual (Se GitHub Actions falhar)
1. git log --oneline -n 5
2. git revert <commit-id>
3. git push origin main
4. Comece no passo 4 da Opção A
```

**Validação:**

```bash
# Local (no servidor)
curl -s http://localhost:3000/status | jq .

# Remoto (de qualquer lugar)
curl -s https://54.159.81.199/status | jq .
```

**Tempo esperado:** 3 minutos  
**Risco:** Baixo

---

### Procedimento 2: Rollback Docker (Rápido)

**Situação:** Container instável, problema detectado imediatamente

**Passos:**

```bash
# 1. SSH para o servidor
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199

# 2. Execute o script de rollback
cd /home/ubuntu/Desafio-DevOps-Lacrei-Sa-de/scripts
./rollback.sh production

# 3. O script irá:
#    - Mostrar status atual
#    - Listar imagens disponíveis
#    - Pedir confirmação
#    - Executar rollback
#    - Rodar health checks

# 4. Verifique resultado
curl -s http://localhost:3000/status | jq .
```

**Tempo esperado:** 2 minutos  
**Risco:** Médio

---

### Procedimento 3: Emergency Rollback (Crítico)

**Situação:** Site fora do ar, sem tempo para procedimentos normais

**Passos:**

```bash
# 1. SSH imediato
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199

# 2. Execute emergency rollback
cd /home/ubuntu/Desafio-DevOps-Lacrei-Sa-de/scripts
./emergency-rollback.sh production

# 3. Digite: ROLLBACK (em MAIÚSCULAS)

# 4. Aguarde ~30 segundos

# 5. Valide
curl -s http://localhost:3000/status | jq .

# 6. APÓS o rollback bem-sucedido:
#    - Documente o incidente
#    - Coletar logs
#    - Investigar causa
```

**Tempo esperado:** 30 segundos  
**Risco:** Alto (Use apenas em emergências!)

---

## ✅ Checklists

### Checklist Pré-Rollback

- [ ] Identifiquei o problema (bug confirmado, não é network)
- [ ] Tentei debug simples (ver logs, restart)
- [ ] Tenho acesso SSH ou GitHub
- [ ] Chaves SSH funcionam
- [ ] Backup de imagem existe: `docker images | grep backup`
- [ ] Git branch está clean: `git status`
- [ ] Tenho conexão estável com internet

### Checklist Pós-Rollback

- [ ] Endpoint `/status` retorna 200 OK
- [ ] Response JSON válido com `"status": "ok"`
- [ ] Environment correto no response
- [ ] Sem erros críticos nos logs: `docker logs lacrei-app-*`
- [ ] Health check passou
- [ ] Response time aceitável (< 2 segundos)
- [ ] Documentei o rollback realizado

---

## 🧪 Testando Rollback (Staging)

**IMPORTANTE:** Sempre teste procedimentos em **STAGING** antes de usar em PRODUCTION

```bash
# 1. Validar readiness em staging
ssh -i lacrei-devops-key.pem ubuntu@54.226.194.208
cd /home/ubuntu/Desafio-DevOps-Lacrei-Sa-de/scripts
./test-rollback.sh staging

# 2. Executar rollback de teste
./rollback.sh staging
# Confirme com 'yes'

# 3. Validar pós-rollback
./post-rollback-check.sh staging

# 4. Se tudo passou em staging, você está pronto para production!
```

---

## 📈 Monitoramento Pós-Rollback

```bash
# Ao realizar qualquer rollback, execute:

# 1. Health check básico
curl -s https://54.159.81.199/status | jq .

# 2. Full health check (com validações)
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
./post-rollback-check.sh production

# 3. Se post-rollback-check.sh falhar:
#    - Coletar logs: docker logs lacrei-app-production > incident.log
#    - Investigar: docker logs lacrei-app-production
#    - Tentar próxima estratégia
```

---

## 🔍 Troubleshooting

### Problema: "Backup image not found"

```bash
# Solução 1: Usar latest image
docker images | grep lacrei-app
# Pegar a imagem mais recente manualmente

# Solução 2: Fazer deploy forçado
git log --oneline -n 10
git revert <commit-id>
git push origin main --force
```

### Problema: "Container não sobe após rollback"

```bash
# 1. Verificar logs
docker logs lacrei-app-production

# 2. Checar se é problema de porta
lsof -i :3000

# 3. Checar recursos
free -h
df -h

# 4. Tentar outra imagem
docker images | grep lacrei-app
# Escolher imagem diferente e executar manualmente
```

### Problema: "Health check falha"

```bash
# 1. Verificar se container está rodando
docker ps | grep lacrei-app

# 2. Verificar se porta está acessível
curl http://localhost:3000/

# 3. Verificar logs da aplicação
docker logs lacrei-app-production --tail 50

# 4. Se nada funcionar, fazer rollback manual
# Escolher versão mais antiga conhecida como boa
```


## 📝 Documentação de Referência

- [ROLLBACK.md](./ROLLBACK.md) - Documentação completa
- [docs/QUICK_ROLLBACK.md](./docs/QUICK_ROLLBACK.md) - Quick reference
- [README.md](./README.md) - Visão geral do projeto

---
