# FPGA-Driven Medicine Dispenser 
### USM Health Unit Digitalization Project

An advanced, hardware-deterministic medication dispensing system designed to bridge the gap between physician consultation and patient treatment through high-speed hardware acceleration and cloud connectivity.

---

## 👥 The Team
* **LIM JIA XIANG**
* **LIEW MING HENG**
* **LUI HON CHEN**
* **MOHAMMAD DARY BIN MOHAMMAD HAIRIE**
* **AIDEE AMIDEE BIN AZLEE**

---

## 📝 Abstract
This project introduces an **FPGA-driven Automated Dispensing System** designed to eliminate pharmacy bottlenecks at the USM Health Unit. By replacing manual retrieval with high-speed hardware acceleration, the system synchronizes physician orders with a physical dispensing unit via a **Cloud-connected Raspberry Pi 4 server**. Key features include **RFID-based patient verification**, real-time **MJPEG video monitoring** for security, and a **delta-update logic** to ensure efficient inventory tracking. Experimental results confirm the system can dispense five common medications within **2 minutes of an order**, significantly reducing human error and patient wait times.



---

## 🚀 System Architecture

The system integrates five primary functional modules into a unified IoT ecosystem:

1. **Doctor Interface (MedPortal):** A web-based application integrated with **Firebase** for instant prescription digitization.
2. **Patient Identification:** An **RC522 RFID** system for secure student matric card verification.
3. **Machine UI:** An interactive dashboard providing patients with prescription details and collection status.
4. **Dispensing Mechanism:** A high-precision **Rack and Pinion** subsystem controlled by a **Lattice CertusPro-NX FPGA**.
5. **Staff Monitoring:** A real-time command center on a **Raspberry Pi 4** providing live logs and **ESP32-CAM** video streams.



---

## ⚠️ Problem Statement
Operations at the USM Health Unit currently rely on manual processes, leading to:
* **Extended Waiting Times:** Heavy congestion at pharmacy counters during peak hours.
* **Technical Gaps:** Absence of an automated link between digital consultation and physical collection.
* **Administrative Burden:** Manual logging increases the risk of human error and staff workload.

## 🎯 Objectives
* To develop a hardware-accelerated dispenser that minimizes patient wait times.
* To enhance the efficiency and accuracy of the USM Health Unit’s post-consultation workflow.

---

## 🛠️ Design Criteria

### 🛡️ Safety & Health
* **Secure Authentication:** RC522 RFID ensures only the correct patient can unlock a specific prescription.
* **Electronic Isolation:** Logic level shifters and relays protect sensitive FPGA/RPi circuitry from high-power motor transients.
* **Mechanical Housing:** Securely enclosed 10mm plywood chassis to prevent injury during actuation.

### 🌿 Environmental Sustainability
* **Low Power:** Utilizes the **Lattice CertusPro-NX FPGA**, optimized for high-performance processing with minimal energy consumption.
* **Modular Design:** Individual rack and pinion gears are replaceable, reducing electronic and mechanical waste.

### 📊 Data Management
* **Network Optimization:** Employs **delta-update logic** for inventory tracking to prevent network congestion.
* **Cloud Integration:** Real-time data synchronization via **Firebase Firestore**.



---

## 📂 Repository Structure
* `/hdl`: Verilog source files (FSM, UART, FIFO, RC522, PWM).
* `/ESP32_CAM`: ESP32-CAM code.
* `/web`: MedPortal frontend and Firebase integration scripts. (Doctor Interface, User Interface & Monitoring Dashboard)

---
*Developed as a Capstone Project for the University Sains Malaysia (USM).*
