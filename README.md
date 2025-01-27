##
# *ELFintoBIT*: Scripts to load Microblaze(-V) binary data into a bitstream's BlockRAM

Sadly, with the introduction of the **Microblaze-V** processor in **Vitis 2024.x**, AMD has removed a very useful feature from the ***Program Device*** dialog: The option to integrate an application's code and data into a bitstream's BRAM before downloading it using the *updatemem* tool. It still works for the classic Microblaze, but who knows for how long.

<!--
*(Frankly, this seems insane, given that it is the most straightforward way to get a freshly compiled application started on the FPGA. The way through the debugger, for example, does not work on Zynq systems if one does not also enable the ARM processor. WTF?)*
-->

This repository holds scripts to provide this function for both the classic **Vitis IDE** *(Eclipse-based)* and the **Vitis Unified IDE** *(VS Code/Theia-based)*. They support both the *Microblaze-V* and the legacy *Microblaze* processor.

If you have questions or suggestions, contact me at [r.willenberg@hs-mannheim.de](mailto://r.willenberg@hs-mannheim.de)

## *Tcl* command for classic *Vitis IDE* (Eclipse) ##

[Click here for new Vitis Unified IDE](#python-script-for-vitis-unified-ide-vs-codetheia)

### Installation ###

The ***xsct*** console inside Vitis IDE opens in a default path dependent on the OS, from which you can source a Tcl script directly:  
**Linux:** Copy **ELFintoBIT.tcl** into your home path, e.g. ```/home/thisuser```  
**Windows:** Copy **ELFintoBIT.tcl** into your ```%XILINX_VITIS%/bin``` path, e.g. ```C:/Xilinx/Vitis/2024.2/bin```

### Simple use inside the IDE ###

To use *ELFintoBIT* with an opened workspace in the Vitis IDE 
* open the *Xilinx Software Commandline Tool (XSCT)* console (Click icon or menu *Vitis*->*XSCT Console*) and
* run our Tcl script once to define the **```ELFintoBIT```** Tcl command with
```xsct
   source ELFintoBIT.tcl
```
*(This assumes the script is located in the current work path)*
* In the common case of exactly **one** application project (or one per CPU, in a multi-processor design), just use the command without parameters:

```xsct
   ELFintoBIT
```

By default the generated file **download.bit** is placed next to the imported Vivado bitstream in the application project(s):  
**```WORKSPACE_PATH/APP_PROJECT/_ide/bitstream/download.bit```**

If you want to *download* the generated bitstream instantly to a locally connected FPGA board (like the GUI did), call the command with the **```-d```** switch:
```xsct
   ELFintoBIT -d
```
If you want to download the *last* generated bitstream again *without updating*, use the **```-l```** switch:
```xsct
   ELFintoBIT -l
```

### Tcl command parameters ###

You can add the following parameters to the **```ELFintoBIT```** call:

**```-d```** : Generates *and* downloads the bitstream with ELF(s).

**```-l```** : Downloads the last generated bitstream again.

**```-o OUTPUT_FILE```** : Specifies a different output path and filename for the generated bitstream.

**```-a APP_NAME```** : Explicitly specifies an application in the workspace to integrate into the bitstream. This is required if there are multiple application projects for the same CPU/domain in the workspace.  
In multiprocessor designs, you can use the key multiple times to specify an application for each CPU. You can also restrict only specific CPUs to getting loaded with an app.  
**```ELFintoBIT```** will fail with an error if
* without **-a** switches, it finds multiple applications for the same CPU or applications associated with multiple platforms in the workspace  
* with **-a** switches, multiple applications for the same CPU are specified or applications for different platforms are specified 

**```-w PATH```** : Specifies a workspace directory to use. This is relevant when using the **xsct** console and **ELFintoBIT** outside the Vitis IDE (see below).

### Use outside Vitis IDE ###

For strict command-line / script use, you can
* set the Vitis environment with the appropriated ```settings*sh/*csh/*bat``` script
* start **xsct** with **ELFintoBIT** as 

```bash
   xsct --quiet --interactive ELFintoBIT.tcl
```
*(add the full path to the script if not in the script directory)*

The *xsct* console starts and you can use the **```ELFintoBIT```** command. If you were not already in the right location, specify the intended workspace with **-w**. An example with workspace, apps and download parameters: 
```xsct
   ELFintoBIT -w ~/MYDESIGN -a cpu0app -a cpu1app -d
```

## *Python* script for *Vitis Unified IDE* (VS Code/Theia) ##

### Installation ###



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
