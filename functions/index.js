const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure email transporter
// For Gmail: Enable 2FA and create an App Password
// Or use SendGrid, AWS SES, etc.
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().email?.user || process.env.EMAIL_USER,
    pass: functions.config().email?.password || process.env.EMAIL_PASSWORD
  }
});

// Trigger when a verification code document is created
exports.sendVerificationEmail = functions.firestore
  .document('verification_codes/{userId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const code = data.code;
    const email = data.email;

    const mailOptions = {
      from: `True Home <${functions.config().email?.user || 'noreply@truehome.com'}>`,
      to: email,
      subject: 'Verify Your True Home Account',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { 
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
              color: white; 
              padding: 30px; 
              text-align: center; 
              border-radius: 10px 10px 0 0; 
            }
            .content { 
              background: #f9f9f9; 
              padding: 30px; 
              border-radius: 0 0 10px 10px; 
            }
            .code-box { 
              background: white; 
              border: 2px dashed #667eea; 
              padding: 20px; 
              text-align: center; 
              margin: 20px 0; 
              border-radius: 8px; 
            }
            .code { 
              font-size: 36px; 
              font-weight: bold; 
              letter-spacing: 10px; 
              color: #667eea; 
              font-family: 'Courier New', monospace;
            }
            .footer { 
              text-align: center; 
              margin-top: 20px; 
              color: #666; 
              font-size: 14px; 
            }
            .warning { 
              background: #fff3cd; 
              border-left: 4px solid #ffc107; 
              padding: 15px; 
              margin: 20px 0; 
              border-radius: 4px;
            }
            h1 { margin: 0; font-size: 28px; }
            h2 { color: #333; margin-top: 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🏠 True Home</h1>
              <p style="margin: 5px 0 0 0; font-size: 16px;">Welcome to Your New Home Journey</p>
            </div>
            <div class="content">
              <h2>Verify Your Email Address</h2>
              <p>Thank you for registering with True Home! To complete your registration, please enter the verification code below in the app:</p>
              
              <div class="code-box">
                <p style="margin: 0 0 10px 0; color: #666; font-size: 14px;">Your Verification Code</p>
                <div class="code">${code}</div>
              </div>
              
              <div class="warning">
                <strong>⚠️ Important:</strong> This code will expire in <strong>10 minutes</strong>. Please verify your account promptly.
              </div>
              
              <p style="color: #666;">If you didn't create an account with True Home, please ignore this email.</p>
              
              <div class="footer">
                <p style="margin: 5px 0;">© ${new Date().getFullYear()} True Home. All rights reserved.</p>
                <p style="margin: 5px 0; color: #667eea; font-weight: 500;">Find your dream home with us!</p>
              </div>
            </div>
          </div>
        </body>
        </html>
      `
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log(`✅ Verification email sent to ${email}`);
      return null;
    } catch (error) {
      console.error('❌ Error sending email:', error);
      // Still return success so the user can use the code from console
      return null;
    }
  });

// HTTP function to send verification email (alternative method)
exports.sendVerificationEmailHttp = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { email, code } = data;

  if (!email || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and code are required');
  }

  const mailOptions = {
    from: `True Home <${functions.config().email?.user || 'noreply@truehome.com'}>`,
    to: email,
    subject: 'Verify Your True Home Account',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            padding: 30px; 
            text-align: center; 
            border-radius: 10px 10px 0 0; 
          }
          .content { 
            background: #f9f9f9; 
            padding: 30px; 
            border-radius: 0 0 10px 10px; 
          }
          .code-box { 
            background: white; 
            border: 2px dashed #667eea; 
            padding: 20px; 
            text-align: center; 
            margin: 20px 0; 
            border-radius: 8px; 
          }
          .code { 
            font-size: 36px; 
            font-weight: bold; 
            letter-spacing: 10px; 
            color: #667eea; 
            font-family: 'Courier New', monospace;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🏠 True Home</h1>
            <p style="margin: 5px 0 0 0;">Welcome to Your New Home Journey</p>
          </div>
          <div class="content">
            <h2>Verify Your Email Address</h2>
            <p>Your verification code is:</p>
            <div class="code-box">
              <div class="code">${code}</div>
            </div>
            <p style="color: #999; font-size: 14px;">This code expires in 10 minutes.</p>
          </div>
        </div>
      </body>
      </html>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});
