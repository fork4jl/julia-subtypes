## Overview

The artifact allows for replication of the following results:

* [TESTS] Results of testing our subtype algorithm against the official Julia 0.6.2 test suit reported in Sec. 4.3 (p. 16).

* [VALIDATION] Results of logs validation reported in Sec. 4.3 (p. 15) and Table 2 of Appendix B. 

* [STATS] Statistics on type annotations reported in Figure 3 (p. 15).

* [RULES] Statistics on rules usage reported in Sec. 4.2 (p. 15) and Figure 6 of Appendix G.


## Artifact evaluation in a nutshell

Instructions for a quick evaluation of the artifact.

0) If this has not been done at the Getting Started step,
   run from the home directory
   
       $ make init

1) [TESTS]  
   From the home directory, execute

       $ make test_subtype
       $ make test_properties

   and check that all tests passed.  This validates our implementation of 
   Julia subtyping against the official regression test suite 
   (see "Julia's Official Subtyping Regression Suite" for details).  
   [Time: ~40 min on our  MacBook Pro]

2) [VALIDATION]  
   To run validation of logs for 5 packages listed in the file
   `~/julia-subtyping-reconstructed/Lambda-Julia/src/pkgs_list/pkgs-test-suit-short.txt`,
   execute from home

       $ make validation_short

   and check that the output table agrees with the Table in Appendix B.
   Remark: many Julia packages have been updated since submission.  
   Discrepancies should be small though.  
   [Time: ~3 hrs on a MacBook Pro]

   The list of 100 packages from the paper is:
   `~/julia-subtyping-reconstructed/Lambda-Julia/src/pkgs_list/pkgs-test-suit.txt`.
   Reviewers can choose what to validate, we suggest subsets to save time.

3) [RULES]  
   To get statistics on usage of subtype rules for the 100 packages,
   run from home

       $ make rule_stat
    
    This prints statistics in ASCII format and creates JSON file storing the
    data pictured on Fig. 6 (Appendix G). The pictures were created with 
    Google.Spreadsheets out of that JSON file.

    Note: the statistics are obtained from validation results located in the folder
    `~/julia-subtyping-reconstructed/Lambda-Julia/logging/oopsla-pkgs-validation-results`.
    [Time: ~2 min on a MacBook Pro]

4) [STATS]  
   To get figures similar to figures 3 and 5 from the paper, run

       $ make type_stat_short

   and see file `~/types_stat.html`.  
   [Time: ~5 min on a MacBook Pro]

   To get figures for the 100 packages, run

       $ make type_stat
    
    [Time: ~3 hrs on a MacBook Pro]

We now describe the artifact in detail, for the interested reader.

## Julia's Official Subtyping Regression Suite [ Section 4.3 ]

The official Julia 0.6.2 [regression test
suite](https://github.com/JuliaLang/julia/blob/v0.6.2/test/subtype.jl)
consists of:

  1. hand-written test cases collected from bug reports over the years;
  2. automatic validation of properties of subtyping on a given list of types.

We have split the regression suite in two different files:

  * `Lambda-Julia/src/tests/test_subtype.jl` are hand-written cases;
  * `Lambda-Julia/src/tests/test_properties.jl` has the property validation.

To validate hand-written tests, type:

    $ make test_subtype

All tests are expected to pass.  Statistics about rule usage are at the end.
To validate the property testing suite:

    $ make test_properties
    ...
    Test Summary:                       |   Pass   Total
    level properties: props of subtype  | 335097  335097

All tests are expected to pass.
[Time: ~40 min on a MacBook Pro]

We also provide hand-written tests for implementation of the `typeof`
function (Appendix A), which can be run with

    $ cd ~/julia-subtyping-reconstructed/Lambda-Julia/src
    $ make test_typeof

## Log Validation [ Section 4.3 and Appendix B ]

In addition to the official test suite, we validate our implementation on 
logs of subtype queries produced by running tests of 100 Julia packages.
As packages evolve, we provide logs collected at submission time:

    ~/julia-subtyping-reconstructed/Lambda-Julia/logging/oopsla-pkgs-logs

There is also an archive with a copy of those in the root folder.

The list of 100 packages we logged is

    ~/julia-subtyping-reconstructed/Lambda-Julia/src/pkgs_list/pkgs-test-suit.txt

Logs contain over 7 millions queries.  For speed, we built an infrastructure that
validates queries in parallel. On a 32 core server, this takes 8 hours.  

For evaluation purposes we provide a setup that validates 5 packages.  
[Time: ~3 hrs on a MacBook Pro.]

A suggested list of 5 packages is found in

    ~/julia-subtyping-reconstructed/Lambda-Julia/src/pkgs_list/pkgs-test-suit-short.txt

This short list can be edited.

The Python script `Lambda-Julia/src/run-validate.py` validates queries.
Validation over the short list of packages is performed with

    $ make validate_short

which is equivalent to the following three commands:

    $ cd ~/julia-subtyping-reconstructed/Lambda-Julia/src
    $ ./run-validate.py -v -t 3 -p 1 -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short.txt
    $ ./run-validate.py -r -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short.txt

The second command performs validation, and the third command collects
the results of validation in a convenient format. A table analogous to those 
reported in Appendix B will be found in

~/julia-subtyping-reconstructed/Lambda-Julia/logging/oopsla-pkgs-logs-copy/validation-res.txt

Statistics on queries that did not pass validation are stored in the file

    validation-err.txt

of the same folder, and the queries are stored in files

    <pkg-name>/add-log_subt/subtype-failures.txt
    <pkg-name>/test-log_subt/subtype-failures.txt

in case of sequential validation, and

    <pkg-name>/add-log_subt/subtype-failures-par.txt
    <pkg-name>/test-log_subt/subtype-failures-par.txt

in case of parallel validation. These should all be instances of the Julia bugs we found.

Note: Several packages have been update since paper submission, 
so number may be slightly off.

### Recovering an interrupted validation procedure

When log validation runs for the first time, it installs the dependencies/precompiles 
cache required by each package into Lambda-Julia/logging/oopsla-pkgs-logs/pkgs-<pkg-name>`.  
If for some reason not everything has been installed (for example, if validation has 
been interrupted), validation will fail/give wrong results for the package.  In this 
case it is recommended to rerun validation for "damaged" packages with the parameter 
`-b`: it will clean and reinstall the dependencies.  For example, if packages Foo 
and Bar have been affected, do the following:

1. Create a text file `my-pkgs.txt` in `Lambda-Julia/pkgs_list`:
   
       Foo.jl
       Bar.jl

2. Run from `Lambda-Julia/src`:

       $ ./run-validate.py -v -t 3 -p 1 -d oopsla-pkgs -f pkgs_list/my-pkgs.txt -b

## Collecting Logs [ Sec 4.3 ]

To collect logs of subtype checks from scratch, run from the home directory:

    $ make collect_short  

Logs will be built in the `Lambda-Julia/logging/oopsla-pkgs-new-logs` folder, as 
specified by the `-d` parameter.  Validation can then be run on the collected 
logs using the commands described above. 

As packages evolved since the paper submissions, it is normal to get different 
logs and different numbers of queries.  All the observed errors should, however, 
be instances of the Julia bugs discussed in the paper.

Remark: when validating newly collected logs, to recover an interrupted validation 
procedure, use the instructions from the previous section but replace `-b` flag 
with `-e`. The latter flag, in addition to cache, also cleans files of type declarations, 
`add-decls_inferred.json` and `test-decls_inferred.json`. These files are created during 
validation and might be broken due to a bad cache.

To collect logs for the 100 packages, run:

    ./run-validate.py -c -t 4 -d oopsla-pkgs-new -f pkgs_list/pkgs-test-suit.txt

* Parameter `-c` means that the script should run logs collection.
* Parameter `-t N` controls the size of a pool of python processes used
  for collecting a list of packages.


## [For Info] Interactive Session for the Reference Subtype Algorithm [ Sec 3.2 and 4.2 ]

The source code for the reference subtype algorithm lives in `Lambda-Julia/src`, and 
subtype rules are implemented in `subtype_xml.jl`.

To load the reference subtype algorithm, run the following:

    $ cd ~/julia-subtyping-reconstructed/Lambda-Julia/src
    $ julia
    ...
    julia> include("lj.jl")
    --- LJ-INFO: LJ init
    ...
    Loading type declarations... Done

    julia>

The entry point of the subtyping algorithm is the `lj_subtype` function, which accepts 
two strings representing two Julia types.  For instance:

    julia> lj_subtype("Tuple{Int}", "Tuple{Union{Bool,Number}}")
    = true
    =  |||

    julia> lj_subtype("Vector{Int}", "Vector{T} where T")
    = true
    = [T ^Int64 _Int64 R [false|0|1] false]  |||

    julia> lj_subtype("Tuple{Int}", "Tuple{Union{String, T}} where T")
    = true
    = [T ^Any _Int64 R [false|1|0] false]  |||

The first line of the output gives the result of the subtype test, and the second line 
details the final variable environment.  A complete execution trace can be obtained by 
setting `f_debug` to `true`:

    julia> set_f_debug(true)

    julia> lj_subtype("Tuple{Int}", "Tuple{Union{String, T}} where T")
    
    <?xml version="1.0"?>
    <check>
    <rule id="ASTBase, TWhere">
    <t1>Tuple{Int64}</t1>
    <t2>Tuple{Union{String, T}} where T</t2>
    <env> ||| </env>
    <rule id="TTuple, TTuple">
    <t1>Tuple{Int64}</t1>
    ...
    = true
    = [T ^Any _Int64 R [false|1|0] false]  |||

The xml trace can be easily explored with an interactive xml-tree
visualizer.  We have used the online service at: xmlviewer.org.

