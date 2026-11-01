# Usage: make <namespace> <command>   e.g. `make skill tui`
# `make` or `make <namespace>` lists commands.
.DEFAULT_GOAL := help
NAMESPACES := skill

NS  := $(word 1,$(MAKECMDGOALS))
CMD := $(word 2,$(MAKECMDGOALS))

.PHONY: help $(NAMESPACES)

help:
	@grep -hE '^[a-z]+/[a-z-]+:.*## ' Makefile | grep -E '^$(or $(NS_FILTER),[a-z]+)/' \
	  | sed -E 's|^([a-z]+)/([a-z-]+):.*## |\1 \2\t|' \
	  | awk -F'\t' '{printf "  make %-22s %s\n", $$1, $$2}'

# `make <ns> <cmd>` -> `make <ns>/<cmd>`
$(NAMESPACES):
	@if [ -z "$(CMD)" ]; then $(MAKE) -s help NS_FILTER=$@; \
	else $(MAKE) --no-print-directory "$@/$(CMD)"; fi

ifneq ($(filter $(NS),$(NAMESPACES)),)
$(wordlist 2,99,$(MAKECMDGOALS)):
	@:
endif

skill/tui: ## skills, agents, MCP, instructions: state per target, mark (space), install marked (enter), remove (x), diff (d)
	@scripts/skill-tui/skill-tui.sh tui

skill/list: ## same as a plain table
	@scripts/skill-tui/skill-tui.sh list
