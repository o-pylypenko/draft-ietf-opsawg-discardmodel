YANGDIR ?= yang

STDYANGDIR ?= tools/yang
$(STDYANGDIR):
	git clone --depth 10 -b main https://github.com/YangModels/yang $@

OPTIONS=--tree-print-structures -f tree --tree-line-length=70

ifeq ($(OS), Windows_NT)
	YANG_PATH="$(YANGDIR);$(STDYANGDIR)/standard/ietf/RFC/;$(STDYANGDIR)/standard/ieee/published/802.1/;$(STDYANGDIR)/experimental/ietf-extracted-YANG-modules"
else
	YANG_PATH="$(YANGDIR):$(STDYANGDIR)/standard/ietf/RFC/:$(STDYANGDIR)/standard/ieee/published/802.1/:$(STDYANGDIR)/experimental/ietf-extracted-YANG-modules"
endif

YANG=$(wildcard $(YANGDIR)/*.yang)
STDYANG=$(wildcard $(YANGDIR)/ietf-*.yang)
TXT=$(patsubst %.yang,%-tree.txt,$(YANG))

.PHONY: yang-lint yang-gen-tree yang-clean

pyang-lint: $(STDYANG) $(STDYANGDIR)
ifeq ($(STDYANG),)
	$(info No files matching $(YANGDIR)/ietf-*.yang found. Skipping pyang-lint.)
else
	pyang -V --ietf -f tree --tree-line-length=69 -p $(YANG_PATH) $(STDYANG)
endif

yang-gen-tree: pyang-lint $(TXT)

yang-clean:
	rm -f $(TXT)

$(YANGDIR)/%-tree.txt: $(YANGDIR)/%.yang
	pyang $(OPTIONS) -p $(YANG_PATH) $< > $@
