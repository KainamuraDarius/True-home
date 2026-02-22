# Firebase Storage CORS Configuration Fix

Your admin web panel cannot display images from Firebase Storage because CORS (Cross-Origin Resource Sharing) is not configured.

## Quick Fix - Set CORS via Google Cloud Console

1. **Open Google Cloud Console Storage**:
   https://console.cloud.google.com/storage/browser?project=truehome-9a244

2. **Click on your bucket** `truehome-9a244.firebasestorage.app` or `truehome-9a244.appspot.com`

3. **Click on "Permissions" tab** at the top

4. **Look for "CORS configuration"** section and click "Edit CORS configuration"

5. **Add this JSON configuration**:
   ```json
   [
     {
       "origin": ["*"],
       "method": ["GET", "HEAD"],
       "responseHeader": ["Content-Type"],
       "maxAgeSeconds": 3600
     }
   ]
   ```

6. **Save** the configuration

7. **Test** your admin panel again - images should now load!

---

## Alternative: Install Google Cloud SDK and use command line

If you prefer command line:

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Initialize and login
gcloud init
gcloud auth login

# Set CORS configuration
gsutil cors set cors.json gs://truehome-9a244.firebasestorage.app
```

The `cors.json` file is already created in your project root.

---

## Verify CORS is set

After setting CORS, verify it's working:

```bash
gsutil cors get gs://truehome-9a244.firebasestorage.app
```

You should see the CORS configuration you just set.

---

## Why this happened

Firebase Storage blocks web requests from different origins by default for security. Since your admin panel is hosted on a different domain/port than the storage bucket, browsers block the image requests unless CORS is properly configured.

The `?alt=media&token=` in your Firebase Storage URLs usually bypasses CORS, but for web Flutter apps using `Image.network()`, explicit CORS configuration is needed.
