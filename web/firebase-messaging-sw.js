importScripts(
  'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js',
);

const parameters = new URL(self.location.href).searchParams;
firebase.initializeApp({
  apiKey: parameters.get('apiKey'),
  appId: parameters.get('appId'),
  authDomain: parameters.get('authDomain') || undefined,
  messagingSenderId: parameters.get('messagingSenderId'),
  projectId: parameters.get('projectId'),
  storageBucket: parameters.get('storageBucket') || undefined,
});

firebase.messaging();
