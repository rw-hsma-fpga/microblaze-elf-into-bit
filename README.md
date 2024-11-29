##
# *ELFintoBIT*: Scripts to load Microblaze(-V) binary data into a bitstream's BlockRAM

Sadly, with the introduction of the **Microblaze-V** processor in **Vitis 2024.x**, AMD has removed a very useful feature from the ***Program Device*** dialog: The option to integrate an application's code and data into a bitstream's BRAM before downloading it. It still works for the classic Microblaze, but who knows how long.

*(Frankly, this seems insane, given that it is the most straightforward way to get a freshly compiled application started on the FPGA. The way through the debugger, for example, does not work on Zynq systems if one does not also enable the ARM processor. WTF?)*

Here, we are providing scripts to provide this function for both the classic **Vitis IDE** *(Eclipse-based)* and the **Vitis Unified IDE** *(VS Code/Theia-based)*. They support both the *Microblaze-V* and the legacy *Microblaze* processor.

If you have questions or suggestions, contact me at [r.willenberg@hs-mannheim.de](mailto://r.willenberg@hs-mannheim.de)

## *Tcl* script for classic *Vitis IDE* (Eclipse) ##

### Automatic use inside the IDE ###

If you have a *Vitis IDE* workspace with exactly **one** application project, there is a quick way to initialize a bitstream:

* Open the *Xilinx Software Commandline Tool (XSCT)* console (Click icon or menu *Vitis*->*XSCT Console*)
* Start our Tcl script with
```xsct
   source ~/ELFintoBIT.tcl
```

*(This assumes the script is located in the home directory ( ```~/``` ) otherwise adjust to the correct location)*

The resulting file **download.bit** is written to the same place where the original functionality placed it, next to the imported original bitstream in the application project:
```path
   WORKSPACE_PATH/APPLICATION/_ide/bitstream/download.bit
```

### Use with command-line parameters (*.sh* wrapper) ###
Alternatively, our script can be used outside *Vitis* with arguments to specify
* a different Vitis workspace location
* an application, in case there are multiple applications in the workspace
* an output bitstream path and name different from the default (```WORKSPACE_PATH/APPLICATION/_ide/bitstream/download.bit```)

Because *Tcl* scripts can't have arguments in XSCT, we are using a *bash* shell script as a wrapper. Make sure that you have set the *Vitis* tool paths with the corresponding script (e.g. ```XILINX_PATH/Vitis/2024.1/settings.sh```).

Assuming that both the Tcl script **ELFintoBIT.tcl** and the shell wrapper **ELFintoBIT.sh** are located in the home directory ( ```~/``` ), call the script with
```bash
   source ~/ELFintoBIT.sh  -w WORKSPACE_PATH  -a APPLICATION_NAME
```
*(adjust the call appropriately if the scripts are located somewhere else)*

The bash script turns the arguments into environment variables and then launches XSCT with the Tcl script, which can read the environment variables.

If no output path was specified, the resulting bitstream is again located at
```path
   WORKSPACE_PATH/APPLICATION/_ide/bitstream/download.bit
```
It is currently not supported to initialize *multiple* processors with *multiple* applications in the same bitstream.

## *Python* script for *Vitis Unified IDE* (VS Code/Theia) ##

### Automatic use inside the IDE ###

If you have a *Vitis Unified IDE* workspace with exactly **one** application project, there is a quick way to initialize a bitstream:

* Open a new shell terminal with the Vitis menu entry *Terminal*->*New Terminal*)
* Launch a *Vitis* command-line instance that executes our Python script with
```bash
   vitis -s ~/ELFintoBIT.py
```

*(This assumes the Python script is located in the home directory ( ```~/``` ) otherwise adjust to the correct location)*

The resulting file **download.bit** is written to the same place where the original functionality placed it, next to the imported original bitstream in the application project:
```path
   WORKSPACE_PATH/APPLICATION/_ide/bitstream/download.bit
```
### Use with command-line parameters ###

You can specify three types of arguments to the script:
* a Vitis workspace path that is different from the terminals current work directory
* a specific application name if there are multiple applications in your Vitis workspace
* an output path and bitstream name different from the default (```WORKSPACE_PATH/APPLICATION/_ide/bitstream/download.bit```)

When using a terminal not opened inside the **Vitis Unified IDE**, make sure you have set the *Vitis* tool paths with the corresponding script (e.g. ```XILINX_PATH/Vitis/2024.1/settings.sh```).

This is what the command-line call with added parameters looks like:

```bash
   vitis -s ~/ELFintoBIT.py  -sw WORKSPACE_PATH  -sa APPLICATION  -so OUTPUT_BITSTREAM
```

Note that the options keys here are ```-sw``` (script workspace),  ```-sa``` (script application) and ```-so``` (script output) because the shorter ```-w``` and ```-a``` are possible options to the Vitis command-line instance, and would not be handed to the script.

If no output path was specified, the resulting bitstream is again located at
```path
   WORKSPACE_PATH/APPLICATION/_ide/bitstream/download.bit
```
It is currently not supported to initialize *multiple* processors with *multiple* applications in the same bitstream.
