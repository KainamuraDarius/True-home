const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Logging middleware (helpful for debugging)
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check - NO /api prefix
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'True Home Backend Server is running',
    timestamp: new Date().toISOString()
  });
});

// Register endpoint
app.post('/api/auth/register', (req, res) => {
  console.log('✅ Registration request received:', req.body);
  
  res.json({
    success: true,
    user: {
      id: Date.now(),
      name: req.body.name,
      email: req.body.email,
      phoneNumber: req.body.phoneNumber,
      role: req.body.role,
    },
    accessToken: 'mock-access-token-' + Date.now(),
    refreshToken: 'mock-refresh-token-' + Date.now(),
  });
});

// Login endpoint
app.post('/api/auth/login', (req, res) => {
  console.log('✅ Login request received:', req.body);
  
  res.json({
    success: true,
    user: {
      id: 1,
      name: 'Test User',
      email: req.body.email,
      role: 'customer',
    },
    accessToken: 'mock-access-token-' + Date.now(),
    refreshToken: 'mock-refresh-token-' + Date.now(),
  });
});

// 404 handler - MUST be last
app.use((req, res) => {
  console.log('❌ Route not found:', req.method, req.path);
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: 'Route not found',
      path: req.path
    }
  });
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log('╔════════════════════════════════════════════════╗');
  console.log('║   TRUE HOME BACKEND SERVER                     ║');
  console.log('╠════════════════════════════════════════════════╣');
  console.log(`║   ✅ Server running on port ${PORT}               ║`);
  console.log(`║   🌐 Local: http://localhost:${PORT}              ║`);
  console.log(`║   📱 Emulator: http://10.0.2.2:${PORT}            ║`);
  console.log(`║   📱 Physical: http://10.53.182.81:${PORT}        ║`);
  console.log('║                                                ║');
  console.log('║   Test endpoints:                              ║');
  console.log(`║   GET  http://localhost:${PORT}/health            ║`);
  console.log(`║   POST http://localhost:${PORT}/api/auth/register║`);
  console.log(`║   POST http://localhost:${PORT}/api/auth/login   ║`);
  console.log('╚════════════════════════════════════════════════╝');
});