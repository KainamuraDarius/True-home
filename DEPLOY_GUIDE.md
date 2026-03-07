# True Home Deployment Scripts

## Build & Deploy Customer App (truehome-9a244.web.app)
```powershell
flutter build web --release
firebase deploy --only hosting:truehome-9a244
```

## Build & Deploy Admin Panel (truehome-admin.web.app)
```powershell
flutter build web --release -t lib/main_admin.dart -o build/web_admin
firebase deploy --only hosting:truehome-admin
```

## Deploy Both Sites
```powershell
# Build customer app
flutter build web --release

# Build admin panel to separate folder
flutter build web --release -t lib/main_admin.dart -o build/web_admin

# Deploy both
firebase deploy --only hosting
```

## Quick Commands
```powershell
# Customer app only
flutter build web --release; firebase deploy --only hosting:truehome-9a244

# Admin panel only  
flutter build web --release -t lib/main_admin.dart -o build/web_admin; firebase deploy --only hosting:truehome-admin
```

## URLs
- **Customer App**: https://truehome-9a244.web.app
- **Admin Panel**: https://truehome-admin.web.app
