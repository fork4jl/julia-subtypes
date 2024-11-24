## [For info] Instructions for Speeding Up Validation

Validation of each package can be done either sequentially or in parallel. Parallel validation is usually faster, but there are several packages that must be validated sequentially. Those are listed in `Lambda-Julia/src/pkgs_list/pkgs-test-suit-seq.txt`.

All the packages listed in `Lambda-Julia/src/pkgs_list/pkgs-test-suit-short.txt` can be validated in parallel mode by running the following commands:

    $ cd ~/julia-subtyping-reconstructed/Lambda-Julia/src
    $ ./run-validate.py -v -t 3 -p 2 -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short.txt
    $ ./run-validate.py -r -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short.txt

The only difference from the instructions given in `README-artifact.md` is a value of the parameter `-p`: here we use 2 processes instead of 1 to validate each logs file.

Remark: to perform fast validation of a list of packages that contains sequential-only packages, do the following:

1) Create a new text file `pkgs-test-suit-short-seq.txt` with sequential-only
   packages you want to validate;
   save it into the folder `Lambda-Julia/src/pkgs_list/`.

2) Create a new text file `pkgs-test-suit-short-par.txt` with all other
   packages you want to validate;
   save it into the folder `Lambda-Julia/src/pkgs_list/`.

3) List all packages you want to validate, including sequential-only ones,
   in the file `Lambda-Julia/src/pkgs_list/pkgs-test-suit-short.txt`.

4) Run the following commands from `Lambda-Julia/src`:

       $ ./run-validate.py -v -t 3 -p 1 -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short-seq.txt
       $ ./run-validate.py -v -t 3 -p 2 -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short-par.txt
       $ ./run-validate.py -r -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short.txt
   
   The first command performs sequential validation of the sequential-only
   packages. The second commands performs parallel validation of all the other
   packages. The last command gathers validation results for all the packages
   listed in `pkgs_list/pkgs-test-suit-short.txt`.

## [For info] Instructions for Fast Validation of 100 Packages

For completeness we provide instructions to run the validation suite over all 100 packages.  We expect this process will take several days/weeks on a VirtualBox VM on commodity hardware, and we do not recommend performing this experiment.  If a reviewer wants to performnthis experiment on a large server machine, we can provide them with a standalone distribution of the artifact.

Running full validation requires some additional information. Validation of each package can be done either sequentially or in parallel.  Parallel validation is usually faster, but there are several packages that must be validated sequentially. Those are listed in `Lambda-Julia/src/pkgs_list/pkgs-test-suit-seq.txt`.

One can use the following commands to run validation of the 100 packages
from `~/julia-subtyping-reconstructed/Lambda-Julia/src`:

    $ ./run-validate.py -v -t 3 -p 3 -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-par.txt
    $ ./run-validate.py -v -t 4 -p 1 -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-seq.txt

* Parameter `-v` means that we want to validate existing logs.
* Parameter `-d` defines a prefix of a folder with logs.
  In this case, logs are in `Lambda-Julia/logging/oopsla-pkgs-logs`.
* Parameter `-t N` controls the size of a pool of python processes used
  for validation of a list of packages.   
* Parameter `-p N` controls the number of Julia processes used for
  validation of a single package. It is equal to 2 by default,
  and should be set to 1 for sequential validation.
* Parameter `-f <file>` is responsible for the file with a list of packages
  that will be processed.

The first command runs parallel validation for the most of the packages. The second command runs sequential validation for the packages that do not support parallel validation.

Once validation is completed, results for all packages can be obtained by running

    $ ./run-validate.py -r -d oopsla-pkgs -f pkgs_list/pkgs-test-suit.txt

This will produce a table similar to the one presented in Appendix B
that can be found in

    ~/julia-subtyping-reconstructed/Lambda-Julia/logging/oopsla-pkgs-logs-copy/validation-res.txt

## [For Info] Instructions to Collect Rules Usage for Validation Results

In order to obtain figures with rules usage for packages in the
`~/julia-subtyping-reconstructed/Lambda-Julia/logging/oopsla-pkgs-logs/`
directory, edit `rule_stat` goal of `~/Makefile`:
replace `oopsla-pkgs-validation-results` with `oopsla-pkgs-logs-copy`.