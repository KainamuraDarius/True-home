# ✅ Pandora Payments API Integration - UPDATED

## Changes Made

### 1. **Fixed API Configuration** ✅
- **Endpoint**: `https://api.pandorapayments.com/v1` (was: `https://api.pandora.co.ug/v1`)
- **Authentication**: `X-API-Key` header (was: `Authorization: Bearer`)
- **Your API Key**: `$argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM`
- **Callback URL**: `https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook`

### 2. **Updated Payment Flow** ✅
The payment flow is now much simpler:

1. **User submits reservation form** → Shows payment confirmation dialog
2. **Clicks "Proceed to Pay"** → Pandora API initiates transaction
3. **User receives payment prompt** on phone:
   - MTN: USSD prompt (*165# or mobile money app)
   - Airtel: Mobile money app notification
4. **User completes payment on phone** (no PIN entry needed in app)
5. **App polls payment status** every 5 seconds
6. **Payment confirmed** → Reservation is created automatically

### 3. **API Endpoints Used**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/transactions/mobile-money` | Initiate payment |
| GET | `/transactions/{ref}` | Check payment status |
| POST | `/transactions/{ref}/cancel` | Cancel payment |

### 4. **Request/Response Format** ✅

**Initiate Payment - Request:**
```json
{
  "amount": 20000,
  "transaction_ref": "HOSTEL_prop123_timestamp",
  "contact": "256701234567",
  "narrative": "Hostel room reservation - Property name",
  "callback_url": "https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook"
}
```

**Headers:**
```
Content-Type: application/json
X-API-Key: $argon2id$v=19$m=65536,t=4,p=3$TnZqZTdOWEd3enVxVHZyMw$Dvu0B/DsxqDfxoHzQKTgKLUeXZ242xJhooLf7sWUdOM
```

**Response:**
```json
{
  "statusCode": 200,
  "success": true,
  "messages": ["Waiting for user to confirm mobile money transfer."],
  "data": [{
    "status": "processing",
    "transaction_reference": "HOSTEL_prop123_timestamp",
    "amount": "20000.00",
    "transaction_charge": "35.00",
    "network": "MTN UG",
    "initiated_at": "2025-03-24 23:21:03"
  }]
}
```

### 5. **Files Updated**

#### `lib/services/pandora_payment_service.dart`
- ✅ Fixed API base URL and endpoint
- ✅ Changed auth to `X-API-Key` header
- ✅ Updated endpoint paths
- ✅ Simplified payment initiation (no PIN needed)
- ✅ Added status polling method
- ✅ Updated response models

Key methods:
- `initiatePayment()` → Starts transaction on Pandora
- `checkPaymentStatus()` → Polls transaction status
- `cancelPayment()` → Cancels payment request
- `_normalizePhoneNumber()` → Converts 0xxx/+256xxx to 256xxx format
- `_isValidUgandanPhoneNumber()` → Validates phone format

#### `lib/screens/customer/reserve_room_screen.dart`
- ✅ Updated payment dialog message (no PIN mention)
- ✅ Removed `_showPINEntryDialog()` method
- ✅ Removed `_confirmPaymentWithPIN()` method
- ✅ Added `_showPaymentStatusDialog()` - shows "check your phone"
- ✅ Added `_pollPaymentStatus()` - checks payment every 5 seconds
- ✅ Updated `_initiatePandoraPayment()` to call new status checker

## How It Works Now

### Payment Initiation
```dart
// User clicks "Proceed to Pay"
await _pandoraService.initiatePayment(
  phoneNumber: '256701234567',
  amount: 20000,
  transactionRef: 'HOSTEL_prop123_1711323600000',
  narrative: 'Hostel room reservation - TrueHome Villa',
);
```

### Status Polling
```dart
// App checks every 5 seconds for up to 5 minutes
await _pandoraService.checkPaymentStatus(
  transactionRef: 'HOSTEL_prop123_1711323600000',
);
// Returns: { success: true, status: "completed", ... }
```

### On Payment Success
- Dialog automatically closes
- Reservation is created with `paymentStatus: "paid"`
- User is taken to confirmation screen

## Testing the Payment Flow

### Steps to Test:
1. Open app → Browse properties → Select a hostel
2. Click "Reserve" → Fill form → Click "Proceed to Payment"
3. **Important**: Use a valid Uganda phone number (format: 256XXXXXXXXX)
4. Payment dialog shows "Check Your Phone"
5. Wait for USSD/mobile money app prompt on your phone
6. Complete payment on phone
7. App should confirm payment within seconds and create reservation

### Phone Number Formats (All work):
- ✅ `256701234567` (international format)
- ✅ `+256701234567` (with + prefix)
- ✅ `0701234567` (local format)
- ✅ `256 701 234 567` (with spaces)

## Known Limitations & Notes

1. **Pandora Webhook**: When payment completes, Pandora will POST to your callback URL
   - Your function should listen at: `/pandoraPaymentWebhook`
   - Extract `transaction_reference` and update Firestore reservation

2. **Transaction Status**: Statuses can be:
   - `processing` - User hasn't completed yet
   - `completed` - Payment successful ✅
   - `failed` - Payment failed ❌
   - `cancelled` - User cancelled
   - `expired` - Request timed out

3. **Phone Validation**: Must be Uganda number (starting with 0, 256, or +256)
   - Service automatically converts all formats to 256XXXXXXXXX

## What's Next

1. **Test with real credentials**
   - Run app and attempt a test reservation
   - Check if USSD prompt appears on phone

2. **Webhook Handler** (if using production)
   - Test callback at: `https://us-central1-truehome-9a244.cloudfunctions.net/pandoraPaymentWebhook`
   - Implement webhook verification for security

3. **Production Checklist**
   - [ ] Update reservation fee if needed
   - [ ] Test with multiple phone numbers
   - [ ] Verify webhook notifications working
   - [ ] Set up email confirmation for hosts
   - [ ] Add transaction history to user dashboard

## Debug Commands

Check logs while testing:
```bash
# In Flutter app console, watch for:
🔵 PANDORA PAYMENTS: Initiating Transaction
📡 Response Status: 200
📡 Transaction Status: completed
```

## API Documentation Reference
https://api.pandorapayments.com/docs

**API Rate Limits**: Check Pandora docs for rate limits (typically 100-1000 requests/minute)
