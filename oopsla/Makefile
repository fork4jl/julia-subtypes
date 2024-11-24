init:
	@echo ""
	@echo "***************************************************"
	@echo "Preparing for artefact evaluation: rebuilding Julia"
	@echo "***************************************************"
	@echo ""
	cd ~/julia && make clean && make -j2
	cd ~/julia-subtyping-reconstructed/Lambda-Julia/julia-log-062 && make clean && make -j2 -f Makefile.fresh && make -j2

check_subtype:
	@echo ""
	@echo "**************************************************************"
	@echo "Super simple demo showing a call to the subtype implementation"
	@echo "**************************************************************"
	@echo "[[[[[  Will check: Vector{Int} <: Union{Vector, String}  ]]]]]"
	@echo ""
	cd ~/julia-subtyping-reconstructed/Lambda-Julia/src && \
	julia -L "lj.jl" -e 'println(lj_subtype("Vector{Int}", "Union{Vector, String}"))'    

test_subtype:
	@echo ""
	@echo "********************************************"
	@echo "Running Julia regression suit on LambdaJulia"
	@echo "********************************************"
	@echo ""
	make -C ~/julia-subtyping-reconstructed/Lambda-Julia/src test_subtype

test_properties:
	@echo ""
	@echo "******************************"
	@echo "Running test_properties target"
	@echo "******************************"
	@echo "Huge set of computer-generated types to check subtype properties"
	@echo "This may take half an hour and shows progress"
	@echo ""
	make  -C ~/julia-subtyping-reconstructed/Lambda-Julia/src test_properties

validate_short:
	@echo ""
	@echo "*******************************************************************"
	@echo "Validation of LambdaJulia on logs from small subset of 100 packages"
	@echo "*******************************************************************"
	@echo "The subset is defined in pkgs-test-suit-short.txt, you can tweak it at will"
	@echo ""
	cd ~/julia-subtyping-reconstructed/Lambda-Julia/src && \
	./run-validate.py -v -t 3 -p 1 -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short.txt && \
	./run-validate.py -r -d oopsla-pkgs -f pkgs_list/pkgs-test-suit-short.txt  && \
	less ../logging/oopsla-pkgs-logs-copy/validation-res.txt

collect_short:
	@echo ""
	@echo "**************************************************************"
	@echo "Collection of subtype logs from a small subset of 100 packages"
	@echo "**************************************************************"
	@echo "The subset is defined in pkgs-test-suit-short.txt, you can tweak it at will"
	@echo "Full dataset of logs is provided in julia-subtyping-reconstructed/oopsla-pkgs-logs.tar.gz"
	@echo ""
	cd ~/julia-subtyping-reconstructed/Lambda-Julia/src && \
	./run-validate.py -c -t 4 -d oopsla-pkgs-new -f pkgs_list/pkgs-test-suit-short.txt

rule_stat:
	@echo ""
	@echo "***********************************************"
	@echo "Collection of rules statistics for 100 packages"
	@echo "***********************************************"
	cd ~/julia-subtyping-reconstructed/Lambda-Julia/logging/oopsla-pkgs-validation-results && \
	julia ../../src/validation/rules_stats/collect_rules_stats.jl

type_stat_short:
	@echo ""
	@echo "****************************************************************************"
	@echo "Collection of type annotations statistics for a small subset of 100 packages"
	@echo "****************************************************************************"
	cd ~/julia-subtyping-reconstructed/Lambda-Julia/src/sa_stats && \
	./make-data.sh ../pkgs_list/pkgs-test-suit-short.txt

type_stat:
	@echo ""
	@echo "**********************************************************"
	@echo "Collection of type annotations statistics for 100 packages"
	@echo "**********************************************************"
	cd ~/julia-subtyping-reconstructed/Lambda-Julia/src/sa_stats && \
	./make-data.sh
