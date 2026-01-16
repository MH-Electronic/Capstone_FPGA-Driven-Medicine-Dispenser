import { db, auth } from "./firebase-config.js";
import { setDoc, doc, getDoc, arrayUnion } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

// 1. Define this outside so it's globally accessible
async function autoFillPatient(uid) {
    console.log("Searching Firestore for UID:", uid);
    try {
        const docRef = doc(db, "consultations", uid);
        const docSnap = await getDoc(docRef);

        if (docSnap.exists()) {
            const data = docSnap.data();
            document.getElementById("patientName").value = data.patientName || "";
            document.getElementById("age").value = data.age || "";
            document.getElementById("gender").value = data.gender || "";
            console.log("Patient record loaded.");
        } else {
            console.log("New Patient UID: No record found.");
            alert("New Card: " + uid + " not found in database.");
        }
    } catch (error) {
        console.error("Firestore Error:", error);
    }
}

document.addEventListener("DOMContentLoaded", () => {
    // --- DECLARE ALL ELEMENTS AT THE TOP ---
    const medicineSelect = document.getElementById("medicineName");
    const dosageInput = document.getElementById("dosage");
    const prescriptionForm = document.getElementById("prescriptionForm");
    const logoutBtn = document.getElementById("logoutBtn");
    const scanBtn = document.getElementById("scanBtn");
    const patientIdInput = document.getElementById("patientId");

    let port;
    let isScanning = false;
    let reader;

    const dosageMapping = {
        "Paracetamol": "500mg",
        "Ceterizine": "10mg",
        "Loperamide": "2mg",
        "Mefenamic Acid": "250mg",
        "Bromhexine HCL": "8mg"
    };

    // --- RFID SCANNING LOGIC ---
   scanBtn.addEventListener("click", async () => {
        // --- 1. HANDLE CANCEL CLICK ---
        if (isScanning) {
            if (reader) {
                console.log("Cancelling scan and unlocking stream...");
                isScanning = false; // Stop the while loop
                await reader.cancel(); // Wait for browser to stop the stream
            }
            return;
        }

        try {
            if (!port) {
                port = await navigator.serial.requestPort();
            }
            if (!port.readable) {
                await port.open({ baudRate: 115200 });
            }

            isScanning = true;
            scanBtn.classList.add("scanning");
            scanBtn.textContent = "Scanning";

            // Trigger ESP32
            const writer = port.writable.getWriter();
            await writer.write(new TextEncoder().encode("S"));
            writer.releaseLock();

            // --- 2. START READING ---
            reader = port.readable.getReader();
            let accumulatedData = "";
            const decoder = new TextDecoder();

            while (isScanning) {
                const { value, done } = await reader.read();
                if (done || !isScanning) break;

                accumulatedData += decoder.decode(value);
                
                if (accumulatedData.includes("ID:")) {
                    const parts = accumulatedData.split("ID:");
                    const uidPart = parts[1].trim().split("\n")[0].split("\r")[0];
                    
                    if (uidPart.length >= 8) {
                        const cleanUID = uidPart.toUpperCase();
                        patientIdInput.value = cleanUID;
                        await autoFillPatient(cleanUID);
                        break; // Exit loop on success
                    }
                }
            }
        } catch (err) {
            console.error("Serial Error:", err);
            // Ignore the "Abort" error caused by manual cancellation
            if (err.name !== 'AbortError' && !err.message.includes("aborted")) {
                alert("Serial Connection Error: " + err.message);
            }
        } finally {
            // --- 3. CRITICAL CLEANUP ---
            if (reader) {
                try {
                    // Ensure the reader is actually unlocked so the next click works
                    reader.releaseLock();
                } catch (e) {
                    console.log("Reader already released");
                }
                reader = null;
            }
            isScanning = false;
            scanBtn.classList.remove("scanning");
            scanBtn.textContent = "Scan Patient Card";
        }
    });

    // --- MEDICINE AUTO-FILL ---
    if (medicineSelect && dosageInput) {
        medicineSelect.addEventListener("change", (e) => {
            dosageInput.value = dosageMapping[e.target.value] || "";
        });
    }

    // --- AUTHENTICATION ---
    onAuthStateChanged(auth, (user) => {
        if (!user) {
            window.location.href = "login_page.html";
        } else {
            const doctorId = user.email.split("@")[0].toUpperCase();
            document.getElementById("doctorNameDisplay").textContent = `Dr. ${doctorId}`;
            document.getElementById("doctorAvatarDisplay").textContent = doctorId.substring(0, 2);
        }
    });

    if (logoutBtn) {
        logoutBtn.addEventListener("click", () => {
            signOut(auth).then(() => window.location.href = "login_page.html");
        });
    }

    // --- FORM SUBMISSION ---
    if (prescriptionForm) {
        prescriptionForm.addEventListener("submit", async (e) => {
            e.preventDefault();
            
            // Now medicineSelect is properly defined in this scope
            const pId = patientIdInput.value;
            const visitDate = document.getElementById("dateOfVisit").value;

            const medData = {
                medicineName: medicineSelect.value,
                dosage: dosageInput.value,
                quantity: document.getElementById("quantity").value,
                frequency: document.getElementById("frequency").value,
                submittedAt: new Date().toISOString()
            };

            try {
                await setDoc(doc(db, "consultations", pId), {
                    patientId: pId,
                    patientName: document.getElementById("patientName").value,
                    age: document.getElementById("age").value,
                    gender: document.getElementById("gender").value
                }, { merge: true });

                const visitRef = doc(db, "consultations", pId, "visits", visitDate);
                await setDoc(visitRef, {
                    doctorId: auth.currentUser.email.split("@")[0],
                    dateOfVisit: visitDate,
                    remarks: document.getElementById("remarks").value,
                    medications: arrayUnion(medData)
                }, { merge: true });

                alert("Prescription Added Successfully!");
                
                // Reset fields
                medicineSelect.value = "";
                dosageInput.value = "";
                document.getElementById("quantity").value = "";
                document.getElementById("frequency").value = "";
                document.getElementById("remarks").value = "";
            } catch (err) {
                console.error("Submission error:", err);
                alert("Failed to save prescription.");
            }
        });
    }
    
    // Clear Patient Info Button
    document.getElementById("clearPatientInfoBtn").addEventListener("click", () => {
        ["patientName", "patientId", "age", "gender", "dateOfVisit"].forEach(id => {
            const el = document.getElementById(id);
            if(el) el.value = "";
        });
    });
});

