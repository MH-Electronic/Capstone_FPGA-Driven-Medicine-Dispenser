// static/prescription.js

document.addEventListener('DOMContentLoaded', () => {
    const dataContainer = document.getElementById('prescriptionData');
    const dispenseButton = document.getElementById('dispenseButton');
    const headerDate = document.getElementById('currentDate');
    
    // Sidebar Elements
    const nameDisp = document.getElementById('patientName');
    const idDisp = document.getElementById('patientID');
    const metaDisp = document.getElementById('patientMeta');

    let currentPatientId = null;
    let currentVisitDate = null;
    
    /**
     * Helper to grab parameters from the URL
     */
    function getUrlParameter(name) {
        const params = new URLSearchParams(window.location.search);
        return params.get(name);
    }
    
    /**
     * Loads the prescription and patient data from the server
     */
    async function loadPrescription() {
        currentPatientId = getUrlParameter('patient_id');
        currentVisitDate = getUrlParameter('visit_date');

        if (!currentPatientId || !currentVisitDate) {
            window.location.href = `/status?title=Error&message=Missing patient or visit details.`;
            return;
        }

        // Update UI with the visit date
        headerDate.textContent = `Visit Date: ${currentVisitDate}`;
        dataContainer.innerHTML = '<p style="padding:20px;">Fetching details from medical records...</p>';
        dispenseButton.disabled = true;

        try {
            const response = await fetch(`/api/get_prescription_details?patient_id=${currentPatientId}&visit_date=${currentVisitDate}`);
            const result = await response.json();
            
            console.log("API Response Data:", result); 

            if (result.status === 'success') {
                // 1. Populate Patient Profile Sidebar
                const info = result.patient_info;
                nameDisp.textContent = info.patientName || "Unknown Patient";
                idDisp.textContent = currentPatientId;
                metaDisp.textContent = `${info.age || '--'} / ${info.gender || '--'}`;

                // 2. Check if medicine was already dispensed
                const visitData = result.data;
                
                if (visitData.status === 'dispensed') {
                    lockDispenseButton("Already Dispensed");
                } else if (visitData.medications && visitData.medications.length > 0) {
                    dispenseButton.disabled = false;
                    dispenseButton.textContent = "Dispense Medicine";
                }

                // 3. Render Medications into the table
                renderMedicationsTable(visitData.medications);

            } else {
                dataContainer.innerHTML = `<p class="warning-text" style="padding:20px;">Error: ${result.message}</p>`;
            }
        } catch (error) {
            console.error('Fetch Error:', error);
            dataContainer.innerHTML = '<p class="warning-text" style="padding:20px;">Network error. Please check server connection.</p>';
        }
    }

    /**
     * Creates the medication table rows
     */
    function renderMedicationsTable(medications) {
        if (!medications || medications.length === 0) {
            dataContainer.innerHTML = '<p style="padding:20px;">No medications listed for this visit.</p>';
            return;
        }

        let tableHTML = '<table><thead><tr><th>Medicine</th><th>Dose</th><th>Freq</th><th>Qty</th></tr></thead><tbody>';
        medications.forEach((med) => {
            tableHTML += `
                <tr>
                    <td><strong>${med.medicineName}</strong></td>
                    <td>${med.dosage}</td>
                    <td>${med.frequency}</td>
                    <td>${med.quantity}</td>
                </tr>
            `;
        });
        tableHTML += '</tbody></table>';
        dataContainer.innerHTML = tableHTML;
    }

    /**
     * Grays out the button if the medicine has already been taken
     */
    function lockDispenseButton(reason) {
        dispenseButton.disabled = true;
        dispenseButton.textContent = reason;
        dispenseButton.style.backgroundColor = "#94a3b8"; // Slate Gray
        dispenseButton.style.color = "#ffffff";
        dispenseButton.style.cursor = "not-allowed";
        
        // Update the confirmation warning box to an information box
        const confirmBox = document.querySelector('.confirmation-box');
        if (confirmBox) {
            confirmBox.style.borderLeftColor = "#94a3b8";
            confirmBox.innerHTML = `
                <div class="confirmation-icon">â„¹ï¸</div>
                <p class="confirmation-text">
                    <strong>RECORD SEALED:</strong><br>
                    This prescription has already been dispensed to the patient.
                </p>
            `;
        }
    }

    /**
     * Handles the Dispense button click
     */
    dispenseButton.addEventListener('click', async () => {
	    if (!confirm("Confirm dispensing medications? This action will update the patient record.")) return;

	    // 1. UI Lockdown
	    dispenseButton.disabled = true;
	    dispenseButton.textContent = "Processing Hardware..."; 
	    
	    try {
		const response = await fetch('/api/dispense', {
		    method: 'POST',
		    headers: {'Content-Type': 'application/json'},
		    body: JSON.stringify({ 
		        patient_id: currentPatientId, 
		        visit_date: currentVisitDate
		    })
		});

		const result = await response.json(); 
		
		if (result.status === 'dispense_success') {
		    const commandString = result.fpga_command; 
		    
		    dispenseButton.textContent = "Finalizing...";
		    await new Promise(resolve => setTimeout(resolve, 1500)); 

		    // Redirect to status with extra params for QR generation
		    const nextUrl = `/status?title=Success` +
				    `&message=${encodeURIComponent(result.message)}` +
				    `&patient_id=${currentPatientId}` +
				    `&visit_date=${currentVisitDate}`;
		    
		    window.location.href = nextUrl;
		}

	    } catch (error) {
		console.error("Dispense Error:", error); 
		window.location.href = `/status?title=Error&message=Connection lost with dispenser.`; 
	    }
	});

    // Initialize the page
    loadPrescription();
});