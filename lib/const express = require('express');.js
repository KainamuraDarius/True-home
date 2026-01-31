const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json());

// In-memory storage (for testing only)
const users = [];
let userId = 1;

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'True Home Backend Server is running',
    timestamp: new Date().toISOString()
  });
});

// Register endpoint
app.post('/api/auth/register', (req, res) => {
  console.log('📝 Registration request received:', req.body);
  
  const { email, password, name, phoneNumber, role, companyName, whatsappNumber } = req.body;
  
  const existingUser = users.find(u => u.email === email);
  if (existingUser) {
    console.log('❌ User already exists');
    return res.status(400).json({ message: 'User already exists with this email' });
  }
  
  const newUser = {
    id: userId++,
    email,
    name,
    phoneNumber,
    role,
    companyName,
    whatsappNumber,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  
  users.push(newUser);
  
  console.log('✅ User registered successfully:', newUser);
  console.log(`📊 Total users: ${users.length}`);
  
  res.status(201).json({
    user: newUser,
    accessToken: `mock-access-token-${newUser.id}`,
    refreshToken: `mock-refresh-token-${newUser.id}`
  });
});

// Login endpoint
app.post('/api/auth/login', (req, res) => {
  console.log('🔐 Login request:', req.body);
  
  const { email } = req.body;
  const user = users.find(u => u.email === email);
  
  if (!user) {
    console.log('❌ User not found');
    return res.status(401).json({ message: 'Invalid credentials' });
  }
  
  console.log('✅ User logged in:', user);
  res.json({
    user,
    accessToken: `mock-access-token-${user.id}`,
    refreshToken: `mock-refresh-token-${user.id}`
  });
});

// Get user profile
app.get('/api/auth/profile', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  const userIdFromToken = token?.split('-').pop();
  
  const user = users.find(u => u.id == userIdFromToken);
  
  if (!user) {
    return res.status(401).json({ message: 'Unauthorized' });
  }
  
  res.json(user);
});

// Debug endpoint
app.get('/api/debug/users', (req, res) => {
  res.json({ count: users.length, users });
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log('╔════════════════════════════════════════════════╗');
  console.log('║   TRUE HOME BACKEND SERVER                     ║');
  console.log('╠════════════════════════════════════════════════╣');
  console.log(`║   ✅ Server running on port ${PORT}               ║`);
  console.log(`║   📱 Physical: http://192.168.0.133:${PORT}       ║`);
  console.log('║   💾 Using in-memory storage (no database)     ║');
  console.log('╚════════════════════════════════════════════════╝');
});
