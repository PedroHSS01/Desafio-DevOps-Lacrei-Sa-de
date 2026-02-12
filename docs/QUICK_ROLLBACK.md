# 🚀 Quick Reference - Rollback

Guia rápido para operações comum de rollback.

## Emergência (Site fora do ar)

```bash
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
./emergency-rollback.sh production
# Responda: ROLLBACK
```

**Tempo:** 30 segundos  
**Risco:** Alto (Use apenas em emergências)

---

## Rollback Normal (GitHub)

1. GitHub → Actions → **Rollback Deployment**
2. Run workflow → `production`
3. Aguarde status verde ✓

**Tempo:** ~2-3 minutos  
**Risco:** Baixo (Recomendado)

---

## Rollback Manual (Git)

```bash
git log --oneline -n 3
git revert <commit-id>
git push origin main
```

**Tempo:** ~2-3 minutos  
**Risco:** Baixo (Com auditoria Git)

---

## Rollback via Docker

```bash
ssh -i lacrei-devops-key.pem ubuntu@54.159.81.199
./rollback.sh production
# Responda: yes
```

**Tempo:** ~1-2 minutos  
**Risco:** Médio (Sem auditoria Git)

---

## Validação Pós-Rollback

```bash
curl -s https://54.159.81.199/status | jq .
```

Esperado: `"status": "ok"` ✓

---

## Para Mais Informações

Veja: [ROLLBACK.md](../ROLLBACK.md)
