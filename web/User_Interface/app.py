# app.py

from flask import Flask, render_template, jsonify, request, send_from_directory
import json
import time
import serial
import os

# =======================================================
# ============ Serial Port Setup =======================
# =======================================================
try:
    ser = serial.Serial('/dev/serial0', 115200, timeout=2) 
    ser.reset_input_buffer()
except Exception as e:
    print(f"Serial Port Error: {e}")
    ser = None

# =======================================================
# == FIREBASE INTEGRATION
# =======================================================
try:
    from firebase import (
        db, 
        read_visit_data, 
        read_patient_data,
        create_dispensing_log,
        update_sensor_status,
        get_available_visit_dates 
    )
except ImportError:
    print("FATAL ERROR: Could not import functions from firebase.py.")

app = Flask(__name__)

# =======================================================
# == ADMIN & PATH CONFIGURATION
# =======================================================
ADMIN_HEX_ID = "E2FA4206"
# This points to: capstone/admin_dashboard/website
ADMIN_DASHBOARD_PATH = os.path.join(os.getcwd(), 'admin_dashboard', 'website')
print(f"Checking Dashboard Path: {ADMIN_DASHBOARD_PATH}")
print(f"Does folder exist? {os.path.exists(ADMIN_DASHBOARD_PATH)}")

# Route to serve the Admin Dashboard HTML
@app.route('/monitoring')
def monitoring_page():
    return send_from_directory(ADMIN_DASHBOARD_PATH, 'index.html')

# Route to serve Dashboard Assets (CSS, JS, Images)
@app.route('/monitoring/<path:filename>')
def serve_monitoring_assets(filename):
    return send_from_directory(ADMIN_DASHBOARD_PATH, filename)

# =======================================================
# == UI PAGE ROUTES
# =======================================================

@app.route('/')
def index():
    return render_template('auth.html')

@app.route('/schedule')
def schedule_page():
    patient_id = request.args.get('patient_id')
    if not patient_id:
        return render_template('status.html', status_title="Error", status_message="Patient ID is missing.")
    patient_info = read_patient_data(patient_id) 
    return render_template('schedule.html', patient_id=patient_id, patient_info=patient_info)

@app.route('/prescription')
def prescription_page():
    patient_id = request.args.get('patient_id')
    visit_date = request.args.get('visit_date')
    return render_template('prescription.html', patient_id=patient_id, visit_date=visit_date)
    
@app.route('/status')
def status_page():
    title = request.args.get('title', 'System Status') 
    message = request.args.get('message', 'An unknown action occurred.') 
    
    patient_id = request.args.get('patient_id')
    visit_date = request.args.get('visit_date')
    
    return render_template('status.html', 
                           status_title=title, 
                           status_message=message,
                           patient_id=patient_id,
                           visit_date=visit_date)

# =======================================================
# == API ENDPOINTS
# =======================================================

@app.route('/api/scan_id', methods=['POST'])
def scan_id():
    raw_id = get_id_from_fpga()
    # raw_id = "ACC0176D" ----testing 
    
    if not raw_id:
        if ser: ser.write(b"END\n")
        return jsonify({
            "status": "error", 
            "message": "Hardware Timeout: No card detected.",
            "error_type": "timeout"
        })
        
    # Check for Admin
    if raw_id == ADMIN_HEX_ID:
        return jsonify({
            "status": "admin_success",
            "message": "Admin access granted."
        })
    
    # Check for Patient
    try:
        patient_doc = db.collection("consultations").document(raw_id).get()
        if patient_doc.exists:
            visit_dates = get_available_visit_dates(raw_id)
            if not visit_dates:
                return jsonify({"status": "error", "message": "No valid prescriptions.", "error_type": "no_prescriptions"})
            return jsonify({"status": "success", "patient_id": raw_id, "visit_dates": visit_dates})
        else:
            return jsonify({"status": "error", "message": "ID not registered.", "error_type": "unregistered"})
    except Exception as e:
        return jsonify({"status": "error", "message": f"Scan error: {str(e)}"})

def get_id_from_fpga():
    if ser is None: return None
    try:
        ser.reset_input_buffer()
        ser.write(b"START\n")
        start_time = time.time()
        while (time.time() - start_time) < 10:
            if ser.in_waiting >= 4:
                chunk = ser.read(ser.in_waiting)
                if b"PID:" in chunk:
                    header_pos = chunk.find(b"PID:")
                    remaining_in_chunk = chunk[header_pos+4:]
                    if len(remaining_in_chunk) >= 4:
                        raw_bytes = remaining_in_chunk[:4]
                    else:
                        raw_bytes = remaining_in_chunk + ser.read(4 - len(remaining_in_chunk))
                    return "".join([f"{b:02X}" for b in raw_bytes])
            time.sleep(0.05)
    except Exception as e:
        print(f"Hardware Error: {e}")
    return None
    
@app.route('/api/get_prescription_details', methods=['GET'])
def get_prescription_details():
    """Retrieves both static patient info and specific visit medications."""
    patient_id = request.args.get('patient_id')
    visit_date = request.args.get('visit_date')
    
    if not patient_id or not visit_date:
        return jsonify({"status": "error", "message": "Missing Patient ID or Visit Date."})
    
    try:
        # 1. Fetch static data (Name, Age, Gender) from the main document
        # This calls read_patient_data(patient_id) from your firebase.py
        patient_profile = read_patient_data(patient_id) 
        
        # 2. Fetch specific visit medications from the sub-collection
        # This calls read_visit_data(patient_id, visit_date) from your firebase.py
        prescription_data = read_visit_data(patient_id, visit_date)
        
        if prescription_data and patient_profile:
            # We return both objects so the frontend can display them together
            return jsonify({
                "status": "success",
                "patient_info": patient_profile,  # New key for the sidebar
                "data": prescription_data         # Existing key for the table
            })
        else:
            return jsonify({
                "status": "error", 
                "message": f"Data not found for Patient {patient_id} on {visit_date}."
            })

    except Exception as e:
        print(f"Server Error: {e}")
        return jsonify({"status": "error", "message": "Internal server error fetching details."})


import time
from flask import jsonify, request

@app.route('/api/dispense', methods=['POST'])
def dispense_medicine():
    data = request.get_json()
    patient_id = data.get('patient_id')
    visit_date = data.get('visit_date')
    
    if not patient_id or not visit_date:
        return jsonify({"status": "error", "message": "Missing ID or Date."})

    try:
        # 1. READ prescription data
        prescription_data = read_visit_data(patient_id, visit_date)
        
        if not prescription_data:
            return jsonify({"status": "error", "message": "Prescription not found."})

        # 2. ASSIGNMENT LOGIC (Mapping Names to FPGA Letters)
        counts = {'A': 0, 'B': 0, 'C': 0, 'D': 0, 'E': 0}
        
        mapping = {
            "Paracetamol": "B",
            "Ceterizine": "E",
            "Loperamide": "D",
            "Mefenamic Acid": "C",
            "Bromhexine HCL": "A"
        }

        # 3. CALCULATE QUANTITIES
        medications = prescription_data.get('medications', [])
        for med in medications:
            name = med.get('medicineName')
            qty = int(med.get('quantity', 0))
            
            if name in mapping:
                letter = mapping[name]
                counts[letter] += qty

        # 4. CONSTRUCT FPGA COMMAND STRING
        fpga_command = f"MED:A{counts['A']}B{counts['B']}C{counts['C']}D{counts['D']}E{counts['E']}"
        
        print(f"FINAL FPGA STRING: {fpga_command}")
        print("-------------------------------------------\n")
        
        # =======================================================
        # == UART TRANSMISSION BLOCK ============================
        # =======================================================
        stock_status = None
        
        if ser and ser.is_open:
            try:
                # Clear buffers and give hardware a tiny moment to stabilize
                ser.reset_input_buffer()
                # ser.reset_output_buffer()
                # time.sleep(0.1) 

                # Send command with newline
                full_command = fpga_command + "\n"
                ser.write(full_command.encode('utf-8'))
                print(f"[UART TX] Command Sent: {full_command.strip()}. Waiting for response...")

                # --- Wait for responses ---
                confirmed = False
                start_wait = time.time()
                timeout = 30 

                while (time.time() - start_wait) < timeout:
                    if ser.in_waiting > 0:
                        response = ser.readline().decode('utf-8', errors='replace').strip()
                        print(f"[UART RX] Incoming: {response}")
                        
                        # Handle Explicit FPGA Error
                        if "ERR" in response:
                            return jsonify({"status": "error", "message": "FPGA returned ERR: Command rejected."})

                        # Handle Completion Signal
                        if "DONE" in response:
                            confirmed = True
                            print("[System] Dispense Complete. Requesting Stock Status...")
                            ser.write(b"END\n") # Triggering FPGA to send STK
                        
                        # Handle Stock Data
                        if response.startswith("STK:"):
                            stock_status = response.replace("STK:", "")
                            print(f"[System] Stock Data Captured: {stock_status}")
                            
                    # Exit loop only when we have both confirmation and stock data
                    if confirmed and stock_status:
                        break

                    time.sleep(0.05) # Prevent high CPU usage

                if not confirmed:
                    return jsonify({"status": "error", "message": "Hardware Timeout: 'DONE' not received."})

            except Exception as uart_err:
                return jsonify({"status": "error", "message": f"UART Failure: {uart_err}"})
        else:
            return jsonify({"status": "error", "message": "Serial port disconnected."})
        
        # =======================================================
        # 5. UPDATE DATABASE (Only if UART loop finished successfully)
        
        # Log the Dispensing Event
        try:
            create_dispensing_log(patient_id, visit_date)
        except Exception as log_err:
            print(f"[Error] Dispensing log failed: {log_err}")

        # Update Sensor Status from FPGA Data
        try:
            if stock_status:
                update_sensor_status(stock_status)
                print(f"[System] Sensors updated in DB.")
        except Exception as sensor_err:
            print(f"[Error] Sensor update failed: {sensor_err}")

        # 6. RETURN SUCCESS
        return jsonify({
            "status": "dispense_success", 
            "message": "Medicine dispensed successfully!",
            "fpga_command": fpga_command  
        })

    except Exception as e:
        print(f"Dispensing Error: {e}")
        return jsonify({"status": "error", "message": str(e)})
        
@app.route('/patient_view')
def patient_view():
    """Route for patients to view their prescription after scanning the QR code."""
    patient_id = request.args.get('patient_id')
    visit_date = request.args.get('visit_date')
    
    if not patient_id or not visit_date:
        return "Missing information to load prescription.", 400

    # Use your existing firebase.py functions to get data
    patient_info = read_patient_data(patient_id) 
    prescription_data = read_visit_data(patient_id, visit_date)
    
    if not patient_info or not prescription_data:
        return "Prescription record not found.", 404

    return render_template('patient_view.html', 
                           patient=patient_info, 
                           prescription=prescription_data,
                           visit_date=visit_date)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
