# Asynchronous FIFO Verification using SystemVerilog

## Overview

This project implements and verifies an Asynchronous FIFO (First-In, First-Out) using Verilog/SystemVerilog and AMD Vivado XSim.

An asynchronous FIFO allows data to be written and read using independent clock domains. This project focuses on verifying FIFO functionality, data integrity, FIFO ordering, and behavior under full and empty conditions.

## Design Specifications

- **Data Width:** 8 bits
- **Address Width:** 4 bits
- **FIFO Depth:** 16 entries
- **Write Clock:** 10 ns period
- **Read Clock:** 14 ns period
- **Reset:** Active-low asynchronous reset
- **Simulator:** AMD Vivado XSim

## Design Features

- Independent write and read clock domains
- Binary read and write pointers
- Gray-code pointer conversion
- Two-stage pointer synchronization between clock domains
- FIFO full and empty flag generation
- Data storage using memory array
- First-Word-Fall-Through (FWFT) read behavior

## Verification Environment

The FIFO was verified using a self-checking SystemVerilog testbench.

Verification features include:

- Scoreboard-based data comparison
- Data integrity checking
- FIFO ordering verification
- Error counting
- Overflow and underflow attempt tracking
- Random data generation
- Reset verification

## Test Scenarios

The following nine test scenarios were executed:

- **T1 – Reset Verification:** PASS
- **T2 – Basic Write and Read Operations:** PASS
- **T3 – Back-to-Back Writes and Reads:** PASS
- **T4 – FIFO Full Condition:** PASS
- **T5 – Overflow Protection:** PASS
- **T6 – FIFO Ordering Verification:** PASS
- **T7 – Underflow Protection:** PASS
- **T8 – Random Data Testing:** PASS
- **T9 – Reset During Operation:** PASS

## Simulation Results

The simulation produced the following results:

- **Accepted Writes:** 45
- **Accepted Reads:** 42
- **Overflow Attempts:** 5
- **Underflow Attempts:** 5
- **Total Errors:** 0
- **Pending Data at End:** 0

Three accepted entries were discarded by the reset during the reset-in-operation test, explaining the difference between accepted writes and reads.

### Final Status

**TEST PASSED — 0 Errors**

## Tools Used

- Verilog
- SystemVerilog
- AMD Vivado
- Vivado XSim
- Waveform Analysis

## How to Run the Simulation

1. Clone or download this repository.
2. Open AMD Vivado.
3. Create a project and add `design.sv` under Design Sources.
4. Add `testbench.sv` under Simulation Sources.
5. Set `tb_top` as the simulation top module.
6. Launch Behavioral Simulation.
7. The simulator initially runs for 1000 ns in the current setup.
8. To continue the simulation and complete all test cases, enter the following command in the Vivado Tcl Console:

```tcl
run 10 us
```

9. Check the Tcl Console for the final verification summary.
10. Observe the waveform for clocks, reset, read/write controls, FIFO full/empty flags, and data signals.

## Project Files

- `design.sv` – Asynchronous FIFO RTL implementation
- `testbench.sv` – SystemVerilog verification testbench
- `results/` – Simulation waveform and result screenshots

## Conclusion

The testbench completed all nine verification scenarios successfully with zero reported errors.

This project helped develop practical understanding of asynchronous FIFO architecture, clock-domain synchronization, self-checking testbenches, scoreboard-based checking, and simulation waveform analysis.
