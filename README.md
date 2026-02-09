# Parallel Dijkstra Algorithm on FPGA (PicoBlaze)

This project implements a parallel **Dijkstra's Shortest Path Algorithm** on an FPGA using a **Master-Slave PicoBlaze** architecture. Designed for **EHB 326E - Introduction to Embedded Systems**.

## Key Features
* **Parallel Processing:** Utilizes 1 Master and 2 Slave PicoBlaze processors to compute shortest paths concurrently.
* **Architecture:** * **Master:** Manages synchronization, distributes workload, and collects results.
  * **Slaves:** Perform independent pathfinding calculations on a 10x10 adjacency matrix.
* **Language:**  **PicoBlaze Assembly (KCPSM6)** and **Verilog**.
* **Performance:** Reduces computation time significantly compared to a single-core implementation.

## Repository Structure
* `assembly_codes/`: Assembly source codes (`.psm`) for Master and Slave processors.
* `docs/`: Detailed project report and architectural diagrams.

## Documentation
For details on the master-slave handshake protocol and instruction flow, please refer to the [Project Report](docs/EHB326E-Final Proje Raporu.pdf).

---
*Developed by Faruk Onar, Hasan Emre Aydemir, and Ozan İnal.*
