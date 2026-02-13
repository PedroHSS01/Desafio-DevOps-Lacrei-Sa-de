const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware para logs
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Rota de status
app.get('/status', (req, res) => {
  res.json({ 
    status: 'ok',
    message: 'Lacrei Saúde rodando com sucesso!',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    version: '0.2.'
  });
});

// Rota raiz
app.get('/', (req, res) => {
  res.json({
    message: 'Bem-vindo à API Lacrei Saúde',
    endpoints: {
      status: '/status'
    }
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor rodando na porta ${PORT}`);
  console.log(`📍 Ambiente: ${process.env.NODE_ENV || 'development'}`);
});