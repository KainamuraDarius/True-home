# Custom Domain Setup for TrueHome (Afriregister Hosting)

## Overview
- **Main Site (Customer/Agent)**: truehome.com.ug
- **Admin Site**: admin.truehome.com.ug
- **Hosting Provider**: Afriregister Uganda
- **DNS Management**: cPanel at simba.afriregister.com

## Your Login Credentials
- **cPanel URL**: https://simba.afriregister.com:2083/
- **Username**: rmsugnxf
- **Password**: n3NBj2tc%@vO
- **Domain**: truehome.com.ug

## Step 1: Connect Custom Domain to Firebase (Main Site)

1. Open Firebase Console: https://console.firebase.google.com/
2. Select your project: **truehome-9a244**
3. Go to **Hosting** in the left sidebar
4. Click on **Add custom domain**
5. Enter: `truehome.com.ug`
6. Follow Firebase instructions to verify ownership

## Step 2: Connect Admin Subdomain to Firebase

1. In Firebase Console, go to **Hosting**
2. Find the **truehome-admin** site
3. Click **Add custom domain**
4. Enter: `admin.truehome.com.ug`
5. Follow Firebase instructions

## Step 3: DNS Configuration with Afriregister cPanel

You need to configure DNS in your cPanel to point to Firebase:

### Access Your DNS Zone Editor:
1. Login to cPanel: https://simba.afriregister.com:2083/
   - Username: rmsugnxf
   - Password: n3NBj2tc%@vO
2. Find **"Zone Editor"** or **"Advanced DNS Zone Editor"**
3. Select domain: truehome.com.ug

### Add DNS Records (Firebase will provide the exact IPs):

#### For truehome.com.ug (Main site):
Delete existing A records for @ and add Firebase's A records:
```
Type: A
Name: @ (or leave blank for root domain)
Value: <IP from Firebase - usually 151.101.1.195>
TTL: 14400

Type: A
Name: @ (or leave blank)
Value: <IP from Firebase - usually 151.101.65.195>
TTL: 14400
```

#### For admin.truehome.com.ug:
```
Type: A
Name: admin
Value: <IP from Firebase - usually 151.101.1.195>
TTL: 14400

Type: A
Name: admin
Value: <IP from Firebase - usually 151.101.65.195>
TTL: 14400
```

**IMPORTANT:** Firebase will show you the exact IP addresses when you add the custom domain. Use those instead of the examples above.

## Step 4: Deploy to Both Sites

After DNS is configured, deploy your app:

### Deploy to main site (truehome-9a244):
```bash
# Update firebase.json to truehome-9a244
firebase deploy --only hosting
```

### Deploy to admin site (truehome-admin):
```bash
# Update firebase.json to truehome-admin
firebase deploy --only hosting
```

## Step 5: SSL/HTTPS

Firebase automatically provisions SSL certificates for custom domains. This may take up to 24 hours after DNS propagation.

## Step 6: Test

Once DNS propagates (can take 1-48 hours):
- Visit https://truehome.com.ug - should show customer/agent site
- Visit https://admin.truehome.com.ug - should show admin login

## Important Notes

1. **Keep Firebase URLs active** during transition in case DNS takes time
2. **DNS Propagation** can take 24-48 hours
3. **SSL Certificate** provisioning is automatic but may take additional time
4. The code has been updated to recognize both old and new domains

## Verification

Check DNS propagation status:
- Use: https://dnschecker.org/
- Enter your domain to see if DNS records are propagating globally

## Troubleshooting

If domain doesn't work after 48 hours:
1. Verify DNS records are correct in your registrar
2. Check Firebase Hosting console for any errors
3. Ensure you've clicked "Finish setup" in Firebase console
4. Try clearing browser cache and using incognito mode
