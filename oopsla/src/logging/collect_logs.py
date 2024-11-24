#
# Run from src with python3
#
from os import system
from multiprocessing import Pool
import os
import sys
import getopt
import subprocess

# Julia installation
julia_bin     = "julia"
julia_version = "v0.6"

# Paths (trivia)
my_path = os.path.dirname(os.path.abspath(__file__))
lj_root = os.path.join(my_path, "../../")
julia_log_bin =  os.path.join(lj_root, "julia-log-062/julia")
uniq = os.path.join(lj_root, "src/logging/filter_uniques.jl")
beats = os.path.join(lj_root, "src/validation/spec-beats-subt.jl")

# Paths (control)
logging_dir = "100pkgs"
logging = os.path.join(lj_root, "logging", logging_dir)
prjs100_fname = "pkgs_list/pkgs_list_ok_100.txt"
pkgs_dir = "pkgs"

# Paths (more trivia)
pkgs_path = os.path.abspath(pkgs_dir)


# Other constants
clean_deps = False
#manage_deps = False #True
proc_num = 4
tmout = 60 * 90 # 90 minutes

prjs10 = [
        "ImageView.jl",
        "MXNet.jl"#, # Mocha
        "ParallelAccelerator.jl", #DSGE
        "DataFrames.jl",
        "PyCall.jl",
        "Interact.jl", # Plots
        "Bio.jl", # Escher
        "Images.jl", # DifferentialEquations
        "Optim.jl", # Optim
        "Gadfly.jl",
        "JuMP.jl",
        "Distributions.jl"
        ]

#prjs = list(set(prjs100) - set(prjs10))

def init_julia_cache(parent_dir, pkgs_path):
    os.system("JULIA_PKGDIR={0} {1} -e 'Pkg.init()'".format(pkgs_path, julia_bin))

def remove_julia_packages(pkgs_path):
    req_path = os.path.join(pkgs_path, julia_version, "REQUIRE")
    os.system("> {0}".format(req_path))
    os.system("JULIA_PKGDIR={0} {1} -e 'Pkg.resolve()'".format(pkgs_path, julia_bin))


def prepare_julia_cache(pkgs_dir, pkg):
    system("JULIA_PKGDIR={0} {2} -e 'Pkg.add(\"{1}\")'".format(pkgs_dir, pkg, julia_bin))

    # Install all test dependencies
    system("JULIA_PKGDIR={0} {2} {1}/../validation/install_test_deps.jl".format(pkgs_dir, my_path, julia_bin))

pkgs_parent_dir = "jl-log-cache"
pkgs_parent_path = os.path.abspath(pkgs_parent_dir)
pkgs_dir_basename = "pkgs"

def get_proc_pkgs_dir_names():
    proc_pkgs_dir  = pkgs_dir_basename + "-" + str(os.getpid())
    proc_pkgs_path = os.path.join(pkgs_parent_path, proc_pkgs_dir)
    return (proc_pkgs_dir, proc_pkgs_path)

def init_pkgs_dir():
    (proc_pkgs_dir, proc_pkgs_path) = get_proc_pkgs_dir_names()
    init_julia_cache(pkgs_parent_dir, proc_pkgs_path)

def clean_pkgs():
    os.system("rm -rf {0}".format(pkgs_parent_dir))

def err(d, s, m):
    system("cd {0} && echo '{1} on {2}' >> error".format(d, s, m))

def task(pr):
    # prepare process-dependent dir
    (proc_pkgs_dir, proc_pkgs_path) = get_proc_pkgs_dir_names()
    remove_julia_packages(proc_pkgs_path)
    prepare_julia_cache(proc_pkgs_path, pr)
    #create a dir
    prdir = "{0}/{1}".format(logging,pr)
    system("if [ -d {0} ]; then rm -rf {0}; fi".format(prdir))
    system("mkdir {0}".format(prdir))

    # loop over two type of programs we log for a project
    for mode in ["add", "test"]:
        #build a command to put in file to run julia-log against
        if mode == "add":
            cmd = "'using {0}'".format(pr)
        elif mode == "test":
            cmd = "'include(\"{0}\")'".format(os.path.join(proc_pkgs_path, julia_version, pr, "test/runtests.jl"))
        #exit()
        # create a file
        cmdfname = "{0}-{1}.jl".format(mode,pr)
        system("if [ -f {0}/{1} ]; then rm {0}/{1}; fi".format(prdir,cmdfname))
        system("echo {0} > {1}/{2}".format(cmd,prdir,cmdfname))

        cmdlog_prefix = "cd {0} && JULIA_PKGDIR={3} {1} {2} 2>".format(
                        prdir, julia_log_bin, cmdfname, proc_pkgs_path)
        # we first have to precompile everything
        cmdlog = cmdlog_prefix + "/dev/null "
        print("precompilation: run {2}-program on {0} with:\n{1}".format(pr, cmdlog, mode))
        try:
            res = subprocess.run(cmdlog, shell=True, executable="/bin/bash", timeout=tmout)
            if res.returncode != 0:
                system("cd {0} && echo 'Return code for log-subprocess: {1}, mode={2}' >> error".format(prdir, res.returncode, mode))
        except:
            err(prdir, "Some error during precompilation", mode)

        # how we run julia-log:
        #julia-log/julia -e 'Pkg.test("JuMP")' 2> >(julia src/filter_uniques.jl)
        #cmdlog = ("cd {0} && " +
        #          "JULIA_PKGDIR={5} {1} {2} 2> >(julia {3} {4}) " # && " +
        #).format(prdir,julia_log_bin, cmdfname, uniq, mode, proc_pkgs_path)
        cmdlog = (cmdlog_prefix +
                  " >({2} {0} {1}) " # && " +
        ).format(uniq, mode, julia_bin)
        print("run {2}-program on {0} with:\n{1}".format(pr, cmdlog, mode))
        #cmdlog1 = "sleep {0}".format(os.getppid() % 3)
        try:
            res = subprocess.run(cmdlog, shell=True, executable="/bin/bash", timeout=tmout)
            if res.returncode != 0:
                system("cd {0} && echo 'Return code for log-subprocess: {1}, mode={2}' >> error".format(prdir, res.returncode, mode))
        except subprocess.TimeoutExpired:
            err(prdir, "Timeout of log-subprocess", mode)
        except Exception as e:
            err(prdir, str(e) + "\n-- from log-subprocess", mode)
        except:
            err(prdir, "Unknown error from log-subprocess", mode)

        # spec-beats-subt
        #beatscmd = "cd {2} && {3} {0} {1}".format(beats, mode, prdir, julia_bin)
        #print("run beats {2}-program on {0} with:\n{1}".format(pr, beatscmd, mode))
        #try:
            #x = 1
        #    subprocess.run(beatscmd, shell=True, executable="/bin/bash", timeout=tmout)
        #except Exception as e:
        #    err(prdir, "Beats:\n" + str(e) + "\n", mode)
        #except:
        #    err(prdir, "Beats, unknown", mode)

    return os.getppid()


def removeExt(fname):
    return os.path.splitext(fname)[0]

def taskFName(fname):
    return task(removeExt(fname))

def usage():
    print("    collect_logs.py [-p N] [-l <cache-dir>] [-d <logs-dir>] [-f <file-name>] [pkg-name]\n")
    print("Usage examples:\n")
    print("(1)  collect_logs.py\n"
          "     runs for a list of packages from \"" + prjs100_fname + "\"\n")
    print("(2)  collect_logs.py <package-name>\n"
          "     runs for a given package\n")
    print("(3)  collect_logs.py -f <file-name>\n"
          "     runs for the list of packages from a given file;\n"
          "     option is ignored if a package name argument is given\n")
    print("By default, log collection runs in the main process for a single package, ")
    print("and uses 5 extra processes if a file name is given.\n")
    print("Use the following options to adjust log collection:")
    print("[-p N]    runs collection on N processes (N in 1..12)")
    print("[-l dir]  uses [dir] as a parent directory for cache folders")
    print("[-d dir]  uses [logging/dir] as a directory for saving logs")

def badNerror():
    print("Run-error. Value of '-p' must be an integer in 1..12 (run -h for help)")


def get100():
    print("Start collecting logs for packages from " + prjs100_fname)
    prjs100_path = os.path.join(my_path, "..", prjs100_fname)
    #print(logging)
    #if manage_deps:
    #    prepare_julia_cache(prjs100_path)
    prjs = open(prjs100_path).read().splitlines()

    pool = Pool(processes=proc_num, initializer=init_pkgs_dir)
    pool.map(taskFName, prjs)

    pool.close()
    pool.join()

def getpkg(pkg_name):
    print("Start collecting logs for a package " + pkg_name)
    #print("LOG: ", logging)
    init_pkgs_dir()
    task(pkg_name)


if __name__ == '__main__':
    if len(sys.argv) == 1:
        get100()
    else:
        try:
            opts, args = getopt.getopt(sys.argv[1:], "hf:p:l:d:")
        except getopt.GetoptError:
            print("Run-error")
            usage()
            sys.exit(2)

        pkgs_parent_dir_changed = False
        logging_dir_changed = False
        
        for opt, arg in opts:
            if opt == '-h':
                usage()
                exit()
            elif opt == '-f':
                prjs100_fname = arg
            elif opt == '-p':
                try:
                    proc_num = int(arg)
                except:
                    badNerror()
                    exit(2)
                if proc_num < 1 or proc_num > 12:
                    badNerror()
                    exit(2)
            elif opt == '-l':
                pkgs_parent_dir = arg  
                pkgs_parent_dir_changed = True
            elif opt == '-d':
                logging_dir = arg
                logging_dir_changed = True
                

        if pkgs_parent_dir_changed:
            pkgs_parent_path = os.path.abspath(pkgs_parent_dir)
        # remove directory with packages' caches
        clean_pkgs()
        # create a clean directory for caches
        os.makedirs(pkgs_parent_dir)
        
        # if we changed logging dir or run logs for a single package,
        # we don't use logging/100pkgs directory
        if logging_dir_changed:
            logging = os.path.join(lj_root, "logging", logging_dir)
        elif len(args) > 0:
            logging = os.path.join(lj_root, "logging", "1pkgs-log")
        # create parent directory for logs if it doesn't exist
        if not os.path.exists(logging):
            os.makedirs(logging)
        
        # run collecting for a list of packages
        if len(args) == 0:
            get100()
        # run collecting for a single package
        else:
            getpkg(args[0])

