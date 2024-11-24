from os import path, system
from multiprocessing import Pool
import os
import sys
import subprocess
import getopt

# Paths
my_path = path.dirname(os.path.abspath(__file__))
lj_root = path.join(my_path, "../../")
lj_src = path.join(lj_root, "src/")
lj_proc_ent = path.join(lj_src, "validation/process_logs.py")
log_dir = "100pkgs"
root_10pkgs = path.join(lj_root, "logging", log_dir)
prjs100_fname = "pkgs_list_ok_curr.txt"
prjs100_path = os.path.join(my_path, "..", prjs100_fname)

ts_proc_num = 3
proc_num = 4
validation_parallel = True
# remove cache and decls files
clean_cache = False
clean_cache_light = False

prjs = ["ImageView",
        "MXNet"#, # Mocha
        "ParallelAccelerator", #DSGE
        "DataFrames",
        "PyCall",
        "Interact", # Plots
        #"Bio", # Escher
        "Images", # DifferentialEquations
        "Optim", # Optim
        "Gadfly",
        ]

tmout= 60 * 150 # AE

run_format = "    process_logs_bulk.py [-t M] [-n | -p N] [-e] [-b] [-f <file-name>] [-d <dir-name>]"

def help():
    print(run_format + "\n")
    print("Validates logs of pkgs listed in <file-name>, with logs searched in <dir-name>.")

def err(d, s, m):
    system("cd {0} && echo '{1} on {2}' >> error".format(d, s, m))

def badNerror(par = "-p", maxVal = "8"):
    print("Argument-error. Value of '{}' must be an integer in 1..{} (run with -h for help)".format(par, maxVal))

def task(pr):
    prdir = "{}/{}".format(root_10pkgs, pr)
    proc_mode = ("-p " + str(proc_num)) if validation_parallel else "-n"
    
    if not path.isdir(prdir):
        print("No project named {} in the log dir".format(pr))
        return
    
    # clean pkgs and decls
    if clean_cache or clean_cache_light:
        files_to_clean = ["pkgs-"+pr, "add-decls_inferred.json", "test-decls_inferred.json"] if clean_cache else ["pkgs-"+pr]
        for fname in files_to_clean:
            fname_path = path.join(prdir, fname)
            if path.exists(fname_path):
                os.system("rm -rf " + fname_path)
                    
    for mode in ["add", "test"]:
        cmdproc = 'python3 {} {} {}/{}-log_subt.txt'.format(lj_proc_ent, proc_mode, prdir, mode)
        print('run process-logs program on {} with:\n{}'.format(pr, cmdproc))
        try:
            res = subprocess.run(cmdproc, shell=True, executable="/bin/bash"
                , timeout=tmout)
            if res.returncode != 0:
                system("cd {0} && echo 'Return code for log-subprocess: {1}, mode={2}' >> error".format(prdir, res.returncode, mode))
        except subprocess.TimeoutExpired:
            err(prdir, "Timeout of log-subprocess", mode)
        except Exception as e:
            err(prdir, str(e) + "\n-- from log-subprocess", mode)
        except:
            err(prdir, "Unknown error from log-subprocess", mode)

    return 0 #os.getppid()

def removeExt(fname):
    return os.path.splitext(fname)[0]

def taskFName(fname):
    return task(removeExt(fname))

def job():
    pool = Pool(processes=ts_proc_num)
    pool.map(taskFName, prjs)
    pool.close()
    pool.join()

if __name__ == '__main__':

    try:
        opts, args = getopt.getopt(sys.argv[1:], "ht:p:d:f:eb")
    except getopt.GetoptError:
        print("Argument-error.")
        sys.exit(2)
        
    for opt, arg in opts:
        if opt == '-h':
            help()
            exit()
        elif opt == '-f':
            prjs100_fname = arg
            prjs100_path = os.path.join(my_path, "..", prjs100_fname)
        elif opt == '-d':
            log_dir = arg
            root_10pkgs = path.join(lj_root, "logging", log_dir)
        elif opt == '-e':
            clean_cache = True
        elif opt == '-b':
            clean_cache_light = True
        elif opt == '-p':
            try:
                proc_num = int(arg)
            except:
                badNerror("-p", "8")
                exit(2)
            if proc_num < 1 or proc_num > 8:
                badNerror("-p", "8")
                exit(2)
            # if proc_num == 1, we'll run validation sequentially
            if proc_num == 1:
                validation_parallel = False
        elif opt == '-t':
            try:
                ts_proc_num = int(arg)
            except:
                badNerror("-t", "20")
                exit(2)
            if ts_proc_num < 1 or ts_proc_num > 20:
                badNerror("-t", "20")
                exit(2)

    if len(args) > 0:
        prjs = os.listdir(args[0])
        root_10pkgs = path.dirname(args[0])
    else:
        if not os.path.isfile(prjs100_path):
            print("Run-error. File " + prjs100_path + " doesn't exist.")
            exit(1)
        prjs = open(prjs100_path).read().splitlines()

    if not os.path.isdir(root_10pkgs):
        print("Run-error. Log directory " + root_10pkgs + " doesn't exist.")
        exit(1)
    
    job()
