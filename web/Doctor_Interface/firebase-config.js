// Import the functions you need from the SDKs you need
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyD2imLAXuYj-uZMe7N0MaV7XsmAvVuEd-U",
  authDomain: "capstone-doctor-interface.firebaseapp.com",
  projectId: "capstone-doctor-interface",
  storageBucket: "capstone-doctor-interface.firebasestorage.app",
  messagingSenderId: "901592362680",
  appId: "1:901592362680:web:3ac435804b9e53e53cce4d",
  measurementId: "G-0GJ6PZ3V0C"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

export { auth, db };

