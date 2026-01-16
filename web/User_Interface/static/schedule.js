// static/schedule.js

document.addEventListener('DOMContentLoaded', () => {
    const dateOptionsContainer = document.getElementById('dateOptions');
    
    function getUrlParameter(name) {
        const params = new URLSearchParams(window.location.search);
        return params.get(name);
    }

    const patientId = getUrlParameter('patient_id');

    if (!patientId) {
        window.location.href = `/status?title=Error&message=Missing Patient ID. Please rescan.`;
        return; 
    }

    // Retrieve Visit Dates stored in Session Storage during the initial scan
    const datesJson = sessionStorage.getItem('visitDates');
    
    if (!datesJson) {
        window.location.href = `/status?title=Error&message=Session expired. Please rescan your card.`;
        return;
    }
    
    let visitDates;
    try {
        visitDates = JSON.parse(datesJson);
    } catch (e) {
        window.location.href = `/status?title=Error&message=Data error. Please rescan.`;
        return;
    }
    
    dateOptionsContainer.innerHTML = ''; 

    if (!visitDates || visitDates.length === 0) {
        dateOptionsContainer.innerHTML = '<p style="color: var(--text-secondary);">No prescriptions found for this patient.</p>';
    } else {
        visitDates.forEach(dateString => {
            const dateButton = document.createElement('button');
            dateButton.className = 'date-button'; // Matches the new CSS
            
            // Format date for display (e.g., "October 24, 2025")
            const displayDate = new Date(dateString).toLocaleDateString('en-US', { 
                 year: 'numeric', month: 'long', day: 'numeric' 
            });
            
            dateButton.textContent = displayDate;
            
            dateButton.addEventListener('click', () => {
                // Pass selection to the prescription details page
                window.location.href = `/prescription?patient_id=${patientId}&visit_date=${dateString}`;
            });

            dateOptionsContainer.appendChild(dateButton);
        });
    }
});