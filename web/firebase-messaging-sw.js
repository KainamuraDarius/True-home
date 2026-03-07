importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: 'AIzaSyDfGVLb-tBvyXpfQLzi-Rw3oP1taV145wY',
  appId: '1:843422990018:web:19395b0ae931a98498455b',
  messagingSenderId: '843422990018',
  projectId: 'truehome-9a244',
  authDomain: 'truehome-9a244.firebaseapp.com',
  storageBucket: 'truehome-9a244.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'TrueHome';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/icons/icon.jpeg',
    badge: '/icons/icon.jpeg',
    tag: payload.data?.type || 'truehome-notification',
    data: payload.data,
    vibrate: [200, 100, 200],
    requireInteraction: true,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event);
  
  event.notification.close();
  
  // Navigate to appropriate page based on notification type
  const data = event.notification.data;
  let url = '/';
  
  if (data?.type === 'new_property' && data?.propertyId) {
    url = `/property/${data.propertyId}`;
  } else if (data?.type === 'property_approved' || data?.type === 'property_rejected') {
    url = '/my-properties';
  }
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a window is already open, focus it
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
