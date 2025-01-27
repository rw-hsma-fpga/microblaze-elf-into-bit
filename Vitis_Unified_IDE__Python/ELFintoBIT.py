import os
import platform
import subprocess
import vitis
from io import StringIO
import sys
from sys import exit
import argparse


# Finish function
def leave_script(lockfilename, oldlockfilename, abort=False):
    # Reinstate stupid workspace lock
    # if file .oldlock exists, rename it to .lock
    if os.path.isfile(oldlockfilename):
        os.system("mv "+oldlockfilename+" "+lockfilename)
        
    if abort:
        print()
        print("ELFintoBIT.py aborted.")
        print()
    else:
        print()
        print("ELFintoBIT.py finished.")
        print()

    exit()

# FPGA download function (calling xsct)
def download_to_FPGA(bitstream):
    # change any backslashes to forward slashes
    bitstream = bitstream.replace("\\", "/")
    print()
    print("Attempting to download bitstream to FPGA...")
    # Using "deprecated" xsct tool until AMD gets off their asses
    # and offers this through the Vitis Python API (and documents it)
    xsct_call = "xsct -quiet -eval \"connect ; set result [ catch { fpga " + bitstream + " } msg ] ; puts \\$msg ; if { \\$result == 1 } { puts \\\"FPGA download failed.\\\" } \""
    os.system(xsct_call)


#### START ####

print()
print("Starting ELFintoBIT.py ...")
print()

# Check/save OS, fix missing GNUWIN path on Vitis Windows
Windows = (platform.system() == "Windows")
if Windows:
    if os.environ["PATH"].find("gnuwin/bin") == -1 and os.environ["PATH"].find("gnuwin\\bin") == -1:
        os.environ["PATH"]=os.environ["PATH"] + ";" + os.environ["XILINX_VITIS"] + "/gnuwin/bin"


#### PROCESS ARGUMENTS ####

# prepare commandline argument parsing. Can't use -w or -a as they are snatched by Vitis
parser = argparse.ArgumentParser(description="Optional arguments if non-automatic")
parser.add_argument('-sw', '--workpath', type=str, required=False, help='script workspace path')
# -sa argument can be specified multiple times
parser.add_argument('-sa', '--app', type=str, required=False, action='append', help='script application name')
parser.add_argument('-so', '--output', type=str, required=False, help='script output path and name')
parser.add_argument('-sd', '--download', action='store_true', help='download bitstream to FPGA')
parser.add_argument('-sl', '--download_last', action='store_true', help='download existing integrated bitstream to FPGA')

args = parser.parse_args()

Download = args.download
DownloadOnly = args.download_last

if Download and DownloadOnly:
    print("ERROR: Conflicting arguments -sl and -sd.")
    print("       Can't both download the last bitstream and generate and download a new one.")
    exit()

if args.app is not None:
    a_apps = args.app
    no_apps_specified = False
else:
    # Set a_apps to empty list of strings
    a_apps = []
    no_apps_specified = True

if args.output is not None:
    a_output = args.output
    a_output_dir = os.path.dirname(a_output)
    if not os.access(a_output_dir, os.W_OK):
        print("ERROR: Specified output file is not writable.")
        exit()
else:
    a_output = ""  # will use default output name

# if workspace argument is empty, use current directory
if args.workpath is not None:
    a_workspace = args.workpath
    # check if workspace exists
    if not os.path.isdir(a_workspace):
        print("ERROR: Specified workspace path does not exist.")
        exit()
    else:
        WSPATH = a_workspace
        WSPATH = os.path.abspath(WSPATH)
        os.chdir(WSPATH)
else:
    WSPATH = os.getcwd()

print()
print("Workspace path: " + WSPATH)
print()

# If requested, only download last generated bitstream and leave
if DownloadOnly:
    # read string OUT from file .last_download
    with open(WSPATH+"/.last_ELFed_BIT", "r") as f:
        last_bitstream = f.read()
    if last_bitstream == "":
        print("ERROR: No last generated bitstream with ELFs found.")
        leave_script("", "", abort=True)
    # if file last_bitstream does not exist, abort
    if not os.path.isfile(last_bitstream):
        print("ERROR: Bitstream " + last_bitstream + " does not exist.")
        leave_script("", "", abort=True)
    download_to_FPGA(last_bitstream)
    leave_script("", "", abort=False)

# Remove stupid workspace lock - if file .lock exists, rename it to .oldlock
LOCKPATH = ""
OLDLOCKPATH = ""
# first check for location since 2024.2
if os.path.isfile(WSPATH + "/_ide/.wsdata/.lock"):
    LOCKPATH = WSPATH + "/_ide/.wsdata/.lock"
    OLDLOCKPATH = WSPATH + "/_ide/.wsdata/.oldlock"
else:
    # otherwise check for location in 2024.1
    if os.path.isfile(WSPATH + "/.lock"):
        LOCKPATH = WSPATH + "/.lock"
        OLDLOCKPATH = WSPATH + "/.oldlock"

if LOCKPATH != "":
    if Windows:
        os.system("rm -f " + LOCKPATH)
        if os.path.isfile(LOCKPATH):
            print("ERROR: Unable to remove .lock file.")
            print("Please terminate  vitis-ide's OpenJDK  process in Windows Task Manager before restarting script.")
            print("(Blame AMD for this crap.)")
            leave_script(LOCKPATH, OLDLOCKPATH, abort=True)
    else:
        os.system("mv "+LOCKPATH+" "+OLDLOCKPATH)


#### RETRIEVE AND MATCH PROJECT DATA ####

# Set Vitis workspace
client = vitis.create_client()
client_state = False
client_state = client.set_workspace(path=WSPATH)
if not client_state:
    print("ERROR: No valid workspace.")
    leave_script(LOCKPATH, OLDLOCKPATH, abort=True)
components = client.list_components()

XSA_PATH=""
BDNAME=""
CURRENT_APPNAME=""
APPNAMES=[]
PLATFORM_PATH=""
NEW_PLATFORMNAME=""
PLATFORMNAME=""
NEW_MB_INSTANCE=""
MB_INSTANCES=[]

# extract app data from components
for i in components:
    comp = client.get_component(name=i['name'])

    if type(comp)==vitis.component.HostComponent:

        old_stdout = sys.stdout
        sys.stdout = comprep = StringIO()
        comp.report()
        sys.stdout = old_stdout
        comprep.seek(0)
        comprepout = comprep.read();    

        if comprepout.find("'APPLICATION'") == -1 : # not an application, something else
            pass
        else: # -> application
            CURRENT_APPNAME = i['name']
            if (no_apps_specified):
                a_apps.append(CURRENT_APPNAME)
            if CURRENT_APPNAME in a_apps:
                appindex = a_apps.index(CURRENT_APPNAME)
                # Ensure APPNAMES has elements up to appindex
                for i in range(len(APPNAMES), appindex+1):
                    APPNAMES.append(None)
                APPNAMES[appindex] = CURRENT_APPNAME
                print("App name      : " + APPNAMES[appindex])
                # extract platform name
                idx1 = comprepout.find("Platform")
                idx2 = comprepout.find("'", idx1+1)
                idx3 = comprepout.find("'", idx2+1)
                PLATFORM_PATH = comprepout[idx2+1:idx3]
                # remove all spaces and newlines
                PLATFORM_PATH = ''.join(PLATFORM_PATH.split())
                # if ".xpfm" in string, remove ".xpfm"
                idx1 = PLATFORM_PATH.rfind(".xpfm")
                if idx1 != -1:
                    PLATFORM_PATH = PLATFORM_PATH[:idx1]
                idx2 = PLATFORM_PATH.rfind("/")
                if idx2 != -1:
                    PLATFORM_PATH = PLATFORM_PATH[idx2+1:]
                idx2 = PLATFORM_PATH.rfind("\\")
                if idx2 != -1:
                    PLATFORM_PATH = PLATFORM_PATH[idx2+1:]
                NEW_PLATFORMNAME = PLATFORM_PATH
                print("Platform name : " + NEW_PLATFORMNAME)
                if PLATFORMNAME != "" and PLATFORMNAME != NEW_PLATFORMNAME:
                    print("ERROR: Applications belong to different platforms.")
                    client.close()
                    leave_script(LOCKPATH, OLDLOCKPATH, abort=True)
                PLATFORMNAME = NEW_PLATFORMNAME

                # extract CPU instance
                idx1 = comprepout.find("CPU instance")
                idx2 = comprepout.find("'", idx1+1)
                idx3 = comprepout.find("'", idx2+1)
                NEW_MB_INSTANCE=comprepout[idx2+1:idx3]
                NEW_MB_INSTANCE = ''.join(NEW_MB_INSTANCE.split())
                if NEW_MB_INSTANCE in MB_INSTANCES:
                    print("ERROR: Multiple applications using same CPU instance.")
                    client.close()
                    leave_script(LOCKPATH, OLDLOCKPATH, abort=True)
                for i in range(len(MB_INSTANCES), appindex+1):
                    MB_INSTANCES.append(None)
                MB_INSTANCES[appindex] = NEW_MB_INSTANCE
                print("MB instance   : " + MB_INSTANCES[appindex])
                print()

# following functions don't need Vitis client anymore, can be closed
client.close()
print()

# Check if all apps from command-line found
if no_apps_specified==False:
    for clApp in a_apps:
        if clApp not in APPNAMES:
            print("ERROR: Application " + clApp + " not found in workspace.")
            leave_script(LOCKPATH, OLDLOCKPATH, abort=True)

# Find XSA file
XSA_DIR = WSPATH+"/"+PLATFORMNAME+"/hw/"
###print("### "+XSA_DIR+" ###")
for file in os.listdir(XSA_DIR):
    if file.endswith(".xsa"):
        XSA_PATH = os.path.join(WSPATH+"/"+PLATFORMNAME+"/hw/",file)

if XSA_PATH=="" or not os.path.isfile(XSA_PATH):
    print("ERROR: XSA file " + XSA_PATH + " does not exist.")
    print()
    print("ELFintoBIT.py aborted.")
    print()
    leave_script(LOCKPATH, OLDLOCKPATH)

print("XSA path      : " + XSA_PATH)

# Unzip XSA and extract BD instance, BIT and MMI paths
unzipcall = "unzip -p " + XSA_PATH + " sysdef.xml"
try:
    result = subprocess.check_output(unzipcall, shell=True, text=True)
except subprocess.CalledProcessError as e:
    print("ERROR unzipping XSA file")
    leave_script(LOCKPATH, OLDLOCKPATH)
BDline = ""
for line in result.splitlines():
    if "BD_TYPE=\"DEFAULT_BD\"" in line:
        BDline = line
        break
idx1 = BDline.find("DESIGN_HIERARCHY=\"")
idx2 = BDline.find("\"", idx1+18)
BD_INSTANCE=BDline[idx1+18:idx2]
print("BD instance   : " + BD_INSTANCE) 

unzipcall = "unzip -p " + XSA_PATH + " sysdef.xml"
try:
    result = subprocess.check_output(unzipcall, shell=True, text=True)
except subprocess.CalledProcessError as e:
    print("ERROR unzipping XSA file")
    leave_script(LOCKPATH, OLDLOCKPATH)
BITline = ""
for line in result.splitlines():
    if "File Type=\"BIT\"" in line:
        BITline = line
        break
idx1 = BITline.find("Name=\"")
idx2 = BITline.find("\"", idx1+6)
BITFILE=BITline[idx1+6:idx2]
print("BIT path      : " + BITFILE)

unzipcall = "unzip -p " + XSA_PATH + " sysdef.xml"
try:
    result = subprocess.check_output(unzipcall, shell=True, text=True)
except subprocess.CalledProcessError as e:
    print("ERROR unzipping XSA file")
    leave_script(LOCKPATH, OLDLOCKPATH)
MMIline = ""
for line in result.splitlines():
    if "File Type=\"MMI\"" in line:
        MMIline = line
        break
idx1 = MMIline.find("Name=\"")
idx2 = MMIline.find("\"", idx1+6)
MMIFILE=MMIline[idx1+6:idx2]
print("MMI path      : " + MMIFILE)
print()


#### BITSTREAM UPDATES ####

APP_BIT_PATH = "/_ide/bitstream/"

# MMI, unELFed BIT must be the same for all, so just using the first app
MMI  = WSPATH + "/" + APPNAMES[0] + APP_BIT_PATH + MMIFILE
BIT  = WSPATH + "/" + APPNAMES[0] + APP_BIT_PATH + BITFILE
TEMPIN  = WSPATH + "/" + APPNAMES[0] + APP_BIT_PATH + "_etob_in.bit"
TEMPOUT  = WSPATH + "/" + APPNAMES[0] + APP_BIT_PATH + "_etob_out.bit"

# check if input files exist
if not os.path.isfile(MMI):
    print("ERROR: " + MMI + "  does not exist.")
    leave_script(LOCKPATH, OLDLOCKPATH, abort=True)
if not os.path.isfile(BIT):
    print("ERROR: " + BIT + "  does not exist.")
    leave_script(LOCKPATH, OLDLOCKPATH, abort=True)
for i in range(len(APPNAMES)):
    ELF  = WSPATH + "/" + APPNAMES[i] + "/build/" + APPNAMES[i] + ".elf"
    if not os.path.isfile(ELF):
        print("ERROR: " + ELF + "does not exist.")
        leave_script(LOCKPATH, OLDLOCKPATH, abort=True)

# make temporary copy of unELFed bitstream
os.system("cp " + BIT + " " + TEMPIN)

for i in range(len(APPNAMES)):
    ELF  = WSPATH + "/" + APPNAMES[i] + "/build/" + APPNAMES[i] + ".elf"
    PROC = BD_INSTANCE + "/"+ MB_INSTANCES[i]
    print()
    print("Adding App " + APPNAMES[i] + " for CPU " + MB_INSTANCES[i] + " to bitstream...")
    umcall = "updatemem -force -meminfo " + MMI + " -bit " + TEMPIN + " -data " + ELF + " -proc " + PROC + " -out " + TEMPOUT
    os.system(umcall)
    os.system("cp " + TEMPOUT + " " + TEMPIN)

# move to output file and remove temporary files
allouts = []
if a_output != "":
    OUT  = a_output
    os.system("cp " + TEMPOUT + " " + OUT)
    firstout = OUT
    allouts.append(OUT)
else:
    for i in range(len(APPNAMES)): # copy to all app folders
        OUT  = WSPATH + "/" + APPNAMES[i] + APP_BIT_PATH + "download.bit"
        os.system("cp " + TEMPOUT + " " + OUT)
        allouts.append(OUT)
        if i==0:
            firstout = OUT
os.system("rm " + TEMPOUT + " " + TEMPIN)

# list output locations
print()
print("The bitstream was written to the following location(s):")
print("-------------------------------------------------------")
for i in range(len(allouts)):
    print(allouts[i])

# write string OUT into file .last_ELFed_BIT
with open(WSPATH+"/.last_ELFed_BIT", "w") as f:
    f.write(firstout)


#### LOCAL FPGA DOWNLOAD ####
if Download:
    download_to_FPGA(firstout)


#### FINISH ####

# leave cleanly
leave_script(LOCKPATH, OLDLOCKPATH)