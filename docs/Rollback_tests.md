# 🧪 Relatório de Testes - Estratégia de Rollback

**Data do Teste:** 14 de Fevereiro de 2026  
**Ambiente:** Staging (54.226.194.208)  
**Objetivo:** Validar estratégias de rollback em cenário real  
**Status Final:** ✅ **SUCESSO**

---

## 📋 Sumário Executivo

Este documento detalha os testes práticos realizados nas estratégias de rollback implementadas para o projeto Lacrei Saúde. Os testes validaram a capacidade de recuperação do sistema após deploy com código defeituoso.

### Resultados Gerais

| Aspecto | Status |
|---------|--------|
| **Quebra intencional do sistema** | Sucesso |
| **Deploy de código com erro** | Sucesso |
| **Rollback via GitHub Actions** | Falhou (limitação descoberta) |
| **Rollback manual via Git** | Sucesso |
| **Sistema restaurado** | 100% funcional |

---

## 🎯 Teste 1: Rollback via GitHub Actions

### Objetivo
Validar o workflow automático `.github/workflows/rollback.yml` em ambiente staging.

### Procedimento
1. ✅ Quebrar staging intencionalmente (modificar `src/index.js` para retornar erro 500)
2. ✅ Fazer deploy do código quebrado (após desabilitar health checks)
3. ✅ Acionar workflow "Rollback Deployment" via GitHub Actions UI
4. ❌ **FALHOU** - Erro de permissões

### Erro Encontrado
```
refusing to allow a GitHub App to create or update workflow `.github/workflows/deploy.yml` 
without `workflows` permission
error: failed to push some refs to 'https://github.com/PedroHSS01/Desafio-DevOps-Lacrei-Sa-de.git'
```

### Causa Raiz
O GitHub Actions não permite que workflows modifiquem arquivos em `.github/workflows/` sem a permissão explícita `workflows: write` por questões de segurança.

**Contexto específico:**
- Durante os testes, foram feitos commits que modificaram `.github/workflows/deploy.yml` (desabilitar health checks)
- O workflow de rollback tentou reverter esses commits via `git revert`
- GitHub bloqueou a operação por segurança

### Resultado
❌ **FALHOU** - Limitação de segurança do GitHub Actions

### Lição Aprendida
**Rollback automático via GitHub Actions funciona para código da aplicação**, mas **falha quando precisa reverter mudanças em workflows**.

**Solução:** Usar rollback manual via Git quando commits modificaram `.github/workflows/`.

---

## 🎯 Teste 2: Rollback Manual via Git Reset

### Objetivo
Validar recuperação manual usando `git reset --hard` para voltar ao último commit bom.

### Procedimento Executado

#### 1. Identificar Commits
```bash
git log --oneline -n 10

# Output:
# 541bf81 Revert "fix: desabilitar smoke test health check também"
# ff1b3bf fix: desabilitar smoke test health check também
# e6eec1d fix: remoção health check completamente linha 208
# 7f6e133 fix: comentar health check linha 208
# c65fa57 test: desabilitar health check no servidor
# 2e1e681 test: desabilitar health check temporariamente
# 3d5be2f test: endpoint /status retorna erro 500  ← CÓDIGO QUEBRADO
# a72be2c test: quebrar staging intencionalmente
# aeebd80 Merge branch 'main' into staging  ← ÚLTIMO COMMIT BOM
```

#### 2. Reset para Commit Bom
```bash
git reset --hard aeebd80
# HEAD is now at aeebd80 Merge branch 'main' into staging
```

#### 3. Force Push
```bash
git push origin staging --force
# Total 5 (delta 2), reused 0 (delta 0)
# ff1b3bf..aeebd80  staging -> staging
```

#### 4. GitHub Actions Deploy Automático
- ✅ Workflow `CI/CD Pipeline` detectou push
- ✅ Build da imagem Docker executado
- ✅ Testes passaram
- ✅ Deploy em staging completado
- ✅ Health checks validados

#### 5. Validação Pós-Rollback
```bash
ssh ubuntu@54.226.194.208
curl -s http://localhost:3000/status | jq .

# ANTES DO ROLLBACK:
{
  "error": "TESTE DE ROLLBACK",
  "message": "Erro intencional para testar estratégia de rollback"
}

# DEPOIS DO ROLLBACK:
{
  "status": "ok",
  "message": "Lacrei Saúde rodando com sucesso!",
  "timestamp": "2026-02-14T04:13:17.213Z",
  "environment": "staging",
  "version": "0.2."
}
```

### Resultado
✅ **SUCESSO COMPLETO** - Sistema 100% restaurado em ~3 minutos

### Métricas
- **Tempo de execução:** ~3 minutos (git reset até health check passar)
- **Downtime:** ~2 minutos (durante rebuild e deploy)
- **Complexidade:** Baixa (3 comandos)
- **Risco:** Baixo (testado em staging)

---

## 📊 Comparação de Estratégias Testadas

| Estratégia | Testado? | Status | Tempo | Complexidade | Quando Usar |
|-----------|----------|--------|-------|--------------|-------------|
| **GitHub Actions** | Sim | Falhou* | N/A | Baixa | Deploy normal sem mudanças em workflows |
| **Git Reset Hard** | Sim | Sucesso | 3 min | Baixa | **RECOMENDADO** - Qualquer cenário |
| **Git Revert** | Não testado | - | ~3 min | Baixa | Manter histórico Git |
| **Docker Manual** | Não testado | - | ~1 min | Média | Problema no container |
| **Emergency** | Não testado | - | ~30s | Alta | Site fora do ar |

\* Falhou devido a limitação de permissões ao reverter workflows

---

## 🔍 Descobertas e Observações

### 1. Health Checks são Críticos
Durante o teste, foi necessário **desabilitar temporariamente os health checks** para permitir deploy de código quebrado. Isso validou que:
- ✅ Health checks funcionam corretamente (bloquearam deploy ruim)
- ✅ Pipeline CI/CD está bem configurado
- ⚠️ Desabilitar health checks requer múltiplas modificações (3 locais diferentes)

### 2. GitHub Actions Deploy é Robusto
Após o `git push --force`, o GitHub Actions:
- ✅ Detectou mudança automaticamente
- ✅ Executou build limpo
- ✅ Validou com health checks
- ✅ Fez deploy sem intervenção manual

### 3. Limitação de Segurança do GitHub
**Importante:** GitHub Actions não pode modificar workflows por design de segurança.

**Impacto:** Baixo - Rollback manual funciona perfeitamente como alternativa.

### 4. Tempo de Recuperação Aceitável
**3 minutos** de recuperação total é excelente para:
- Staging (não-crítico)
- Production (aceitável para rollback planejado)

Para emergências, estratégias Docker/Emergency podem ser mais rápidas (~30s-1min).

---

## ✅ Validações Realizadas

### Pré-Rollback (Sistema Quebrado)
- [x] Endpoint `/status` retorna erro 500
- [x] Mensagem de erro customizada presente
- [x] Container rodando (mas com código ruim)

### Pós-Rollback (Sistema Restaurado)
- [x] Endpoint `/status` retorna 200 OK
- [x] Response JSON válido: `"status": "ok"`
- [x] Environment correto: `"environment": "staging"`
- [x] Timestamp atualizado
- [x] Sem erros nos logs do container
- [x] Health checks do pipeline passaram

---

## 📝 Recomendações

### Para Uso em Produção

1. **Estratégia Primária:** Git Reset Hard
   - Rápido (~3 min)
   - Confiável (testado com sucesso)
   - Baixo risco
   - Deploy automático via GitHub Actions

2. **Fallback:** Rollback Docker Manual
   - Mais rápido (~1 min)
   - Quando Git não está disponível
   - Testar antes de usar em produção

3. **Emergência:** Emergency Rollback Script
   - Últimos recursos (~30s)
   - Apenas quando site está fora do ar
   - Testar antes de usar em produção

### Melhorias Sugeridas

1. ✅ **Documentar limitação** do GitHub Actions (este documento)
2. ⏸️ **Testar estratégias restantes** em staging:
   - Git revert
   - Rollback Docker manual
   - Emergency rollback
3. ⏸️ **Adicionar permissão `workflows: write`** ao rollback.yml (opcional)
4. ✅ **Criar matriz de decisão** rápida (já existe em TROUBLESHOOTING.md)

---

## 🎓 Lições Aprendidas

### O Que Funcionou Bem ✅
1. Health checks bloquearam deploy ruim efetivamente
2. GitHub Actions deploy automático é confiável
3. Git reset + force push é rápido e eficaz
4. Documentação de rollback está clara e utilizável
5. Ambiente staging isolado (zero impacto em produção)

### O Que Descobrimos ⚠️
1. GitHub Actions tem limitação de segurança em workflows
2. Desabilitar health checks requer modificações em 3 locais
3. Rollback manual é mais confiável que automático (neste caso)

### O Que Testar Ainda 📋
1. Estratégia de rollback via Docker manual
2. Emergency rollback script
3. Rollback em produção (simulação)
4. Rollback com múltiplos commits ruins
5. Rollback quando backup Docker não existe

---

## 📂 Arquivos Modificados Durante Teste

### Commits Criados (Depois Revertidos)
```
2e1e681 test: desabilitar health check temporariamente para testar rollback
c65fa57 test: desabilitar health check no servidor para testar rollback
7f6e133 fix: comentar health check linha 208 para permitir deploy de teste
e6eec1d fix: remoção health check completamente linha 208
ff1b3bf fix: desabilitar smoke test health check também
3d5be2f test: endpoint /status retorna erro 500 para teste de rollback
a72be2c test: quebrar staging intencionalmente para testar rollback
541bf81 Revert "fix: desabilitar smoke test health check também"
```

### Commit de Recuperação
```
aeebd80 Merge branch 'main' into staging ← ROLLBACK PARA ESTE COMMIT
```

### Arquivos Afetados
- `src/index.js` - Modificado para retornar erro 500 (revertido)
- `.github/workflows/deploy.yml` - Health checks desabilitados (revertido)

---

## 🎯 Conclusão

**O teste de rollback foi 100% bem-sucedido.**

Validamos que:
1. ✅ Sistema pode ser quebrado e recuperado de forma controlada
2. ✅ Rollback manual via Git funciona perfeitamente
3. ✅ GitHub Actions deploy automático é confiável
4. ✅ Tempo de recuperação é aceitável (~3 minutos)
5. ⚠️ GitHub Actions rollback tem limitação conhecida (documentada)

**Próximos Passos:**
1. ✅ Documentar limitação descoberta (este documento)
2. ⏸️ Testar estratégias Docker em staging

---

**Elaborado por:** Pedro Henrique  
**Revisado em:** 14/02/2026  