# 🆘 Guia de Troubleshooting & Matriz de Decisão Rápida

Use este guia para tomar decisões de rollback rapidamente.

---

## ⚡ Matriz de Decisão Rápida

```
┌─────────────────────────────────────────────────────────────────┐
│                   MATRIZ DE DETECÇÃO DE SINTOMAS                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SITE_DOWN (503/504)                                             │
│  └─ Tempo < 5 min? ──→ ROLLBACK-EMERGÊNCIA       (~30 seg)      │
│  └─ Tempo > 5 min? ──→ ROLLBACK-DOCKER          (~1-2 min)      │
│                                                                 │
│  RESPOSTA_LENTA (>2 seg)                                         │
│  └─────────────→ ROLLBACK-DOCKER ou GIT-REVERT (~1-3 min)       │
│                                                                 │
│  ERROS_NOS_LOGS (/status retorna 5XX)                            │
│  └─────────────→ GIT-REVERT                    (~2-3 min)      │
│                                                                 │
│  CONTAINER_RESTARTANDO_CONTINUAMENTE                             │
│  └─────────────→ GIT-REVERT                    (~2-3 min)      │
│                                                                 │
│  PERDA_DE_DADOS / CORRUPÇÃO                                      │
│  └─────────────→ ESCALAR IMEDIATAMENTE PARA CTO                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## EMERGÊNCIA (< 30 segundos)

**Quando:** Site completamente fora do ar, sem tempo de pensar

```bash
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
./emergency-rollback.sh production
# Digite: ROLLBACK (em MAIÚSCULAS)
```

**Resultado:** Volta em ~30 segundos ou FALHA  
**Risco:** Alto  
**Requisitos:**
- Acesso SSH funcionando
- Network estável
- Imagem de backup existe

---

## CRÍTICO (5-10 minutos)

**Quando:** Sistema não responde, mas temos alguns minutos

```bash
# Opção 1: Manual via Docker
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
./rollback.sh production

# Opção 2: GitHub Actions
1. Vá para: https://github.com/repo/actions
2. Clique em: "Rollback Deployment"
3. Selecione: production
4. Execute workflow
```

**Resultado:** Volta em ~1-2 minutos  
**Risco:** Médio  
**Requisitos:** Acesso SSH ou GitHub

---

## ALTO (30+ minutos para lidar)

**Quando:** Funcionalidade quebrada, mas não completamente fora do ar

```bash
# GitHub Actions (RECOMENDADO)
# ou Git Revert se quiser controle total

git log --oneline -n 5
git revert <commit-id>
git push origin main
# Aguarde deployment automático (~2-3 min)
```

**Resultado:** Volta em ~2-3 minutos  
**Risco:** Baixo  
**Requisitos:** Acesso Git, branch limpa

---

## Validação Após Qualquer Rollback

```bash
# 1. Health check básico
curl -s https://54.159.81.199/status | jq .

# 2. Validação completa
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
./post-rollback-check.sh production

# 3. Procure por: All health checks passed!
```

---

## 📋 Problemas Comuns & Soluções

| Problema | Sintoma | Solução |
|----------|---------|---------|
| **Backup faltando** | `Error: No backup found` | `git revert` + push |
| **Erro de certificado SSL** | `curl: SSL error` | Use flag `-k` ou tente novamente |
| **Conflito de porta** | `Port 3000 already in use` | Verifique `docker ps`, pare conflitante |
| **Disco cheio** | `No space left on device` | `docker image prune -af` |
| **Problema de network** | `Cannot reach endpoint` | Verifique firewall, tente SSH novamente |
| **Resposta lenta** | Response > 5 segundos | Verifique uso de recursos, restart |

---

## 🆘 Se Tudo Falhar

1. **Coleta de evidências** (imediatamente):
   ```bash
   docker ps > incident.txt
   docker images >> incident.txt
   docker logs lacrei-app-production >> incident.txt
   df -h >> incident.txt
   ```

2. **Documente o problema:**
   - O que aconteceu?
   - Quando começou?
   - O que foi deployado?
   - Qual foi o erro?

3. **Escale para:**
   - Slack: #incident-response
   - Email: devops@lacrei.saude
   - Telefone: [Contato do Tech Lead]

4. **Evite causar mais danos:**
   - Não tente novamente se continuar falhando
   - Mantenha container rodando como está para investigação
   - Preserve os logs

---

## 📱 Referência Rápida de Comandos

```bash
# Health check (rápido)
curl -s http://localhost:3000/status | jq .status

# Verifique container  
docker ps | grep lacrei-app

# Ver logs (últimas 10 linhas)
docker logs --tail 10 lacrei-app-production

# Editar histórico git (revert)
git revert <commit-id>
git push origin main

# Executar script de rollback
./rollback.sh production

# Validação completa pós-rollback
./post-rollback-check.sh production

# Verificar se porta está livre
lsof -i :3000

# Verificar espaço em disco
df -h

# Verificar memória
free -h
```

---

## 🚨 Último Recurso - Quebra de Vidro

```bash
# SE NADA FUNCIONAR, faça isto:

# 1. Pare tudo
docker stop $(docker ps -q) || true

# 2. Remova containers atuais
docker rm $(docker ps -aq) || true

# 3. Execute imagem conhecida como boa
docker run -d \
  --name lacrei-app-production \
  --restart unless-stopped \
  -p 3000:3000 \
  -e NODE_ENV=production \
  lacrei-app:backup

# 4. Verifique se funciona
curl http://localhost:3000/status

# 5. Documente o que fez
# 6. Reporte como incidente crítico
```

---

## ✓ Critérios de Sucesso

Rollback é bem-sucedido quando:

- [ ] `curl` retorna HTTP 200
- [ ] Response contém `"status": "ok"`
- [ ] Sem erros em `docker logs`
- [ ] Tempo de resposta < 2 segundos
- [ ] Environment combina valor esperado

---

**Mantenha este guia à mão!** 📌  
Referência: [Documentação Completa](./ROLLBACK.md)
