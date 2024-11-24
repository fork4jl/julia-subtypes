import sys
import os
import getopt
from os import path

# Julia installation
julia_bin     = "julia" #"julia-dev --depwarn=no"
julia_version = "v0.6" #"v0.7"

# I live here:
my_path = os.path.dirname(os.path.abspath(__file__))
lj_root = os.path.join(my_path, "../../")
lj_src_path = os.path.join(lj_root, "src")

# Paths to main scripts
process_logs = "process_logs_entry_par.jl"
install_test_deps = os.path.join(lj_root, "src/validation/install_test_deps.jl")

# default prefix of a dir to install deps
pkgs_dir = "pkgs"

# default number of parallel processes
proc_num = 10

# rewrite test-program
prepare_tests = False #True

run_format = "    process_logs.py [-n | -p N] [-s <logged-program> [-b <decls-base>]] <log-file-name>"

def help():
    print(run_format + "\n")
    print("By default, validation runs in parallel mode with 10 procs.\n")
    print("Use the following options to adjust validation:")
    print("[-n]   runs non-parallel log validation; option [-p N] is ignored")
    print("[-p N] runs parallel validation on N processes (N in 1..8)")

def runerror():
    print("Run-error. Use the following format:")
    print(run_format)
    print("Run -h for help.")

def badNerror():
    print("Run-error. Value of '-p' must be an integer in 1..20 (run -h for help)")


if __name__ == '__main__':
    #if len(args) == 0:
    #    usage()
    #    exit(0)
    argc = len(sys.argv)
    if argc == 1:
        runerror()
        exit(2)

    try:
        opts, args = getopt.getopt(sys.argv[1:], "hnp:es:b:")
    except getopt.GetoptError:
        runerror()
        sys.exit(2)

    non_parallel_mode = False # parallel by default

    infer_src_prog = True
    src_prog = ""

    use_provided_decls_dump = False
    decls_dump = ""

    for opt, arg in opts:
        if opt == '-h':
            help()
            exit()
        elif opt == '-n':
            non_parallel_mode = True
        elif opt == '-p':
            try:
                proc_num = int(arg)
            except:
                badNerror()
                exit(2)
            if proc_num < 1 or proc_num > 8:
                badNerror()
                exit(2)
        elif opt == '-s':
            infer_src_prog = False
            src_prog = os.path.abspath(arg)
        elif opt == '-b':
            use_provided_decls_dump = True
            decls_dump = os.path.abspath(arg)

    if len(args) == 0:
        runerror()
        exit(2)

    #log_name = sys.argv[1]
    log_name = args[0]
    log_path = path.abspath(log_name)

    #if argc == 2:
    # run in pkg-mode
    if infer_src_prog:
        # main params
        log_dir = path.dirname(log_path)
        pkg = path.basename(log_dir)
        pkgs_dir = path.join(log_dir, pkgs_dir + "-" + pkg)
            #pkgs_dir + "-" + ("" if parallel_mode else "nonpar-") + pkg)
        #print(pkgs_dir)

        # init Julia pkg cache
        if not path.exists(pkgs_dir):
            curr_cmd = "JULIA_PKGDIR={0} {2} -e 'Pkg.init(); Pkg.add(\"{1}\"); Pkg.add(\"JSON\"); Pkg.add(\"DataStructures\")'".format(pkgs_dir, pkg, julia_bin)
            print("RUN:\n" + curr_cmd)
            os.system(curr_cmd)
            curr_cmd = "JULIA_PKGDIR={0} {2} {1}".format(pkgs_dir, install_test_deps, julia_bin)
            print("RUN:\n" + curr_cmd)
            os.system(curr_cmd)
            prepare_tests = True

        if prepare_tests:
            print("Prepare tests")
            # update test-program
            test_prog_cmd = "'include(\"{0}\")'".format(
                os.path.join("pkgs-"+pkg, julia_version, pkg, "test/runtests.jl")) #pkgs_dir
            print(test_prog_cmd)
            test_fname = "test-" + pkg + ".jl"
            os.system("if [ -f {0}/{1} ]; then rm {0}/{1}; fi".format(log_dir,test_fname))
            os.system("echo {0} > {1}/{2}".format(test_prog_cmd,log_dir,test_fname))

    julia_run_cmd = julia_bin + " -p " + str(proc_num)
    # change run script for non-parallel
    if non_parallel_mode:
        julia_run_cmd = julia_bin
        process_logs = "process_logs_entry.jl"

    julia_pkg_prefix = "cd {0} && ".format(my_path)
    if infer_src_prog:
        julia_pkg_prefix += "JULIA_PKGDIR={0} ".format(pkgs_dir)

    julia_run_cmd = julia_pkg_prefix + julia_run_cmd + " {0} {1}"
    julia_run_cmd = julia_run_cmd.format(process_logs, log_path)

    if not infer_src_prog:
        julia_run_cmd = julia_run_cmd + " {0}".format(src_prog)
        if use_provided_decls_dump:
            julia_run_cmd = julia_run_cmd + " {0}".format(decls_dump)


    # run process_logs_entry*.jl log_name * *
    print("RUN:\n" + julia_run_cmd)
    os.system(julia_run_cmd)


