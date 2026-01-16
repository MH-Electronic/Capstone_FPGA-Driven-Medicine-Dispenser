import { auth } from "./firebase-config.js";
import { 
    signInWithEmailAndPassword, 
    createUserWithEmailAndPassword,
    signOut // <-- NEW: Import signOut
} from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

// === DOM ELEMENT REFERENCES ===
const loginForm = document.getElementById("loginForm");
const formTitle = document.getElementById("formTitle");
const formSubtitle = document.getElementById("formSubtitle");
const submitBtn = document.getElementById("submitBtn");
const toggleLink = document.getElementById("toggleLink");

const doctorIdInput = document.getElementById("doctorId"); 
const passwordInput = document.getElementById("password");

let isRegistering = false;

// === TOGGLE LOGIN/REGISTER VIEW ===
toggleLink.addEventListener("click", (e) => {
    e.preventDefault();
    isRegistering = !isRegistering;

    if (isRegistering) {
        formTitle.textContent = "Create Account";
        formSubtitle.textContent = "Register a new Doctor ID to get started";
        submitBtn.textContent = "Register";
        toggleLink.textContent = "Back to Login";
    } else {
        formTitle.textContent = "Welcome Back";
        formSubtitle.textContent = "Please enter your credentials to access the portal";
        submitBtn.textContent = "Sign In";
        toggleLink.textContent = "Register New Doctor ID";
    }

    loginForm.reset();
});

// === AUTHENTICATION HANDLER ===
loginForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    const doctorId = doctorIdInput.value.trim();
    const password = passwordInput.value.trim();
    const email = `${doctorId}@medportal.local`; 

    if (!doctorId || !password) {
        alert("Please fill in all fields.");
        return;
    }

    try {
        if (isRegistering) {
            // 1. Create the new user
            await createUserWithEmailAndPassword(auth, email, password);
            
            // 2. Sign out the user immediately (stops auto-login and redirect)
            await signOut(auth); 

            // 3. Notify user and reset the form view
            alert("Registration successful! You can now sign in.");
            toggleLink.click(); // Switch form back to "Sign In" view
            
            // 4. No redirection here, function finishes

        } else {
            // Sign In attempt
            await signInWithEmailAndPassword(auth, email, password);
            
            // 5. Redirect ONLY on successful sign-in
            window.location.href = "main_page.html"; 
        }
        
    } catch (error) {
        let message = error.message;
        if (error.code === 'auth/email-already-in-use') message = "This Doctor ID is already registered.";
        if (error.code === 'auth/invalid-credential') message = "Invalid Doctor ID or Password.";
        if (error.code === 'auth/weak-password') message = "Password should be at least 6 characters.";
        
        console.error("Authentication Error:", error);
        alert(message);
    }
});

