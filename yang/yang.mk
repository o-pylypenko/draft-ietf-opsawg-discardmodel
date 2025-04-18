YANGDIR ?= yang

STDYANGDIR ?= tools/yang
$(STDYANGDIR):
	git clone --depth 10 -b main https://github.com/YangModels/yang $@

OPTIONS=--tree-print-structures -f tree --tree-line-length=70

YANG_PATH=$(YANGDIR):$(STDYANGDIR)/standard/ietf/RFC/:$(STDYANGDIR)/standard/ieee/published/802.1/:$(STDYANGDIR)/experimental/ietf-extracted-YANG-modules

YANG=$(wildcard $(YANGDIR)/*.yang)
STDYANG=$(wildcard $(YANGDIR)/ietf-*.yang)
TXT=$(patsubst $(YANGDIR)/%.yang,$(YANGDIR)/trees/%.tree,$(YANG))

.PHONY: yang-lint yang-gen-tree yang-clean pyang-setup

$(YANGDIR)/trees:
	mkdir -p $@

pyang-setup: $(STDYANGDIR)
pyang-lint: pyang-setup $(STDYANG)
ifeq ($(STDYANG),)
	$(info No files matching $(YANGDIR)/ietf-*.yang found. Skipping pyang-lint.)
else
	pyang --ietf --max-line-length 69 -p $(YANG_PATH) $(STDYANG)
endif

yang-gen-tree: $(YANGDIR)/trees pyang-lint $(TXT)

yang-clean:
	rm -f $(TXT)

FORCE:

$(YANGDIR)/trees/%.tree: $(YANGDIR)/%.yang $(YANGDIR)/trees FORCE
	pyang $(OPTIONS) -p $(YANG_PATH) $< > $@
