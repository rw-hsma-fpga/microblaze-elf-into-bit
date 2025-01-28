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
```console
   source ELFintoBIT.tcl
```
*(This assumes the script is located in the current work path)*
* In the common case of exactly **one** application project (or one per CPU, in a multi-processor design), just use the command without parameters:

```console
   ELFintoBIT
```

By default the generated file **download.bit** is placed next to the imported Vivado bitstream in the application project(s):  
**```WORKSPACE_PATH/APP_PROJECT/_ide/bitstream/download.bit```**

If you want to *download* the generated bitstream instantly to a locally connected FPGA board (like the GUI did), call the command with the **```-d```** switch:
```console
   ELFintoBIT -d
```
If you want to download the *last* generated bitstream again *without updating*, use the **```-l```** switch:
```console
   ELFintoBIT -l
```

### Tcl command parameters ###

You can add the following parameters to the **```ELFintoBIT```** call:

**```-d```** : Generates *and* downloads the bitstream with ELF(s).

**```-l```** : Downloads the last generated bitstream again.

**```-o OUTPUT_FILE```** : Specifies a different output path and filename for the generated bitstream.

**```-a APP_NAME```** : Explicitly specifies an application in the workspace to integrate into the bitstream. This is required if there are multiple application projects for the same CPU/domain in the workspace.  
In multiprocessor designs, you can use the key multiple times to specify an application for each CPU. You can also restrict app-loading to only specific CPUs.  
**```ELFintoBIT```** will fail with an error if  
* without **-a** switches, it finds multiple applications for the same CPU or applications associated with multiple platforms in the workspace *OR* 
* with **-a** switches, multiple applications for the same CPU are specified or applications for different platforms are specified 

**```-w PATH```** : Specifies a workspace directory to use. This is useful when using the **xsct** console and **ELFintoBIT** outside the Vitis IDE (see below).
ATTENTION: Please use forward slashes **```/```** for paths even in **Windows** or *xsct* won't process correctly.

### Use outside Vitis IDE ###

For strict command-line use outside the IDE
* set the Vitis environment with the appropriate ```settings64.*``` script
* start **xsct** with **ELFintoBIT** as 

```console
   xsct --quiet --interactive SCRIPT_DIR/ELFintoBIT.tcl
```
*(use the full path to the script if not in its directory)*

The *xsct* console starts and you can use the **```ELFintoBIT```** command. If you are not already in the intended workspace path, specify it with **-w**. An example with workspace, apps and download parameters: 
```console
   ELFintoBIT -w C:/MYDESIGN -a cpu0app -a cpu1app -o ~/2MBs.bit -d
```
ATTENTION: Please use forward slashes **```/```** for paths even in **Windows** or *xsct* won't process correctly.

## *Python* script for *Vitis Unified IDE* (VS Code/Theia) ##

### Installation ###

The easiest way to execute our script for the Vitis Python API is through an OS-specific wrapper. That's because executable *Linux bash* and *Windows batch* scripts can be found through the systems **```PATH```** variable. Since we need Vitis environment variables anyway, the installation path of Vitis binaries is a good destination.  
**Linux:** Copy **ELFintoBIT.sh** and **ELFintoBIT.py** into ```$XILINX_VITIS/bin```    
(Make sure the shell script is executable)  
**Windows:** Copy **ELFintoBIT.bat** and **ELFintoBIT.py** into ```$XILINX_VITIS/bin```  

### Simple use inside the Unified IDE ###

To use *ELFintoBIT* with an opened workspace in the *Vitis Unified IDE*, another commandline instance of Vitis has to be called to execute our Python script:

* Open a new shell terminal with the Vitis menu entry *Terminal*->*New Terminal*)
* In the common case of exactly **one** application project (or one per CPU, in a multi-processor design), call the appropriate OS wrapper script without parameters:
```console
   ELFintoBIT.sh
```
```console
   ELFintoBIT.bat
```

**NOTE:** **In Windows, the Unified IDE sometimes creates a workspace lock that the script can't remove.** *In this case, you'll get a message asking you to kill the task named ***OpenJDK*** in the Windows Task Manager; doing this doesn't break anything else, and enables lock override.*

By default the generated file **download.bit** is placed next to the imported Vivado bitstream in the application project(s):  
**```WORKSPACE_PATH/APP_PROJECT/_ide/bitstream/download.bit```**

If you want to *download* the generated bitstream instantly to a locally connected FPGA board (like the GUI did), call the command with the **```-sd```** switch:
```console
   ELFintoBIT.sh  -sd
   ELFintoBIT.bat  -sd
```
If you want to download the *last* generated bitstream again *without updating*, use the **```-sl```** switch:
```console
   ELFintoBIT.sh  -sl
   ELFintoBIT.bat  -sl
```
### Script command parameters ###

You can add the following parameters to the **```ELFintoBIT.sh/.bat```** call (all switches have two letters starting with **```s```** so Vitis or Python don't grab them):

**```-sd```** : Generates *and* downloads the bitstream with ELF(s).

**```-sl```** : Downloads the last generated bitstream again.

**```-so OUTPUT_FILE```** : Specifies a different output path and filename for the generated bitstream.

**```-sa APP_NAME```** : Explicitly specifies an application in the workspace to integrate into the bitstream. This is required if there are multiple application projects for the same CPU/domain in the workspace.  
In multiprocessor designs, you can use the key multiple times to specify an application for each CPU. You can also restrict app-loading to only specific CPUs.  
**```ELFintoBIT```** will fail with an error if  
* without **-sa** switches, it finds multiple applications for the same CPU or applications associated with multiple platforms in the workspace *OR* 
* with **-sa** switches, multiple applications for the same CPU are specified or applications for different platforms are specified 

**```-sw PATH```** : Specifies a workspace directory to use. This is useful when the console you're calling from is not in the workspace directory, for example if you opened it outside the IDE (see below).

An example Linux call with multiple parameters might look like this:

```console
   ELFintoBIT.sh -sw ~/MYDESIGN -sa cpu0app -sa cpu1app -so ~/2MBs.bit -sd
```

### Use outside the Unified IDE ###

You can use our scripts in a console outside the Unified IDE, as long as you set the Vitis environment with the appropriate ```settings64.*``` script. Especially in this case, the **```-sw```** switch to target the workspace might be useful

### Calling the Python script directly without wrappers ###

**ELFintoBIT.py** can be called without bash/batch wrapper scripts on the commandline in two ways:

1. Call Vitis with the **```-s```** switch to execute the script once and leave again:
```console
   vitis  -s  SCRIPT_PATH/ELFintoBIT.py  [OTHER_PARAMETERS]
```

2. Call Vitis to start the Python interactive console, and then run the script:
```console
   vitis  -i
   
   Vitis [1]:  run  SCRIPT_PATH/ELFintoBIT.py  [OTHER_PARAMETERS]
```

In both cases, the Vitis environment must be set, either by opening the terminal inside Vitis Unified IDE, or by calling the appropriate ```settings64.*``` script.

The parameters **```-sd```**, **```-sl```**, **```-sa```**, **```-so```** and **```-sw```** can be used the same way.

If you do not want to specify the full path to the script each time, you can set the environment variables ```%PYTHONPATH%``` resp. ```$PYTHONPATH``` to the scripts path and the run the script as a module
```console
   vitis  -s  -m  ELFintoBIT.py  [OTHER_PARAMETERS]
```
or
```console
   vitis  -i
   
   Vitis [1]:  run  -m  ELFintoBIT.py  [OTHER_PARAMETERS]
```
Vitis falsely complains about the **```-m```** switch but hands it through to Python anyway.
