import os
import subprocess
import vitis
from io import StringIO
import sys
import argparse

def leave_script(lockfilename, oldlockfilename):
    # Reinstate stupid workspace lock
    # if file .oldlock exists, rename it to .lock
    if os.path.isfile(oldlockfilename):
        os.system("mv "+oldlockfilename+" "+lockfilename)
    exit()


print()
print("Starting ELFintoBIT.py ...")
print()

# prepare commandline argument parsing. Can't use -w or -a as they are snatched by Vitis
parser = argparse.ArgumentParser(description="Optional arguments if non-automatic")
parser.add_argument('-sw', '--workpath', type=str, required=False, help='script workspace path')
parser.add_argument('-sa', '--app', type=str, required=False, help='script application name')
parser.add_argument('-so', '--output', type=str, required=False, help='script output path and name')

# parse
args = parser.parse_args()

if args.app is not None:
    a_app = args.app
else:
    a_app = ""  # will use first app found in workspace

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
        os.chdir(WSPATH)
else:
    WSPATH = os.getcwd()


# Remove stupid workspace lock - if file .lock exists, rename it to .oldlock
LOCKPATH = ""
OLDLOCKPATH = ""
# first check for location since 2024.2
if os.path.isfile(WSPATH + "/_ide/.wsdata/.lock"):
    LOCKPATH = WSPATH + "/_ide/.wsdata/.lock"
    OLDLOCKPATH = WSPATH + "/_ide/.wsdata/.oldlock"
    os.system("mv "+LOCKPATH+" "+OLDLOCKPATH)
else:
    # otherwise check for location in 2024.1
    if os.path.isfile(WSPATH + "/.lock"):
        LOCKPATH = WSPATH + "/.lock"
        OLDLOCKPATH = WSPATH + "/.oldlock"
        os.system("mv "+LOCKPATH+" "+OLDLOCKPATH)


# Set Vitis workspace
client = vitis.create_client()
client.set_workspace(path=WSPATH)
print()
print("Workspace path: " + WSPATH)

components = client.list_components()

MB_INSTANCE=""
XSA_PATH=""
BDNAME=""
CURRENT_APPNAME=""
APPNAME=""
CURRENT_PLATFORMNAME=""
PLATFORMNAME=""

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
            if (a_app==""):
                a_app = CURRENT_APPNAME
            if CURRENT_APPNAME == a_app:
                APPNAME = CURRENT_APPNAME
                print("App name      : " + APPNAME)

                # extract platform name
                idx1 = comprepout.find("Platform")
                idx2 = comprepout.find("'", idx1+1)
                idx3 = comprepout.find("'", idx2+1)
                PLATFORM_PATH = comprepout[idx2+1:idx3]
                idx1 = PLATFORM_PATH.rfind(".xpfm")
                idx2 = PLATFORM_PATH.rfind("/")
                PLATFORMNAME = PLATFORM_PATH[idx2+1:idx1]
                print("Platform name : " + PLATFORMNAME)

                # extract CPU instance
                idx1 = comprepout.find("CPU instance")
                idx2 = comprepout.find("'", idx1+1)
                idx3 = comprepout.find("'", idx2+1)
                MB_INSTANCE=comprepout[idx2+1:idx3]
                MB_INSTANCE = ''.join(MB_INSTANCE.split())
                print("MB instance   : " + MB_INSTANCE)

# following functions don't need Vitis client anymore, can be closed
client.close()

# Find XSA file
XSA_DIR = WSPATH+"/"+PLATFORMNAME+"/hw/"
for file in os.listdir(PLATFORMNAME+"/hw/"):
    if file.endswith(".xsa"):
        XSA_PATH = os.path.join(WSPATH+"/"+PLATFORMNAME+"/hw/",file)
        print(XSA_PATH)

if XSA_PATH=="" or not os.path.isfile(XSA_PATH):
    print("ERROR: XSA file " + XSA_PATH + " does not exist.")
    print()
    print("ELFintoBIT.py aborted.")
    print()
    leave_script(LOCKPATH, OLDLOCKPATH)

print("XSA path      : " + XSA_PATH)

# Unzip XSA and extract BD instance, BIT and MMI paths
unzipcall = "unzip -p " + XSA_PATH + " sysdef.xml | grep DEFAULT_BD"
try:
    result = subprocess.check_output(unzipcall, shell=True, text=True)
except subprocess.CalledProcessError as e:
    print("ERROR unzipping XSA file")
    leave_script(LOCKPATH, OLDLOCKPATH)
idx1 = result.find("DESIGN_HIERARCHY=\"")
idx2 = result.find("\"", idx1+18)
BD_INSTANCE=result[idx1+18:idx2]
print("BD instance   : " + BD_INSTANCE) 

unzipcall = "unzip -p " + XSA_PATH + " sysdef.xml | grep BIT"
try:
    result = subprocess.check_output(unzipcall, shell=True, text=True)
except subprocess.CalledProcessError as e:
    print("ERROR unzipping XSA file")
    leave_script(LOCKPATH, OLDLOCKPATH)
idx1 = result.find("Name=\"")
idx2 = result.find("\"", idx1+6)
BITFILE=result[idx1+6:idx2]
print("BIT path      : " + BITFILE)

unzipcall = "unzip -p " + XSA_PATH + " sysdef.xml | grep MMI"
try:
    result = subprocess.check_output(unzipcall, shell=True, text=True)
except subprocess.CalledProcessError as e:
    print("ERROR unzipping XSA file")
    leave_script(LOCKPATH, OLDLOCKPATH)
idx1 = result.find("Name=\"")
idx2 = result.find("\"", idx1+6)
MMIFILE=result[idx1+6:idx2]
print("MMI path      : " + MMIFILE)

print()

MMI  = WSPATH + "/" + APPNAME + "/_ide/bitstream/" + MMIFILE
BIT  = WSPATH + "/" + APPNAME + "/_ide/bitstream/" + BITFILE
ELF  = WSPATH + "/" + APPNAME + "/build/" + APPNAME + ".elf"
PROC = BD_INSTANCE + "/"+ MB_INSTANCE

if a_output != "":
    OUT  = a_output
else:
    OUT  = WSPATH + "/" + APPNAME + "/_ide/bitstream/download.bit"

MISSINGFILES = 0
if not os.path.isfile(MMI):
    print("ERROR: " + MMI + "  does not exist.")
    MISSINGFILES = MISSINGFILES + 1
if not os.path.isfile(BIT):
    print("ERROR: " + BIT + "  does not exist.")
    MISSINGFILES = MISSINGFILES + 1
if not os.path.isfile(ELF):
    print("ERROR: " + ELF + "  does not exist.")
    MISSINGFILES = MISSINGFILES + 1

if MISSINGFILES==0:
    print("Input files available, going ahead...")

    print("updatemem -force -meminfo " + MMI)
    print("                 -bit     " + BIT)
    print("                 -data    " + ELF)
    print("                 -proc    " + PROC)
    print("                 -out     " + OUT)
    umcall = "updatemem -force -meminfo " + MMI + " -bit " + BIT + " -data " + ELF + " -proc " + PROC + " -out " + OUT
    os.system(umcall)
else:
    print()
    print("ELFintoBIT.py aborted.")
    print()
    leave_script(LOCKPATH, OLDLOCKPATH)

print()
print("ELFintoBIT.py finished.")
print()

leave_script(LOCKPATH, OLDLOCKPATH)