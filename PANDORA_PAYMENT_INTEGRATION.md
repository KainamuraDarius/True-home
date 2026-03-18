# Pandora Payment Gateway Integration for Hostel Reservations

## Overview
This document explains the Pandora payment gateway integration for student hostel room reservations.

## Current Status
✅ **IMPLEMENTED** - Pandora payment service is now integrated into the reservation flow

## How It Works

### Payment Flow
1. **User fills reservation form** with:
   - Full name
   - Phone number (Uganda format: +256XXXXXXXXX or 0XXXXXXXXX)
   - Email (optional)

2. **User clicks "Proceed to Payment"**

3. **Payment Dialog appears** showing:
   - Pandora Payment Gateway branding
   - Reservation fee: UGX 20,000
   - Instructions about PIN confirmation

4. **System initiates payment** via Pandora API:
   - Sends payment request with user's phone number
   - Gets transaction ID from Pandora

5. **User enters 4-digit PIN** in-app:
   - PIN is sent to Pandora for confirmation
   - No payment happens until PIN is correctly entered

6. **On successful payment**:
   - Room is booked (decreases availability)
   - Reservation is created with "paid" status
   - Transaction ID and payment reference are saved
   - Confirmation screen is shown

7. **On payment failure**:
   - User sees error message
   - Can try again
   - Room availability is not affected

## Files Modified/Created

### New Files
- `lib/services/pandora_payment_service.dart` - Main Pandora payment service

### Modified Files
- `lib/screens/customer/reserve_room_screen.dart` - Integrated Pandora payment flow

## Configuration

### Step 1: Get Pandora Credentials
Contact Pandora to get your credentials:
- **API Key**
- **Client ID**
- **Merchant ID**
- **API Base URL** (sandbox and production)

### Step 2: Update Service Configuration
Edit `lib/services/pandora_payment_service.dart`:

```dart
// Around line 20-26
static const String _apiKey = 'YOUR_PANDORA_API_KEY';
static const String _clientId = 'YOUR_PANDORA_CLIENT_ID';
static const String _apiBaseUrl = 'https://api.pandora.co.ug/v1'; // YOUR URL
static const String _merchantId = 'YOUR_MERCHANT_ID';
```

### Step 3: Set Callback URLs
Configure these URLs in Pandora dashboard:
- **Callback URL**: `https://truehome.ug/api/payment/callback`
- **Return URL**: `https://truehome.ug/payment/success`

> **Note**: Update these URLs to match your actual backend domain

## API Endpoints Used

### 1. Initiate Payment
```
POST /payment/initiate

Request:
{
  "merchantId": "YOUR_MERCHANT_ID",
  "amount": 20000,           // In UGX (smallest unit)
  "currency": "UGX",
  "customerPhoneNumber": "256774123456",
  "externalId": "HOSTEL_abc123_1234567890",
  "description": "Hostel room reservation",
  "callbackUrl": "https://truehome.ug/api/payment/callback",
  "returnUrl": "https://truehome.ug/payment/success"
}

Response:
{
  "transactionId": "TXN-123456",
  "referenceId": "HOSTEL_abc123_1234567890",
  "message": "Payment request initiated successfully",
  "requestToken": "token_xyz",
  "ussdCode": "*123#" (optional)
}
```

### 2. Confirm Payment with PIN
```
POST /payment/confirm

Request:
{
  "transactionId": "TXN-123456",
  "phoneNumber": "256774123456",
  "pin": "1234"
}

Response:
{
  "success": true,
  "transactionId": "TXN-123456",
  "status": "COMPLETED",
  "message": "Payment confirmed successfully",
  "amount": 20000,
  "timestamp": "2026-03-17T10:30:00Z"
}
```

### 3. Check Payment Status
```
GET /payment/status/{transactionId}?externalId=HOSTEL_abc123_1234567890

Response:
{
  "status": "COMPLETED",
  "message": "Payment completed successfully",
  "amount": 20000,
  "timestamp": "2026-03-17T10:30:00Z"
}
```

## Phone Number Formats Supported

The service automatically normalizes phone numbers:

- `+256774123456` ✅ International format
- `256774123456` ✅ Without plus
- `0774123456` ✅ Uganda domestic format (converted to 256...)
- `+256 774 123 456` ✅ With spaces (spaces removed)

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Invalid phone number" | Phone format incorrect | Use +256 or 0 format with 9 digits |
| "Failed to initiate payment" | API credentials wrong | Check API key, Client ID, Merchant ID |
| "Network error" | Connection issue | Check internet connection |
| "Payment request expired" | Took too long to enter PIN | Try payment again |
| "PIN incorrect" | Wrong PIN entered | Ask user to verify PIN and retry |

## Testing

### Test Mode (Sandbox)
```dart
// Configuration is ready for sandbox testing
// Use test phone numbers provided by Pandora
// Example: 256733123450
```

### Production Deployment
1. Get production credentials from Pandora
2. Update API URLs and credentials in service
3. Test thoroughly with real payments
4. Monitor payment transactions

## Security Considerations

✅ **Security Features Implemented:**
- PIN is entered in-app (user controls entry)
- Sensitive data (API key, client ID) stored in code (move to backend in production)
- HTTPS used for all API calls
- Transaction IDs tracked for audit
- Payment status verified before completing reservation

⚠️ **TODO For Production:**
1. Move API credentials to backend environment variables
2. Implement backend payment verification
3. Add webhook handler for Pandora callbacks
4. Implement payment retry logic with exponential backoff
5. Add comprehensive logging and monitoring
6. Implement PCI compliance measures

## Troubleshooting

### Payment not initiating
**Check:**
- API credentials are correct
- Phone number format is valid
- Internet connection is active
- Check logcat for detailed error messages

### PIN entry screen doesn't appear
**Check:**
- Payment initiation was successful
- Transaction ID was received
- No errors in previous step

### Payment confirmed but reservation not created
**Check:**
- Firebase connection is working
- User has sufficient permissions
- Room availability data is correct
- Check Firestore for conflicting documents

## Database Schema

### Reservations Collection
```firestore
reservations/{docId}
  - id: string
  - propertyId: string
  - propertyTitle: string
  - university: string
  - roomTypeName: string
  - roomPrice: number
  - studentName: string
  - studentPhone: string
  - studentEmail: string
  - studentUserId: string
  - reservationFee: number (20000)
  - paymentStatus: string ("paid", "pending", "failed")
  - paymentReference: string (transaction ID)
  - paymentTransactionId: string (Pandora transaction)
  - paymentDate: timestamp
  - hostelManagerName: string
  - hostelManagerPhone: string
  - hostelManagerEmail: string
  - status: string ("confirmed", "pending", "cancelled")
  - createdAt: timestamp
  - updatedAt: timestamp
```

## Next Steps

1. **Get Pandora Credentials**
   - Contact Pandora support
   - Obtain sandbox credentials for testing
   - Obtain production credentials

2. **Configure Service**
   - Update API key, Client ID, Merchant ID
   - Test with sandbox environment
   - Verify payment flow works end-to-end

3. **Backend Integration**
   - Implement callback handler
   - Verify payments server-side
   - Store payment logs

4. **Testing**
   - Test with various phone number formats
   - Test payment success/failure scenarios
   - Test error handling

5. **Monitoring**
   - Set up payment analytics
   - Monitor failed payments
   - Create admin dashboard for payment management

## Support

For issues or questions:
1. Check logs in Android Studio logcat
2. Review error messages in payment dialogs
3. Test with sandbox credentials first
4. Contact Pandora support for API issues
