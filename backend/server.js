const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// JWT Secret (in production, use environment variable)
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-super-secret-refresh-key-change-this';

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// PostgreSQL connection pool
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'true_home_db',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
});

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Database connection error:', err.message);
    console.log('⚠️  Running in NO-DATABASE mode. Some features will use in-memory storage.');
  } else {
    console.log('✅ Database connected successfully at', res.rows[0].now);
  }
});

// In-memory storage (fallback if database is not available)
let inMemoryUsers = [];
let inMemoryProperties = [];
let inMemoryTourRequests = [];
let inMemoryContactRequests = [];

// Configure nodemailer transporter
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER || 'your-email@gmail.com',
    pass: process.env.EMAIL_PASSWORD || 'your-app-password'
  }
});

// Test email configuration on startup
transporter.verify((error, success) => {
  if (error) {
    console.log('⚠️  Email service not configured:', error.message);
    console.log('   Add EMAIL_USER and EMAIL_PASSWORD to .env file');
  } else {
    console.log('✅ Email service ready');
  }
});

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Helper function to check if database is available
const isDatabaseAvailable = async () => {
  try {
    await pool.query('SELECT 1');
    return true;
  } catch (error) {
    return false;
  }
};

// ============================================
// HEALTH CHECK
// ============================================
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    service: 'True Home API'
  });
});

// ============================================
// EMAIL VERIFICATION ROUTES
// ============================================

// Send verification code via email
app.post('/api/email/send-verification', async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required' });
    }

    // Email template
    const mailOptions = {
      from: process.env.EMAIL_USER || 'noreply@truehome.com',
      to: email,
      subject: 'Verify Your True Home Account',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
            .code-box { background: white; border: 2px dashed #667eea; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; }
            .code { font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #667eea; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 14px; }
            .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin: 20px 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🏠 True Home</h1>
              <p>Welcome to Your New Home Journey</p>
            </div>
            <div class="content">
              <h2>Verify Your Email Address</h2>
              <p>Thank you for registering with True Home! To complete your registration, please enter the verification code below:</p>
              
              <div class="code-box">
                <p style="margin: 0; color: #666;">Your Verification Code</p>
                <div class="code">${code}</div>
              </div>
              
              <div class="warning">
                <strong>⚠️ Important:</strong> This code will expire in 10 minutes. Please verify your account promptly.
              </div>
              
              <p>If you didn't create an account with True Home, please ignore this email.</p>
              
              <div class="footer">
                <p>© ${new Date().getFullYear()} True Home. All rights reserved.</p>
                <p>Find your dream home with us!</p>
              </div>
            </div>
          </div>
        </body>
        </html>
      `
    };

    // Send email
    await transporter.sendMail(mailOptions);
    
    res.json({ success: true, message: 'Verification email sent successfully' });
  } catch (error) {
    console.error('Error sending verification email:', error);
    res.status(500).json({ error: 'Failed to send verification email', details: error.message });
  }
});

// ============================================
// AUTHENTICATION ROUTES
// ============================================

// Register new user
app.post('/api/auth/register', async (req, res) => {
  try {
    const {
      email,
      password,
      name,
      phoneNumber,
      role,
      companyName,
      companyAddress,
      whatsappNumber
    } = req.body;

    // Validate required fields
    if (!email || !password || !name || !phoneNumber || !role) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    const dbAvailable = await isDatabaseAvailable();

    if (dbAvailable) {
      // Check if user already exists
      const existingUser = await pool.query(
        'SELECT * FROM users WHERE email = $1',
        [email]
      );

      if (existingUser.rows.length > 0) {
        return res.status(400).json({ error: 'User already exists' });
      }

      // Insert new user
      const result = await pool.query(
        `INSERT INTO users (email, password, name, phone_number, role, company_name, company_address, whatsapp_number)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING id, email, name, phone_number, role, company_name, company_address, whatsapp_number, profile_image_url, is_verified, created_at, updated_at`,
        [email, hashedPassword, name, phoneNumber, role, companyName, companyAddress, whatsappNumber]
      );

      const user = result.rows[0];

      // Generate tokens
      const accessToken = jwt.sign(
        { id: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '7d' }
      );

      const refreshToken = jwt.sign(
        { id: user.id, email: user.email },
        JWT_REFRESH_SECRET,
        { expiresIn: '30d' }
      );

      res.status(201).json({
        user: {
          id: user.id.toString(),
          email: user.email,
          name: user.name,
          phoneNumber: user.phone_number,
          role: user.role,
          companyName: user.company_name,
          companyAddress: user.company_address,
          whatsappNumber: user.whatsapp_number,
          profileImageUrl: user.profile_image_url,
          isVerified: user.is_verified,
          createdAt: user.created_at,
          updatedAt: user.updated_at,
        },
        accessToken,
        refreshToken,
      });
    } else {
      // In-memory fallback
      const existingUser = inMemoryUsers.find(u => u.email === email);
      if (existingUser) {
        return res.status(400).json({ error: 'User already exists' });
      }

      const newUser = {
        id: (inMemoryUsers.length + 1).toString(),
        email,
        password: hashedPassword,
        name,
        phoneNumber,
        role,
        companyName,
        companyAddress,
        whatsappNumber,
        profileImageUrl: null,
        isVerified: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      inMemoryUsers.push(newUser);

      const accessToken = jwt.sign(
        { id: newUser.id, email: newUser.email, role: newUser.role },
        JWT_SECRET,
        { expiresIn: '7d' }
      );

      const refreshToken = jwt.sign(
        { id: newUser.id, email: newUser.email },
        JWT_REFRESH_SECRET,
        { expiresIn: '30d' }
      );

      const { password: _, ...userWithoutPassword } = newUser;

      res.status(201).json({
        user: userWithoutPassword,
        accessToken,
        refreshToken,
      });
    }
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error during registration' });
  }
});

// Login user
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }

    const dbAvailable = await isDatabaseAvailable();

    if (dbAvailable) {
      const result = await pool.query(
        'SELECT * FROM users WHERE email = $1',
        [email]
      );

      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const user = result.rows[0];

      const validPassword = await bcrypt.compare(password, user.password);
      if (!validPassword) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const accessToken = jwt.sign(
        { id: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '7d' }
      );

      const refreshToken = jwt.sign(
        { id: user.id, email: user.email },
        JWT_REFRESH_SECRET,
        { expiresIn: '30d' }
      );

      res.json({
        user: {
          id: user.id.toString(),
          email: user.email,
          name: user.name,
          phoneNumber: user.phone_number,
          role: user.role,
          companyName: user.company_name,
          companyAddress: user.company_address,
          whatsappNumber: user.whatsapp_number,
          profileImageUrl: user.profile_image_url,
          isVerified: user.is_verified,
          createdAt: user.created_at,
          updatedAt: user.updated_at,
        },
        accessToken,
        refreshToken,
      });
    } else {
      // In-memory fallback
      const user = inMemoryUsers.find(u => u.email === email);
      if (!user) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const validPassword = await bcrypt.compare(password, user.password);
      if (!validPassword) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const accessToken = jwt.sign(
        { id: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '7d' }
      );

      const refreshToken = jwt.sign(
        { id: user.id, email: user.email },
        JWT_REFRESH_SECRET,
        { expiresIn: '30d' }
      );

      const { password: _, ...userWithoutPassword } = user;

      res.json({
        user: userWithoutPassword,
        accessToken,
        refreshToken,
      });
    }
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error during login' });
  }
});

// Get user profile
app.get('/api/auth/profile', authenticateToken, async (req, res) => {
  try {
    const dbAvailable = await isDatabaseAvailable();

    if (dbAvailable) {
      const result = await pool.query(
        'SELECT id, email, name, phone_number, role, company_name, company_address, whatsapp_number, profile_image_url, is_verified, created_at, updated_at FROM users WHERE id = $1',
        [req.user.id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }

      const user = result.rows[0];
      res.json({
        id: user.id.toString(),
        email: user.email,
        name: user.name,
        phoneNumber: user.phone_number,
        role: user.role,
        companyName: user.company_name,
        companyAddress: user.company_address,
        whatsappNumber: user.whatsapp_number,
        profileImageUrl: user.profile_image_url,
        isVerified: user.is_verified,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
      });
    } else {
      // In-memory fallback
      const user = inMemoryUsers.find(u => u.id === req.user.id);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      const { password: _, ...userWithoutPassword } = user;
      res.json(userWithoutPassword);
    }
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Refresh token
app.post('/api/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(401).json({ error: 'Refresh token required' });
  }

  jwt.verify(refreshToken, JWT_REFRESH_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid refresh token' });
    }

    const accessToken = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({ accessToken });
  });
});

// ============================================
// PROPERTIES ROUTES (Basic implementation)
// ============================================

// Get all properties
app.get('/api/properties', async (req, res) => {
  try {
    const dbAvailable = await isDatabaseAvailable();

    if (dbAvailable) {
      const result = await pool.query(
        'SELECT * FROM properties WHERE is_available = true ORDER BY created_at DESC'
      );
      res.json(result.rows);
    } else {
      // In-memory fallback
      res.json(inMemoryProperties);
    }
  } catch (error) {
    console.error('Fetch properties error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get single property
app.get('/api/properties/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const dbAvailable = await isDatabaseAvailable();

    if (dbAvailable) {
      const result = await pool.query('SELECT * FROM properties WHERE id = $1', [id]);
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Property not found' });
      }
      res.json(result.rows[0]);
    } else {
      // In-memory fallback
      const property = inMemoryProperties.find(p => p.id === id);
      if (!property) {
        return res.status(404).json({ error: 'Property not found' });
      }
      res.json(property);
    }
  } catch (error) {
    console.error('Fetch property error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create property
app.post('/api/properties', authenticateToken, async (req, res) => {
  try {
    const propertyData = req.body;
    const dbAvailable = await isDatabaseAvailable();

    if (dbAvailable) {
      const result = await pool.query(
        `INSERT INTO properties (title, description, type, price, currency, location, latitude, longitude,
         image_urls, bedrooms, bathrooms, square_meters, amenities, manager_id, manager_name, manager_phone, manager_email)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
         RETURNING *`,
        [
          propertyData.title, propertyData.description, propertyData.type, propertyData.price,
          propertyData.currency || 'USD', propertyData.location, propertyData.latitude, propertyData.longitude,
          propertyData.imageUrls || [], propertyData.bedrooms, propertyData.bathrooms,
          propertyData.squareMeters, propertyData.amenities || [], req.user.id,
          propertyData.managerName, propertyData.managerPhone, propertyData.managerEmail
        ]
      );
      res.status(201).json(result.rows[0]);
    } else {
      // In-memory fallback
      const newProperty = {
        id: (inMemoryProperties.length + 1).toString(),
        ...propertyData,
        managerId: req.user.id,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      inMemoryProperties.push(newProperty);
      res.status(201).json(newProperty);
    }
  } catch (error) {
    console.error('Create property error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ============================================
// ERROR HANDLING
// ============================================
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ============================================
// START SERVER
// ============================================
app.listen(PORT, '0.0.0.0', () => {
  console.log('\n🚀 True Home Backend Server');
  console.log('================================');
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`📍 Local: http://localhost:${PORT}`);
  console.log(`📍 Network: http://0.0.0.0:${PORT}`);
  console.log(`🔍 Health check: http://localhost:${PORT}/health`);
  console.log('================================\n');
});
