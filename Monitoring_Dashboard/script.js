import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import {
    getFirestore,
    doc,
    getDoc,
    onSnapshot
} from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

const firebaseConfig = {
    apiKey: "AIzaSyD2imLAXuYj-uZMe7N0MaV7XsmAvVuEd-U",
    authDomain: "capstone-doctor-interface.firebaseapp.com",
    projectId: "capstone-doctor-interface",
    storageBucket: "capstone-doctor-interface.firebasestorage.app",
    messagingSenderId: "901592362680",
    appId: "1:901592362680:web:3ac435804b9e53e53cce4d"
};

const MEDICINE_NAMES = [
    "Bromhexine HCL",  
    "Paracetamol",     
    "Mefenamic Acid",  
    "Loperamide",      
    "Ceterizine"       
];

class MedicineDispenserDashboard {
    constructor() {
        this.app = initializeApp(firebaseConfig);
        this.db = getFirestore(this.app);

        // Default to '0' (Available) based on your new logic
        this.machine = { status: 'online', stocks: [0, 0, 0, 0, 0] }; 
        this.dispensingLogs = [];
        this.init();

        window.triggerTestAlert = (meds) => this.triggerRefillAlert(meds);
    }

    init() {
        this.setupRealtimeListeners();
        this.setupEventListeners();
        
        const today = new Date();
        const localDate = new Date(today.getTime() - (today.getTimezoneOffset() * 60000)).toISOString().split('T')[0];
        const dateInput = document.getElementById('logDate');
        if (dateInput) {
            dateInput.value = localDate;
            this.fetchLogsByDate(localDate);
        }
    }

    setupRealtimeListeners() {
        onSnapshot(doc(this.db, "machines", "MED-001"), (snapshot) => {
            if (snapshot.exists()) {
                this.machine.status = snapshot.data().status || 'online';
                this.updateUI();
            }
        });

        // REVERTED LOGIC: 0 = Stock Available, 1 = Refill Needed
        onSnapshot(doc(this.db, "sensor", "status"), (snapshot) => {
            if (snapshot.exists()) {
                const data = snapshot.data();
                
                const newStocks = [
                    data.A ?? 0, 
                    data.B ?? 0, 
                    data.C ?? 0, 
                    data.D ?? 0, 
                    data.E ?? 0
                ];

                console.log("--- Current Medication Status ---");
                newStocks.forEach((val, idx) => {
                    const status = val === 1 ? "EMPTY (Refill Needed)" : "OK (Stock Available)";
                    console.log(`${MEDICINE_NAMES[idx]}: ${status} [Signal: ${val}]`);
                });

                const newlyEmptyMeds = [];
                newStocks.forEach((newLevel, index) => {
                    const oldLevel = this.machine.stocks[index];
                    // Alert if transition from 0 (OK) to 1 (EMPTY)
                    if (oldLevel === 0 && newLevel === 1) {
                        newlyEmptyMeds.push(MEDICINE_NAMES[index]);
                    }
                });

                if (newlyEmptyMeds.length > 0) {
                    this.triggerRefillAlert(newlyEmptyMeds);
                }

                this.machine.stocks = newStocks;
                this.updateUI();
            }
        });
    }

    triggerRefillAlert(medicationList) {
        if (document.querySelector('.refill-overlay')) return;

        const overlay = document.createElement('div');
        overlay.className = 'refill-overlay';
        
        const alertBox = document.createElement('div');
        alertBox.className = 'refill-alert-box';
        
        alertBox.style.cssText = `
            background: white; 
            color: #e74c3c; 
            padding: 40px; 
            border-radius: 20px; 
            box-shadow: 0 25px 50px rgba(0,0,0,0.4);
            display: flex; 
            flex-direction: column; 
            align-items: center; 
            gap: 25px;
            text-align: center;
            min-width: 380px;
            max-width: 500px;
            animation: modalFadeIn 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
        `;

        const medText = medicationList.join(', ');

        alertBox.innerHTML = `
            <i class="fas fa-exclamation-circle fa-5x"></i>
            <div style="font-family: 'Segoe UI', sans-serif;">
                <h2 style="margin: 0 0 10px 0; font-size: 2rem; font-weight: 800; text-transform: uppercase;">Refill Required</h2>
                <p style="margin: 0; font-size: 1.3rem; line-height: 1.4;">
                    The following are empty:<br>
                    <strong style="color: #c0392b; display: block; margin-top: 10px; font-size: 1.5rem;">${medText}</strong>
                </p>
            </div>
            <button style="
                background: #e74c3c; color: white; border: none; 
                padding: 15px 50px; border-radius: 10px; font-size: 1.1rem;
                font-weight: 700; cursor: pointer;
                box-shadow: 0 4px 15px rgba(231, 76, 60, 0.4);
                transition: all 0.2s ease;"
                onclick="this.closest('.refill-overlay').remove()">
                ACKNOWLEDGE & CLOSE
            </button>
        `;
        
        overlay.appendChild(alertBox);
        document.body.appendChild(overlay);
    }

    updateUI() {
        const grid = document.getElementById('medicationGrid');
        if (!grid) return;
        grid.innerHTML = '';

        MEDICINE_NAMES.forEach((name, index) => {
            const level = this.machine.stocks[index];
            
            // LOGIC: 0 is Available, 1 is Empty
            const isRefillNeeded = (level === 1); 
            const statusClass = isRefillNeeded ? 'stock-low' : 'stock-ok';
            
            const item = document.createElement('div');
            item.className = `med-item ${statusClass}`;
            
            item.innerHTML = `
                <div class="med-info">
                    <h3>${name}</h3>
                </div>
                <div class="med-status">
                    <span class="status-badge ${statusClass}">
                        ${isRefillNeeded ? 
                            '<i class="fas fa-exclamation-triangle"></i> Refill Needed' : 
                            '<i class="fas fa-check-circle"></i> Stock Available'}
                    </span>
                </div>`;
            grid.appendChild(item);
        });

        const statusBtn = document.getElementById('statusBtn');
        if (statusBtn) {
            statusBtn.textContent = (this.machine.status || 'offline').toUpperCase();
            statusBtn.className = `mode-btn ${this.machine.status}`;
        }
    }

    fetchLogsByDate(dateStr) {
        if (!dateStr) return;
        onSnapshot(doc(this.db, "logs", dateStr), (snapshot) => {
            const tbody = document.getElementById('logsTableBody');
            if (!tbody) return;

            if (snapshot.exists() && snapshot.data().entries) {
                this.dispensingLogs = Object.values(snapshot.data().entries);
                this.dispensingLogs.sort((a, b) => (b.timestamp || "").localeCompare(a.timestamp || ""));
                this.renderLogTable();
            } else {
                this.dispensingLogs = [];
                tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding: 20px;">No logs found for this date.</td></tr>';
            }
        });
    }

    renderLogTable() {
        const tbody = document.getElementById('logsTableBody');
        if (!tbody) return;
        tbody.innerHTML = '';
        
        this.dispensingLogs.forEach((log, index) => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${log.timestamp || '--:--'}</td>
                <td>${log.patient_id || 'N/A'}</td>
                <td>${log.source_visit || 'N/A'}</td>
                <td><span class="status-success">Dispensed</span></td>
                <td><button class="view-btn" onclick="window.dashboardApp.showLogDetails(${index})">View</button></td>
            `;
            tbody.appendChild(row);
        });
    }

    async showLogDetails(index) {
        const log = this.dispensingLogs[index];
        const modal = document.getElementById('logDetailModal');
        const body = document.getElementById('logDetailBody');
        if (!modal || !body) return;

        body.innerHTML = '<div style="text-align:center; padding:20px;"><i class="fas fa-spinner fa-spin"></i> Fetching...</div>';
        modal.style.display = 'block';

        try {
            const visitPath = `consultations/${log.patient_id}/visits/${log.source_visit}`;
            const patientPath = `consultations/${log.patient_id}`;
            const [visitSnap, patientSnap] = await Promise.all([
                getDoc(doc(this.db, visitPath)),
                getDoc(doc(this.db, patientPath))
            ]);

            if (visitSnap.exists()) {
                const visitData = visitSnap.data();
                const patientData = patientSnap.exists() ? patientSnap.data() : {};
                const patientName = patientData.name || patientData.patientName || visitData.patientName || "Unknown Patient";
                const rawMeds = visitData.medications || []; 
                const medsArray = Array.isArray(rawMeds) ? rawMeds : Object.values(rawMeds);

                body.innerHTML = `
                    <div style="margin-bottom:15px; border-bottom:1px solid #eee; padding-bottom:12px;">
                        <p><strong>Patient:</strong> ${patientName}</p>
                        <p><strong>ID:</strong> ${log.patient_id}</p>
                    </div>
                    <div>
                        <h4 style="margin-bottom: 8px;">Medications:</h4>
                        ${medsArray.map(m => `
                            <div style="background:#fdfdfd; padding:10px; margin:8px 0; border-radius:8px; border-left: 5px solid #3498db; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
                                <strong>${m.name || m.medicineName || 'Unknown Medicine'}</strong> (Qty: ${m.quantity || 0})
                            </div>
                        `).join('')}
                    </div>
                `;
            }
        } catch (e) { console.error(e); }
    }

    setupEventListeners() {
        const logsModal = document.getElementById('logsModal');
        const logsBtn = document.getElementById('logsBtn');
        if (logsBtn && logsModal) {
            logsBtn.onclick = () => logsModal.style.display = 'block';
        }

        document.querySelectorAll('.close').forEach(btn => {
            btn.onclick = (event) => {
                const modal = event.target.closest('.modal');
                if (modal) modal.style.display = 'none';
            };
        });

        const videoEl = document.getElementById('videoStream');
        const startBtn = document.getElementById('startStreamBtn');
        if (startBtn && videoEl) {
            startBtn.addEventListener('click', () => {
                const isStreaming = videoEl.src.includes("stream");
                videoEl.src = isStreaming ? "./images/machine-placeholder.png" : "http://192.168.137.100:81/stream";
                startBtn.innerHTML = isStreaming ? '<i class="fas fa-play"></i> Start Feed' : '<i class="fas fa-stop"></i> Stop Feed';
            });
        }
    }
}

window.addEventListener('DOMContentLoaded', () => {
    window.dashboardApp = new MedicineDispenserDashboard();
});