# MTN Mobile Money Integration Setup

## Overview
This app integrates MTN Mobile Money Collection API for hostel room reservation payments.

## Current Status
- ✅ MTN MoMo service implemented (`lib/services/mtn_momo_service.dart`)
- ✅ Reservation screen updated with payment flow (`lib/screens/customer/reserve_room_screen.dart`)
- ✅ Payment tracking added to ReservationModel
- ⚠️ **Currently in TEST MODE** - Mock payments are enabled until MTN credentials are obtained

## Test Mode
The service is currently running in `useMockMode = true` which means:
- Payment requests will simulate success after 2 seconds
- Payment status checks will always return SUCCESSFUL
- No actual MTN API calls are made
- Perfect for testing the UI flow and reservation creation

## Getting Real MTN Credentials

### Prerequisites
- MTN MoMo Developer Account: https://momodeveloper.mtn.com/
- Collection API subscription key: `ec1bc2bfcfb3454d8188a0845e852912` (already configured)

### Steps to Get API Credentials

1. **Wait for MTN Sandbox to Recover**
   - The sandbox is currently returning 500 errors when creating API users
   - This is a temporary MTN issue, not a problem with your setup
   
2. **Run Setup Script**
   ```bash
   cd android
   dart setup_mtn.dart
   ```
   
   This will:
   - Generate a unique UUID for your API user
   - Create the API user with MTN
   - Generate an API key
   - Display credentials to copy

3. **Configure the Service**
   
   Open `lib/services/mtn_momo_service.dart` and update:
   
   ```dart
   class MTNMoMoService {
     final String subscriptionKey = 'ec1bc2bfcfb3454d8188a0845e852912';
     String? apiUser = 'YOUR_API_USER_UUID_HERE'; // From setup script
     String? apiKey = 'YOUR_API_KEY_HERE'; // From setup script
     
     // Change this to false once you have real credentials
     final bool useMockMode = false; // <<<< CHANGE THIS
   ```

4. **Test with Sandbox**
   
   Use MTN's test phone numbers:
   - For successful payments: `46733123450`
   - For failed payments: `46733123451`
   
   Amount limits in sandbox:
   - Minimum: 100 UGX
   - Maximum: 100,000 UGX

## Alternative: Contact MTN Support

If the sandbox continues to have issues:

1. Email: momodeveloper@mtn.com
2. Explain the 500 error when creating API users
3. Request manual setup of API user credentials
4. Provide your subscription key: `ec1bc2bfcfb3454d8188a0845e852912`

## Payment Flow

### Customer Experience
1. Customer fills reservation form
2. Clicks "Reserve Room" button
3. Payment dialog appears showing:
   - Reservation fee: UGX 20,000
   - MTN Mobile Money branding
   - Instructions on how it works
4. Customer clicks "Pay Now"
5. App sends payment request to their phone
6. Customer receives USSD prompt or notification
7. Customer enters PIN to approve
8. App polls for payment status
9. On success: Reservation is confirmed and saved
10. Customer sees confirmation screen

### Technical Flow
1. `_initiateMTNPayment()` validates form
2. Calls `MTNMoMoService.requestToPay()` with:
   - Amount: 20000
   - Currency: UGX
   - Phone number from form
   - Payment message
3. Shows "Approve on your phone" dialog
4. `_checkPaymentAndComplete()` polls status
5. On SUCCESSFUL:
   - Books the room (decreases availability)
   - Creates reservation with `paymentStatus: 'paid'`
   - Saves transaction ID and reference
   - Navigates to confirmation screen
6. On FAILED:
   - Shows error message
   - Allows retry

## Testing the Implementation

### In Test Mode (Current)
1. Open app and navigate to any hostel
2. Select a room type
3. Click "Reserve"
4. Fill in the form with any details
5. Click "Reserve Room"
6. Click "Pay Now" in the payment dialog
7. Wait 2 seconds for simulated payment
8. Click "I've Paid"
9. Wait 1 second for simulated status check
10. Reservation should be created successfully

### With Real Credentials
1. Set `useMockMode = false` in `mtn_momo_service.dart`
2. Add real `apiUser` and `apiKey`
3. Use test phone number: `256733123450` (Uganda format)
4. Follow same steps as above
5. Approve payment in MTN sandbox
6. Real API calls will be made

## Troubleshooting

### "API credentials not set"
- Make sure you've run the setup script successfully
- Update `apiUser` and `apiKey` in the service file

### "Payment request failed"
- Check if `useMockMode` is set correctly
- Verify subscription key is valid
- Ensure phone number format is correct (256XXXXXXXXX)
- Check MTN sandbox status

### "Payment status is still PENDING"
- This is normal - payments can take 5-30 seconds
- The app will retry automatically
- Make sure to approve the payment on your phone

### 500 Internal Server Error
- This is a known MTN sandbox issue
- Keep `useMockMode = true` for now
- Monitor MTN developer portal for updates
- Contact MTN support if it persists

## Production Deployment

When moving to production:

1. Subscribe to **Production Collection API** (not sandbox)
2. Get production credentials using the same setup process
3. Update `baseUrl` and `collectionUrl` in service:
   ```dart
   final String baseUrl = 'https://momodeveloper.mtn.com';
   final String collectionUrl = 'https://momodeveloper.mtn.com/collection';
   ```
4. Set `X-Target-Environment: 'mtncameroon'` (or your country)
5. Test with real phone numbers
6. Set `useMockMode = false`

## Security Notes

⚠️ **Important**: Never commit real API credentials to version control
- Use environment variables for production
- Consider using Flutter's `--dart-define` for secure config
- Rotate API keys regularly
- Monitor usage on MTN developer portal

## Resources

- MTN MoMo Developer Portal: https://momodeveloper.mtn.com/
- API Documentation: https://momodeveloper.mtn.com/api-documentation/
- Support: momodeveloper@mtn.com
- Subscription Key: `ec1bc2bfcfb3454d8188a0845e852912`
