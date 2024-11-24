## `julia-log` low-level interface

There are three tested scenarios for using `julia-log` immediately (not going through nice automated interface of `validation.py`).

1. Log one Julia program of your choice:

        python3 log_program.py <your-program>

    This will create `log_subt.txt` and `log_spec.txt` in current directory with logs for subtype / specificity checks during the execution of your program.

2. Logging a Julia project:

        python3 collect_logs.py <project-name>

    We use two template programs to collect logs from a given project, named
    `add-PROJ` and `test-PROJ`, where `PROJ` is a name of a project. Those programs
    look like this:

    * `using PROJ`
    * `Pkg.test("PROJ")`
    
    Output is written in the current directory, creating subdirectory named `PROJ`.

3. Batch logging of top Julia projects.
    
        python3 collect_logs.py
    
    Some 100 projects to log. [Have to be described in more detail]
    
    Output is written to the `logging/100pkgs` directory.

## `process_logs` low-level interface

`process_logs` is a series of scripts to test `type_validator` against the real
results of the Julia's subtype checks preserved by *julia-log*.

Just call:

    julia process_logs_entry.jl /full/path/to/log/file

or

    julia -p N process_logs_entry_par.jl /full/path/to/log/file

to run validation in parallel on N processes.

And you will get a directory with the results of validation of *julia-ott* as
implemented in *type_validator* against given log file. The directory will have
the same base name and lie along the log file.

### Automation for `process_logs`

There are several python scripts to facilitate processing logs.

1. `process_logs.py` to run validation of a single log file.
2. `process_logs_bulk.py` to run validation of multiple logs.

#### Validation of a single log file

For non-parallel validation, call:

    python3 src/process_logs.py -n path/to/log/file
    
For parallel validation on N processes, call:

    python3 src/process_logs.py -p N path/to/log/file
    
**Note.** Log file should be either add- or test-log of some package, 
with add- or test-programs located in the same folder as the log file.

For validation of log of an arbitrary program, 
use option `-s path/to/logged/program` to point the program being logged.

To use custom declarations base in addition to custom source program,
use option `-b path/to/decls-base`.

#### Validation of multiple logs

It is possible to automatically validate add- and test-logs for 
multiple packages, if packages' logs are within the same directory.

For example, to validate packages' logs from `logging/pkgs-logs`
listed in `src/pkgs_list_ok_100.txt`, call from `src`:

    python3 process_logs_bulk.py [-p N | -n] -f pkgs_list_ok_100.txt -d pkgs-logs

As before, `-n` means non-parallel validation of each log, 
and `-p N` means validation on N processes.

By default, list of packages is taken from `src/pkgs_list_ok_curr.txt`,
and logs are searched in `logging/100pkgs`.

To validate all logs in a given directory, call:

    python3 process_logs_bulk.py [-p N | -n] path/to/logs
    
Use option `-e` to clean and rebuild cache of every package before validation. 
    

