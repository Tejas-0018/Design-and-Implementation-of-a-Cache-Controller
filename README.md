# Design-and-Implementation-of-a-Cache-Controller

Project Overview

The project focuses on the design and implementation of an FSM-based cache controller to bridge the significant speed gap between a fast CPU and slower main memory. Cache memory functions as a critical intermediate storage layer that reduces average memory access time and improves overall system performance. 


System Architecture and Logic

The system acts as an intermediate layer comprising an address decoding unit, direct-mapped cache memory, and the FSM-based cache controller. To maintain data consistency and minimize memory access latency, the architecture employs a write-back and write-allocate policy. The Finite State Machine manages the communication between the CPU and memory through specific operational states: Idle, Tag Comparison, Read/Write Hit, Miss Handling, Write-Back, and Allocate/Refill. For instance, during a write miss, the controller allocates the required block from main memory into the cache before performing the write operation, and if a dirty block is replaced, it is safely written back to main memory.


Hardware Implementation

The cache controller and memory management unit are implemented using Verilog HDL. The hardware complexity is deliberately minimized by utilizing a direct mapping approach with a single tag comparator and separating the tag and data arrays, making the design highly suitable for FPGA and embedded implementations. The memory addressing is structured for a 16-bit CPU address, which is decoded into a 9-bit tag, a 3-bit index to select one of eight cache lines, and a 4-bit offset. Each cache line is designed to store a 128-bit data block alongside its tag, a valid bit, and a dirty bit.


Performance and Conclusion

Simulation results obtained via Modelsim validate the correct functionality of the cache controller across various memory access scenarios, including cache hits, compulsory misses, conflict misses, and write-back operations. The use of an FSM ensures deterministic behavior, correct timing synchronization with main memory latency, and simplified verification. Ultimately, the parameterized design provides a scalable, reusable, and efficient memory management solution that can be easily adapted to different processor architectures and embedded systems by simply adjusting the design parameters.
