# RO2 Processor -- Group 2

8-bit PicoBlaze-style processor written in VHDL.
The full assignment spec is in `docs/3_RO2-Aufgabe.pdf`.

## Architecture

```
 ┌────────────┐ inst  ┌───────────────┐ alu_op,regs ┌────────────┐
 │ Instruction│──────▶│  Control Unit │────────────▶│  Datapath  │
 │   Memory   │       │  (decoder +   │             │ (regfile + │
 │   (ROM)    │◀──────│  PC + branch) │◀────────────│    ALU)    │
 └────────────┘  PC   └───────┬───────┘  carry,zero └─────┬──────┘
                              │                      addr, │ ▲ data
                         ctrl │ stall  ┌───────────┐  data │ │
                              │  ┌────▶│  Hazard   │◀──────┘ │
                              │  │     │ Detector  │         │
                              ▼  │     └───────────┘         │
                        ┌────────┴──┐               ┌────────┴───┐
                        │  IO/Mem   │               │ Scratchpad │
                        │ Pipeline  │               │ RAM(256x8) │
                        │ (1c delay)│               └────────────┘
                        └─────┬─────┘
                              │
                        ┌─────┴──────┐
                        │  IO Unit   │
                        │ (256 ports)│
                        └────────────┘
```

**Pipeline:** 2 stages -- Fetch/Decode and Execute/Writeback.
IO and memory control signals are delayed one cycle so they align with execute-stage data.

### Key features

- **16 general-purpose registers** (s0--sF), 8 bits each
- **18-bit instruction word** -- 6-bit opcode, 4-bit register address, 8-bit immediate/source
- **12-bit program counter** -- 4096-address instruction space
- **RAW hazard detection** -- combinational comparator stalls the pipeline when the execute stage writes a register that the decode stage needs to read
- **Branch flush** -- taken jumps flush the in-flight decode instruction (no delay slot)
- **IO unit** -- 256 input + 256 output ports, directly addressed by INPUT/OUTPUT instructions
- **Scratchpad RAM** -- 256 x 8-bit, synchronous write, asynchronous read (STORE/FETCH instructions)
- **ALU operations** -- ADD, ADDCY, SUB, SUBCY, AND, OR, XOR, TEST, TESTCY, shifts (SL0/SL1/SLA/SLX, SR0/SR1/SRA/SRX), rotates (RL/RR), COMPARE, COMPARECY, LOAD

## Project structure

```
src/
├── cpu.vhd                    Top-level CPU
├── types.vhd                  Core types (ro2_word, ro2_address, ...)
├── pkg/io_types_pkg.vhd       IO port array type
├── ControlUnit/               Decoder, PC, branch logic, control_unit wrapper
├── DataPath/                  ALU, register file, datapath pipeline
├── HazardDetection/           RAW hazard detector
├── IO_Unit/                   256-port IO bridge
└── MemoryUnit/                Instruction ROM + scratchpad RAM

sim/
├── cpu_tb.vhd                 Fibonacci integration test
├── cpu_instruction_tb.vhd     Per-instruction coverage (NOP, TEST, JC, JZ, INPUT, OUTPUT, STORE, FETCH)
├── cpu_pipeline_tb.vhd        Back-to-back stalls, stall+branch, reset recovery
├── cpu_stall_tb.vhd           Far jump + real RAW hazard
├── cpu_addcy_zero_tb.vhd      ADDCY zero flag chaining (z_i=1 vs z_i=0)
├── cpu_flush_tb.vhd           No-delay-slot verification
├── cpu_stress_tb.vhd          Cold start, Fibonacci, reset mid-execution, input noise
├── cpu_wrapper_tb.vhd         Minimal waveform-analysis wrapper
├── ControlUnit/               Unit tests for decoder, PC, branch logic, control_unit
├── DataPath/                  ALU, regfile, datapath, datapath flush tests
├── HazardDetection/           Hazard detector edge cases
├── IO_Unit/                   IO read/write sweep, isolation, boundary, simultaneous access
└── MemoryUnit/                Scratchpad RAM read/write, write protection, debug port

docs/                          Typst documentation + architecture diagrams
tests/                       System test (C#)
```

## Getting started (Vivado)

1. Open Vivado
2. Open the Tcl Console (bottom left)
3. `cd` to the project directory
4. Run `source project.tcl` -- creates the project, adds all sources and simulation files

## Running tests

Each testbench uses a VHDL configuration to bind a custom `InstructionMemory` architecture (test-specific ROM program) into the CPU. Run any `*_tb` entity or its `*_cfg` configuration in the simulator.
