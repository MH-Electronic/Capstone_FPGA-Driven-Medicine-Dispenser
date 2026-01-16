// static/auth.js

document.addEventListener('DOMContentLoaded', () => {
    const scanButton = document.getElementById('scanButton');
    const statusMessage = document.getElementById('statusMessage');

    if (scanButton) {
        scanButton.addEventListener('click', async () => {
            
            statusMessage.textContent = 'Scanning in progress... Please wait.';
            scanButton.disabled = true;

            try {
                const response = await fetch('/api/scan_id', {
                    method: 'POST', 
                    headers: {'Content-Type': 'application/json'}
                });

                const data = await response.json();
                
                // 1. Check for Admin
                if (data.status === 'admin_success') {
                    statusMessage.textContent = 'Admin detected. Opening Dashboard...';
                    window.location.href = '/monitoring'; 

                // 2. Check for Patient
                } else if (data.status === 'success') {
                    statusMessage.textContent = `Welcome, Patient ${data.patient_id}.`;
                    
                    sessionStorage.setItem('patientId', data.patient_id);
                    sessionStorage.setItem('visitDates', JSON.stringify(data.visit_dates));
                    
                    window.location.href = `/schedule?patient_id=${data.patient_id}`; 

                // 3. Handle Errors
                } else if (data.status === 'error') {
                    const title = data.error_type === 'unregistered' ? 'Registration Required' : 'Data Error';
                    window.location.href = `/status?title=${title}&message=${encodeURIComponent(data.message)}`;

                } else {
                    statusMessage.textContent = 'System Error: Unknown response.';
                }

            } catch (error) {
                console.error('Fetch error:', error);
                statusMessage.textContent = 'Communication Error. Check server connection.';
            } finally {
                scanButton.disabled = false;
            }
        });
    }
});