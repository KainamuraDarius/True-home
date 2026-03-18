# Quick Setup Checklist - Pandora Payment Integration

## What Was Done ✅
- [x] Created Pandora Payment Service (`pandora_payment_service.dart`)
- [x] Integrated payment service into reservation flow
- [x] Added PIN entry dialog
- [x] Added payment status tracking
- [x] Updated Firestore to track paid reservations
- [x] Proper phone number validation and normalization
- [x] Error handling and user feedback

## What You Need To Do 🔧

### 1. Get Pandora Credentials (CRITICAL)
**Do this FIRST**
- [ ] Contact Pandora or your payment provider
- [ ] Request API credentials:
  - API Key
  - Client ID
  - Merchant ID
  - API Base URL (Sandbox & Production)
- [ ] Get test phone number for sandbox testing

### 2. Update Configuration
Edit: `lib/services/pandora_payment_service.dart`

Replace the placeholder values (around line 20-26):
```dart
static const String _apiKey = 'YOUR_PANDORA_API_KEY';          // ← Update
static const String _clientId = 'YOUR_PANDORA_CLIENT_ID';      // ← Update
static const String _apiBaseUrl = 'https://api.pandora.co.ug/v1'; // ← Update URL
static const String _merchantId = 'YOUR_MERCHANT_ID';          // ← Update
```

### 3. Update Callback URLs
Tell Pandora these URLs in their dashboard:
- Callback URL: `https://yourdomain.com/api/payment/callback`
- Return URL: `https://yourdomain.com/payment/success`

### 4. Test the Flow
1. Build and run the app
2. Navigate to any hostel property
3. Select a room type
4. Click "Reserve Room"
5. Fill in form:
   - Name: Any name
   - Phone: +256 format (or 0...)
   - Email: Optional
6. Click "Proceed to Payment"
7. Enter test PIN when prompted (usually 1234 in sandbox)
8. Watch for success or error messages

### 5. Verify Pandora Integration (If Not Working)

**If payment won't initiate:**
```bash
# Check if Pandora service is imported correctly
grep -r "PandoraPaymentService" lib/

# Check API configuration
grep -r "_apiKey\|_clientId" lib/services/pandora_payment_service.dart

# Enable debug logging to see API responses
# Check Android Studio Logcat during payment attempt
```

**Common issues:**
- [ ] API credentials not updated (most common)
- [ ] Wrong API URL (dev vs production)
- [ ] Phone number format invalid
- [ ] Network connectivity issues
- [ ] Pandora API down or unreachable

### 6. Production Deployment
- [ ] Get production Pandora credentials
- [ ] Update API credentials and URL
- [ ] Set up backend payment verification
- [ ] Implement Pandora webhook callbacks
- [ ] Test with real users (small amounts first)
- [ ] Monitor payment failures

## Current Payment Flow 🔄

```
User Fills Form
    ↓
User Clicks "Proceed to Payment"
    ↓
Payment Dialog Shows
    ↓
Pandora API: Initiate Payment
    ↓
PIN Entry Dialog Shows
    ↓
User Enters 4-digit PIN
    ↓
Pandora API: Confirm with PIN
    ↓
✅ Payment Success OR ❌ Payment Failed
    ↓
Create Reservation & Book Room
    ↓
Show Confirmation Screen
```

## Testing Checklist ✅

- [ ] App builds without errors
- [ ] Can navigate to hostel property
- [ ] Can fill reservation form
- [ ] Payment dialog appears
- [ ] PIN entry dialog appears
- [ ] Can enter 4-digit PIN
- [ ] Error messages display properly if payment fails
- [ ] Reservation is created on success
- [ ] Confirmation screen shows

## Files Changed

1. **Created:**
   - `lib/services/pandora_payment_service.dart` - NEW platform payment service

2. **Modified:**
   - `lib/screens/customer/reserve_room_screen.dart` - Added Pandora integration

3. **Documentation:**
   - `PANDORA_PAYMENT_INTEGRATION.md` - Full technical documentation

## Support & Debugging

### Enable Debug Mode
Add this to see detailed logs:
```dart
// In pandora_payment_service.dart
debugPrint('🔵 Pandora: [message]'); // Appears in Android Studio logcat
```

### Check Logs
```bash
# In Android Studio:
# 1. Open Logcat tab
# 2. Search for "Pandora"
# 3. Watch for 🔵 (info), ❌ (errors)
```

### API Response Format
Check if Pandora returns these fields:
```json
{
  "transactionId": "...",
  "referenceId": "...",
  "status": "...",
  "message": "..."
}
```

If response format differs, update `PandoraPaymentService` methods accordingly.

## Next Session Tasks

1. Update Pandora credentials
2. Test payment flow on device
3. Fix any API response mapping issues
4. Set up backend webhook handler
5. Implement production setup

---
**Status**: Ready for credential configuration
**Next Step**: Insert your Pandora API credentials in `pandora_payment_service.dart`
