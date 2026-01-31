# Email Verification Setup with EmailJS

EmailJS is a free service that lets you send emails directly from Flutter without a backend (300 emails/month free).

## Quick Setup Guide

### Step 1: Create EmailJS Account
1. Go to https://www.emailjs.com/
2. Click **Sign Up** (top right)
3. Sign up with your email (kainamuradarius@gmail.com or any email)
4. Verify your email address

### Step 2: Add Email Service
1. Once logged in, go to **Email Services** (left sidebar)
2. Click **Add New Service** button
3. Choose **Gmail**
4. Click **Connect Account**
5. Log in with your Gmail (kainamuradarius@gmail.com)
6. Copy the **Service ID** (e.g., `service_abc1234`)
   - Keep this ID handy!

### Step 3: Create Email Template
1. Go to **Email Templates** (left sidebar)
2. Click **Create New Template**
3. Template Name: `True Home Verification`
4. Set up the template:

**Subject Line:**
```
Verify Your True Home Account
```

**Content (use this exact format):**
```
Hello {{to_name}},

Thank you for registering with {{app_name}}!

Your email verification code is:

{{verification_code}}

⚠️ This code will expire in 10 minutes.

If you didn't create an account with True Home, please ignore this email.

Best regards,
The True Home Team
```

5. Click **Save** and copy the **Template ID** (e.g., `template_xyz7890`)

### Step 4: Get Your Public Key
1. Go to **Account** → **General** (top right, click your email)
2. Find **Public Key** (under API Keys section)
3. Copy it (e.g., `abcXYZ123_user`)

### Step 5: Update Your App
Open `lib/services/email_verification_service.dart` and replace these three lines:

```dart
static const String _emailJsServiceId = 'YOUR_SERVICE_ID';      // Replace with your Service ID
static const String _emailJsTemplateId = 'YOUR_TEMPLATE_ID';    // Replace with your Template ID  
static const String _emailJsPublicKey = 'YOUR_PUBLIC_KEY';      // Replace with your Public Key
```

Example:
```dart
static const String _emailJsServiceId = 'service_abc1234';
static const String _emailJsTemplateId = 'template_xyz7890';
static const String _emailJsPublicKey = 'abcXYZ123_user';
```

### Step 6: Test!
1. Save the file
2. Hot restart the app in terminal: Press `R`
3. Register a new account with any email
4. **Check your email inbox** - you should receive the verification code!

---

## Troubleshooting

**No email received?**
- Check spam/junk folder
- Verify you saved all three IDs correctly (no extra spaces)
- Make sure you hot restarted the app after saving
- Check EmailJS dashboard for send history

**Error in console?**
- Double-check the Service ID, Template ID, and Public Key
- Make sure EmailJS service is connected to Gmail
- Verify template variable names match: `{{to_name}}`, `{{verification_code}}`, `{{app_name}}`

---

## Option 1: Firebase Cloud Functions (Recommended)

### Step 1: Install Dependencies
```bash
cd functions
npm install
```

### Step 2: Configure Email Credentials

You have two options:

#### A. Using Gmail (For Testing)
1. Enable 2-factor authentication on your Gmail account
2. Generate an App Password: https://myaccount.google.com/apppasswords
3. Set Firebase config:
```bash
firebase functions:config:set email.user="your-email@gmail.com" email.password="your-app-password"
```

#### B. Using SendGrid (Recommended for Production)
1. Sign up at https://sendgrid.com/
2. Get your API key
3. Modify `functions/index.js` to use SendGrid:
```javascript
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);
```

### Step 3: Deploy Functions
```bash
firebase deploy --only functions
```

The function will automatically send emails when a document is created in the `verification_codes` collection.

## Option 2: Firebase Extension (Easiest)

### Install Trigger Email Extension
```bash
firebase ext:install firebase/firestore-send-email
```

Follow the prompts to configure:
- **Collection path**: `mail`
- **SMTP server**: `smtp.gmail.com` (or your provider)
- **SMTP port**: `587`
- **Email**: Your sending email
- **Password**: Your app password

Then update the Flutter app to write to the `mail` collection instead of calling the Cloud Function.

## Option 3: Third-Party Email API (Alternative)

Use services like:
- **EmailJS** (https://www.emailjs.com/) - Free tier available, works directly from Flutter
- **Sendinblue/Brevo** (https://www.brevo.com/) - Free tier, REST API
- **Mailgun** (https://www.mailgun.com/) - Developer-friendly

## Current Status

✅ Verification system is fully functional
✅ Codes are generated and stored in Firestore
✅ Verification logic works correctly
⚠️ Emails are currently printed to console (for testing)
🔄 Need to deploy Cloud Functions for production email sending

## For Testing

The verification code is printed to the console when a user registers. Check your IDE's debug console or use `flutter logs` to see it.

## Security Notes

- Never commit email credentials to Git
- Use Firebase Functions config or environment variables
- Consider using Firebase App Check to prevent abuse
- Implement rate limiting on email sending
