SRCDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
JULIAHOME := $(abspath $(SRCDIR)/..)
BUILDDIR := .
include $(JULIAHOME)/Make.inc
VERSDIR := v$(shell cut -d. -f1-2 < $(JULIAHOME)/VERSION)
STDLIBDIR := $(build_datarootdir)/julia/stdlib/$(VERSDIR)
# TODO: this Makefile ignores BUILDDIR, except for computing JULIA_EXECUTABLE

export JULIA_DEPOT_PATH := $(build_prefix)/share/julia
export JULIA_LOAD_PATH := @$(PATHSEP)@stdlib
unexport JULIA_PROJECT :=
unexport JULIA_BINDIR :=

TESTGROUPS = unicode strings compiler Compiler
TESTS = all default stdlib $(TESTGROUPS) \
		$(patsubst $(STDLIBDIR)/%/,%,$(dir $(wildcard $(STDLIBDIR)/*/.))) \
		$(filter-out runtests testdefs relocatedepot, \
			$(patsubst $(SRCDIR)/%.jl,%,$(wildcard $(SRCDIR)/*.jl))) \
		$(foreach group,$(TESTGROUPS), \
			$(patsubst $(SRCDIR)/%.jl,%,$(wildcard $(SRCDIR)/$(group)/*.jl)))
# run `make print-TESTS` to see a list of all tests that can be run

EMBEDDING_ARGS := "JULIA=$(JULIA_EXECUTABLE)" "BIN=$(SRCDIR)/embedding" "CC=$(CC)"

GCEXT_ARGS := "JULIA=$(JULIA_EXECUTABLE)" "BIN=$(SRCDIR)/gcext" "CC=$(CC)"

TRIMMING_ARGS := "JULIA=$(JULIA_EXECUTABLE)" "BIN=$(SRCDIR)/trimming" "CC=$(CC)"

default:

$(TESTS):
	@cd $(SRCDIR) && \
	$(call PRINT_JULIA, $(call spawn,$(JULIA_EXECUTABLE)) --check-bounds=yes --startup-file=no --depwarn=error ./runtests.jl $@)

$(addprefix revise-, $(TESTS)): revise-% :
	@cd $(SRCDIR) && \
    $(call PRINT_JULIA, $(call spawn,$(JULIA_EXECUTABLE)) --check-bounds=yes --startup-file=no --depwarn=error ./runtests.jl --revise $*)

relocatedepot:
	@rm -rf $(SRCDIR)/relocatedepot
	@cd $(SRCDIR) && \
	$(call PRINT_JULIA, $(call spawn,$(JULIA_EXECUTABLE)) --check-bounds=yes --startup-file=no --depwarn=error ./runtests.jl $@)
	@mkdir $(SRCDIR)/relocatedepot
	@cp -R $(build_datarootdir)/julia $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg1 $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg2 $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg3 $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg4 $(SRCDIR)/relocatedepot
	@cd $(SRCDIR) && \
	$(call PRINT_JULIA, $(call spawn,RELOCATEDEPOT="" $(JULIA_EXECUTABLE)) --check-bounds=yes --startup-file=no --depwarn=error ./runtests.jl $@)

revise-relocatedepot: revise-% :
	@rm -rf $(SRCDIR)/relocatedepot
	@cd $(SRCDIR) && \
	$(call PRINT_JULIA, $(call spawn,$(JULIA_EXECUTABLE)) --check-bounds=yes --startup-file=no --depwarn=error ./runtests.jl --revise $*)
	@mkdir $(SRCDIR)/relocatedepot
	@cp -R $(build_datarootdir)/julia $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg1 $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg2 $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg3 $(SRCDIR)/relocatedepot
	@cp -R $(SRCDIR)/RelocationTestPkg4 $(SRCDIR)/relocatedepot
	@cd $(SRCDIR) && \
	$(call PRINT_JULIA, $(call spawn,RELOCATEDEPOT="" $(JULIA_EXECUTABLE)) --check-bounds=yes --startup-file=no --depwarn=error ./runtests.jl --revise $*)

embedding:
	@$(MAKE) -C $(SRCDIR)/$@ check $(EMBEDDING_ARGS)

gcext:
	@$(MAKE) -C $(SRCDIR)/$@ check $(GCEXT_ARGS)

trimming:
	@$(MAKE) -C $(SRCDIR)/$@ check $(TRIMMING_ARGS)

clangsa:
	@$(MAKE) -C $(SRCDIR)/$@

clean:
	@$(MAKE) -C embedding $@ $(EMBEDDING_ARGS)
	@$(MAKE) -C gcext $@ $(GCEXT_ARGS)
	@$(MAKE) -C llvmpasses $@
	@$(MAKE) -C trimming $@ $(TRIMMING_ARGS)

.PHONY: $(TESTS) $(addprefix revise-, $(TESTS)) relocatedepot revise-relocatedepot embedding gcext trimming clangsa clean
