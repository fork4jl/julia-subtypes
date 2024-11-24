#!/usr/bin/python3

################################################################################
## Main entry point for running collection and validation
################################################################################

## ------------------------------ NOTES ------------------------------
## Run from src with python3
## ------------------------------

import os
import sys
import getopt

# Julia installation
julia_bin = "julia"

# --------------------- Paths (trivia)
my_path = os.path.dirname(os.path.abspath(__file__))
lj_root = os.path.join(my_path, "..")
ts_logging = os.path.join(lj_root, "logging")
ts_log_src = os.path.join(lj_root, "src", "logging")
ts_validation = os.path.join(lj_root, "src", "validation")
lj_collect_results = os.path.join(ts_validation, "collect_results.jl")
lj_collect_rules_stats = os.path.join(ts_validation, "collect_rules_stats.jl")

# --------------------- Constants and variables
ts_clean_logs = False
ts_clean_cache = False
# number of processes in the pool to be used for collection/validation
ts_proc_num = 4
# number of processes to be used to validate one log
vl_proc_num = 3
vl_proc_num_provided = False
# default file with the list of packages to process
ts_pkgs_list_file = "pkgs_list/pkgs-test-suit.txt"
# directory for the pkgs' cache
ts_cache_dir = "lj-test-suit-cache"
# directory the pkgs' logs
ts_logs_dir  = "lj-test-suit-logs"



def usage():
    print("    validate_run.py [-p N] [-t N] [-c|-v|-r] [-e] [-b] [-f <file-name>] [-d <dir-prefix>]\n")
    print("Runs collection/validation of packages from the file <file-name> if -f is provided", 
          "(from", ts_pkgs_list_file, "otherwise).")
    print("By default, runs both collection and validation on", ts_proc_num, "processes.\n")
    print("The following options are supported:")
    print("[-p N]  runs validation of every log on N processes (N in 1..8)")
    print("[-t M]  runs validation on M processes (M in 1..20)")
    print("[-c]    runs only collection")
    print("[-v]    runs only validation")
    print("[-r]    runs only collection of results")
    print("[-e]    cleans log directory before collection/removes cache and decls before validation")
    print("[-b]    removes cache before validation")

def badNerror(par = "-p", maxVal = "8"):
    print("Argument-error. Value of '{}' must be an integer in 1..{} (run with -h for help)".format(par, maxVal))

def removeExt(fname):
    return os.path.splitext(fname)[0]


if __name__ == '__main__':

    run_collection = True
    run_validation = True

    try:
        opts, args = getopt.getopt(sys.argv[1:], "hf:cvrebp:t:d:")
    except getopt.GetoptError:
        print("Argument-error. Run with -h for help.")
        sys.exit(2)
        
    for opt, arg in opts:
        if opt == '-h':
            usage()
            exit()
        elif opt == '-f':
            ts_pkgs_list_file = arg
        elif opt == '-d':
            ts_logs_dir  = arg + "-logs"
            ts_cache_dir = arg + "-cache"
        elif opt == '-c':
            run_validation = False
        elif opt == '-v':
            run_collection = False
        elif opt == '-r':
            run_collection = False
            run_validation = False
        elif opt == '-e':
            ts_clean_logs = True
        elif opt == '-b':
            ts_clean_cache = True
        elif opt == '-p':
            try:
                vl_proc_num = int(arg)
                vl_proc_num_provided = True
            except:
                badNerror("-p", "8")
                exit(2)
            if vl_proc_num < 1 or vl_proc_num > 8:
                badNerror("-p", "8")
                exit(2)
        elif opt == '-t':
            try:
                ts_proc_num = int(arg)
            except:
                badNerror("-t", "20")
                exit(2)
            if ts_proc_num < 1 or ts_proc_num > 20:
                badNerror("-t", "20")
                exit(2)

    # first, check that the file exists
    if not os.path.isfile(ts_pkgs_list_file):
        print("Run-error. File " + ts_pkgs_list_file + " doesn't exist.")
        exit(1)
        
    # ----------------------------- Collection
        
    if not run_collection:
        print("TS-INFO: collection is skipped by request")
    else:
        if ts_clean_logs:
            ts_logs_path = os.path.join(ts_logging, ts_logs_dir)
            print("TS_INFO: clean logs directory (" + ts_logs_path + ")")
            os.system("rm -rf " + ts_logs_path)
        cmd_collect = "python3 {4}/collect_logs.py -p {0} -l {1} -d {2} -f {3}"
        cmd_collect = cmd_collect.format(ts_proc_num, ts_cache_dir, ts_logs_dir, ts_pkgs_list_file, ts_log_src)
        print("TS-INFO: run collection with")
        print("         " + cmd_collect)
        rslt = os.system(cmd_collect)
        print("TS-INFO: exit status of collection is", rslt)
        
    # ----------------------------- Validation
    
    if not run_validation:
        print("TS-INFO: validation is skipped by request")
    else:
        if not vl_proc_num_provided:
            # adjust proc_num and pick number of workers per one validation
            if ts_proc_num > 8:
                ts_proc_num = ts_proc_num // 3
                vl_proc_num = 3
            elif ts_proc_num > 3:
                ts_proc_num = ts_proc_num // 2
                vl_proc_num = 2
        # if no collection, but ts_clean_logs, we have to remove cache and decls
        cmd_clean_mode = "-e" if ts_clean_logs and not run_collection else ""
        cmd_clean_cache_mode = "-b" if ts_clean_cache and not run_collection else ""
        cmd_validate = "python3 {5}/process_logs_bulk.py -t {4} -p {0} -d {1} -f {2} {3} {6}"
        cmd_validate = cmd_validate.format(vl_proc_num, ts_logs_dir, ts_pkgs_list_file, cmd_clean_mode, ts_proc_num, ts_validation, cmd_clean_cache_mode)
        print("TS-INFO: run validation with")
        print("         " + cmd_validate)
        rslt = os.system(cmd_validate)
        print("TS-INFO: exit status of validation is", rslt)
        
    # ----------------------------- Collect results
    
    if run_collection and not run_validation:
        exit()
    
    # Our julia-script collect_results.jl works from the directory with logs.
    # Thus, we only want plain logs (without caches)
    
    ts_logs_dir_copy = os.path.join(ts_logging, ts_logs_dir + "-copy")
    ts_logs_dir      = os.path.join(ts_logging, ts_logs_dir)
    os.system("rm -rf " + ts_logs_dir_copy)
    os.makedirs(ts_logs_dir_copy)   
        
    print("TS-INFO: collect results of validation...") 
    if not os.path.isdir(ts_logs_dir):
        print("Run-error. Logs directory " + ts_logs_dir + " doesn't exist.")
        exit(1)
    # first, copy results of validation
    prjs = open(ts_pkgs_list_file).read().splitlines()
    for prjfull in prjs:
        prj = removeExt(prjfull)
        prj_src = os.path.join(ts_logs_dir, prj)
        prj_dst = os.path.join(ts_logs_dir_copy, prj)
        os.makedirs(prj_dst)
        for fname in ["add-log_subt", "test-log_subt"]:
            f_src = os.path.join(prj_src, fname)
            f_dst = os.path.join(prj_dst, fname)
            if os.path.exists(f_src):
                os.system("cp -r " + f_src + " " + f_dst)
    # second, run collect_results.jl from the dir
    os.chdir(ts_logs_dir_copy)
    os.system(julia_bin + " " + lj_collect_results + " > validation-res.txt")
    os.system(julia_bin + " " + lj_collect_results + " err > validation-err.txt")
    print("TS-INFO: done. Check " + ts_logs_dir_copy + " directory for results.")
    
    #print("TS-INFO: collect rules stats of validation...") 
    #os.chdir(ts_logs_dir_copy)
    #os.system(julia_bin + " " + lj_collect_rules_stats + " > rules-stats.txt")
    #print("TS-INFO: done. Check validation-rules-stats.txt in logs copy.")

