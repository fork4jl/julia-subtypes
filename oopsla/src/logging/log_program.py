#
# Log given julia program (run on pyhton3)
#
from os import system
from multiprocessing import Pool
import os
import sys
import subprocess

# Julia installation
julia_bin = "julia"

lj_root = os.path.dirname(os.path.abspath(__file__)) + "/../../"
julia_log_bin =  lj_root + "julia-log-060/julia"
uniq = lj_root + "src/logging/filter_uniques.jl"

tmout = 60 * 15 # 15 minutes

def err(s):
    print(s)

def task(fname):
    # how we run julia-log:
    #julia-log/julia program.jl 2> >(julia src/filter_uniques.jl)
    cmdlog = ("{1} {2} 2> >( {4} {3} )" #
    ).format("dummy",julia_log_bin, fname, uniq, julia_bin)
    #print("run program with:\n{0}".format(cmdlog))
    try:
        res = subprocess.run(cmdlog, shell=True, executable="/bin/bash", timeout=tmout)
        if res.returncode != 0:
            system("echo 'Return code for log-subprocess: {0}' >> error".format(res.returncode))
    except subprocess.TimeoutExpired:
        err("Timeout of log-subprocess")
    except Exception as e:
        err(str(e) + "\n-- from log-subprocess")
    except:
        err("Unknown error from log-subprocess")

    return os.getppid()

if __name__ == '__main__':
    if len(sys.argv) == 2:
        task(sys.argv[1])
    else:
        print("Usage: `log.py <file with julia-program to run>`. Quit")

