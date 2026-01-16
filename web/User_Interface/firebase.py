# firebase.py

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import json
import time
import re

# =========================================================
# 1. ADMIN SDK INITIALIZATION FOR FIRESTORE
# =========================================================

# Path to the JSON key file (Ensure this path is correct on your Pi)
SERVICE_ACCOUNT_KEY = "/home/capstone/Desktop/capstone/capstone-doctor-interface-firebase-adminsdk-fbsvc-1a0663a6e1.json"

# Initialize Firebase App
cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
firebase_admin.initialize_app(cred)

# Get a reference to the Firestore client
db = firestore.client() 

# =========================================================
# 2. RESTORED UTILITY FUNCTIONS (For project stability)
# =========================================================

def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError (f"Type {type(obj)} not serializable")


def stream_handler(doc_snapshots, patient_id):
    print(f"\n--- Real-time Update Received for Patient {patient_id} ---")
    for doc in doc_snapshots:
        print(f"Visit Date: {doc.id}")
        print(json.dumps(doc.to_dict(), indent=2, default=json_serial)) 
    
    
def stream_patient_visits(patient_id):
    """Listens for real-time changes to Patient's visits (for external use/testing)."""
    print(f"\nListening for real-time changes to Patient {patient_id}'s visits...")
    query_ref = db.collection("consultations").document(patient_id).collection("visits")
    query_ref.on_snapshot(lambda doc_snapshots, changes, read_time: stream_handler(doc_snapshots, patient_id))
    print("Listener started.")


# =========================================================
# 3. CORE PROJECT FUNCTIONS (with stability fixes)
# =========================================================

def read_patient_data(patient_id):
    """
    Reads the patient's static data (name, age, gender) 
    from the main document in the 'consultations' collection.
    """
    doc_ref = db.collection("consultations").document(patient_id)
    doc = doc_ref.get()
    
    if doc.exists:
        data = doc.to_dict()
        print(f"\n--- Reading Static Data for Patient: {patient_id} ---")
        return {
            "patientID": data.get("patientID"),
            "patientName": data.get("patientName"),
            "age": data.get("age"),
            "gender": data.get("gender")
        }
    else:
        print(f"\nNo static patient data found for ID: {patient_id}")
        return None


def get_available_visit_dates(patient_id):
    """Fetches all visit dates (document IDs) for a patient from Firestore."""
    # Path: consultations / [patient_id] / visits
    visits_ref = db.collection("consultations").document(patient_id).collection("visits")
    
    # Get all documents in the 'visits' subcollection
    docs = visits_ref.stream()
    
    # Return a list of the document IDs (which are the visit dates)
    return [doc.id for doc in docs]


def read_visit_data(patient_id, visit_date):
    """
    Reads the specific visit data (including the medications array) 
    from the 'visits' subcollection. Includes stability fix.
    """
    # --- STABILITY FIX: Clean the date string immediately before use ---
    cleaned_visit_date = visit_date.strip()
    
    # Path: consultations / [patient_id] / visits / [cleaned_visit_date]
    doc_ref = (
        db.collection("consultations")
        .document(patient_id)
        .collection("visits")
        .document(cleaned_visit_date)
    )
    doc = doc_ref.get()
    
    if doc.exists:
        print(f"\n--- Reading Visit Data for Patient {patient_id} on {cleaned_visit_date} ---")
        return doc.to_dict() # Returns the data dictionary
    else:
        print(f"\nNo visit data found for Patient {patient_id} on {cleaned_visit_date}")
        return None

def update_dispense_status(patient_id, visit_date):
    try:
        doc_ref = db.collection("consultations").document(patient_id).collection("visits").document(visit_date)
        doc_ref.update({"status": "dispensed"})
        return True
    except Exception as e:
        print(f"Error updating status: {e}")
        return False

def create_dispensing_log(patient_id, visit_date):
    try:
        # Get today's date for the log filename (e.g., 2025-12-31)
        today_str = datetime.now().strftime("%Y-%m-%d")
        
        log_ref = db.collection("logs").document(today_str)
        
        new_entry = {
            "patient_id": patient_id,
            "timestamp": datetime.now().strftime("%H:%M:%S"),
            "source_visit": visit_date
        }

        # ArrayUnion adds the new entry to a list called 'entries' without overwriting old ones
        log_ref.update({
            "entries": firestore.ArrayUnion([new_entry])
        })
        return True
    except Exception as e:
        # If the document doesn't exist yet, .update() fails, so we .set() it
        log_ref.set({"entries": [new_entry]})
        return True


def write_sensor_data(patient_id, value):
    """Logs a dispensing event or sensor reading to the 'device_logs' collection."""
    data = {
        "patientId": patient_id,
        "device": "Dispenser_Unit",
        "log_type": "DISPENSE_EVENT", 
        "value": value,
        "timestamp": datetime.now().isoformat(),
        "location": "Dispenser Bay" 
    }
    
    db.collection("device_logs").add(data)
    print(f"Log written successfully for Patient {patient_id}: {value}!")
    
def update_sensor_status(stock_status):
    """
    Updates the 'status' document in the 'sensor' collection in FIRESTORE.
    Input stock_status: "01000"
    """
    try:
        # 1. Define the sensor keys
        sensor_keys = ['E', 'D', 'C', 'B', 'A']
        
        # 2. Map the string "01000" to a dictionary
        updates = {}
        for i in range(len(sensor_keys)):
            if i < len(stock_status):
                updates[sensor_keys[i]] = int(stock_status[i])

        # 3. Use Firestore syntax (db.collection.document)
        # This will update fields A, B, C, D, E inside the document 'status'
        doc_ref = db.collection("sensor").document("status")
        doc_ref.update(updates)
        
        print(f"[Firestore] IR Stock Status Updated: {updates}")
        return True
    except Exception as e:
        # If the document 'status' doesn't exist yet, .update() will fail.
        # We can use .set(updates, merge=True) to create it if it's missing.
        try:
            db.collection("sensor").document("status").set(updates, merge=True)
            return True
        except Exception as e2:
            print(f"[Firestore Error] IR Sensor update failed: {e2}")
            return False
