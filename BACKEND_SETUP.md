# True Home Backend Setup - Complete Guide

## ✅ System Status

Your True Home application is now fully configured with:

- ✅ PostgreSQL database (`true_home_db`) - Running and connected
- ✅ Node.js backend server - Running on port 3000
- ✅ Real authentication system - Registration and login working
- ✅ USB port forwarding - Phone can access backend via localhost
- ✅ Data persistence - All user data stored in PostgreSQL

## 🚀 Quick Start

### 1. Start Backend Server (if not running)

```bash
cd /home/kainamura/StudioProjects/true_home/backend
node server.js
```

Or run in background:
```bash
cd /home/kainamura/StudioProjects/true_home/backend
nohup node server.js > server.log 2>&1 &
```

### 2. Enable USB Port Forwarding

**IMPORTANT:** Run this command every time you connect your phone:

```bash
adb reverse tcp:3000 tcp:3000
```

This allows your phone to access the backend via `http://localhost:3000`

### 3. Run the Flutter App

```bash
cd /home/kainamura/StudioProjects/true_home
flutter run
```

## 📱 User Flow

### Registration
1. User fills registration form with:
   - Email
   - Password
   - Name
   - Phone number
   - Role (Customer/Manager/Owner)
   - Optional: Company details, WhatsApp

2. On successful registration:
   - Account is created in PostgreSQL database
   - User is redirected to **Login Screen**
   - Success message: "Account created successfully! Please login."

### Login
1. User enters registered email and password
2. Backend verifies credentials from database
3. JWT tokens are generated and stored
4. User is navigated to their role-specific home screen

## 🗄️ Database Information

**Database:** `true_home_db`
**User:** `true_home_user`
**Password:** `true_home_pass123`
**Host:** `localhost`
**Port:** `5432`

### View Registered Users

```bash
sudo -u postgres psql -d true_home_db -c "SELECT id, email, name, role, created_at FROM users;"
```

### Delete Test User

```bash
sudo -u postgres psql -d true_home_db -c "DELETE FROM users WHERE email = 'test@example.com';"
```

### Reset All Data

```bash
sudo -u postgres psql -d true_home_db -c "TRUNCATE users, properties, tour_requests, contact_requests, property_submissions RESTART IDENTITY CASCADE;"
```

## 🔧 Troubleshooting

### Backend Not Connecting

1. **Check if backend is running:**
   ```bash
   ps aux | grep "node server.js"
   ```

2. **Check backend logs:**
   ```bash
   tail -f /home/kainamura/StudioProjects/true_home/backend/server.log
   ```

3. **Test backend health:**
   ```bash
   curl http://localhost:3000/health
   ```

### Phone Can't Connect

1. **Ensure USB port forwarding is active:**
   ```bash
   adb reverse tcp:3000 tcp:3000
   ```

2. **Verify phone is connected:**
   ```bash
   adb devices
   ```

3. **Check if app is using localhost:**
   - Open: `lib/config/api_config.dart`
   - Verify: `baseUrl = _localhostUrl`

### Database Connection Issues

1. **Check PostgreSQL is running:**
   ```bash
   sudo systemctl status postgresql
   ```

2. **Test database connection:**
   ```bash
   psql -h localhost -U true_home_user -d true_home_db -c "SELECT 1;"
   # Password: true_home_pass123
   ```

3. **Restart PostgreSQL:**
   ```bash
   sudo systemctl restart postgresql
   ```

## 📊 API Endpoints

### Authentication
- `POST /api/auth/register` - Create new account
- `POST /api/auth/login` - Login with credentials
- `GET /api/auth/profile` - Get user profile (requires auth)
- `POST /api/auth/refresh` - Refresh access token

### Properties
- `GET /api/properties` - List all properties
- `POST /api/properties` - Create property (requires auth)
- `GET /api/properties/:id` - Get single property

### Health Check
- `GET /health` - Server health status

## 🔐 Security Notes

- Passwords are hashed using bcrypt
- JWT tokens expire after 7 days
- Refresh tokens expire after 30 days
- Database credentials should be changed in production
- JWT secrets should be changed in production

## 📝 Configuration Files

### Backend Configuration
- **Server:** `/home/kainamura/StudioProjects/true_home/backend/server.js`
- **Environment:** `/home/kainamura/StudioProjects/true_home/backend/.env`
- **Dependencies:** `/home/kainamura/StudioProjects/true_home/backend/package.json`

### Flutter Configuration
- **API Config:** `/home/kainamura/StudioProjects/true_home/lib/config/api_config.dart`
- **Auth Service:** `/home/kainamura/StudioProjects/true_home/lib/services/auth_service.dart`
- **Register Screen:** `/home/kainamura/StudioProjects/true_home/lib/screens/auth/register_screen.dart`

## 🎯 Testing the System

### Test Registration (via terminal)

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "password123",
    "name": "Test User",
    "phoneNumber": "0712345678",
    "role": "customer"
  }'
```

### Test Login (via terminal)

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "password123"
  }'
```

## 🚀 Production Deployment Checklist

When deploying to production:

1. ✅ Change JWT_SECRET in `.env`
2. ✅ Change JWT_REFRESH_SECRET in `.env`
3. ✅ Update database password
4. ✅ Use environment variables for all secrets
5. ✅ Enable HTTPS/SSL
6. ✅ Set up proper CORS rules
7. ✅ Add rate limiting
8. ✅ Set up database backups
9. ✅ Use a process manager (PM2) for Node.js
10. ✅ Set up proper logging

## 📞 Support

For issues or questions:
1. Check the logs: `tail -f backend/server.log`
2. Verify database: Check PostgreSQL logs
3. Test endpoints: Use curl commands above
4. Check Flutter console for errors

---

**Last Updated:** December 23, 2025
**System Status:** ✅ Fully Operational
