# fpga-hdmi

HDMI/DVI transmitter in Verilog for the PYNQ-Z2 (Zynq XC7Z020). Vivado 2025.2 project with XSim testbenches.

## Rebuilding

`HDMI.xpr` was created on the original machine and contains absolute paths under `D:\FPGA\HDMI\`. It also references board constraints at `D:\FPGA\pynq-z2_v1.0.xdc\`, which is outside this repo. Copies of `PYNQ-Z2 v1.0.xdc` and `PYNQ-Z2 v1.0.tcl` are included at the repo root and must be re-added to the project after cloning. The project will not open cleanly from a fresh clone without this.

## Excluded files

`frame.ppm` and `check_frame.py` are excluded via `.gitignore`. `check_frame.py` is currently an empty placeholder.
