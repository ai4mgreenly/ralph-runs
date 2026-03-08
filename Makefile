INSTALL_DIR := $(HOME)/.local/share/ralph-runs
BIN_DIR     := $(HOME)/.local/bin

GOAL_SCRIPTS := goal-abort goal-cancel goal-comment goal-comments goal-create \
                goal-done goal-get goal-list goal-queue goal-retry goal-start goal-stuck

.PHONY: install

install:
	rm -rf $(INSTALL_DIR)/scripts
	mkdir -p $(INSTALL_DIR)/scripts $(BIN_DIR)
	cp -r scripts/. $(INSTALL_DIR)/scripts/
	@# ralph-runs wrapper
	printf '#!/bin/sh\nexec %s/scripts/ralph-runs/run "$$@"\n' "$(INSTALL_DIR)" > $(BIN_DIR)/ralph-runs
	chmod +x $(BIN_DIR)/ralph-runs
	@# ralph wrapper
	printf '#!/bin/sh\nexec %s/scripts/ralph/run "$$@"\n' "$(INSTALL_DIR)" > $(BIN_DIR)/ralph
	chmod +x $(BIN_DIR)/ralph
	@# notify wrapper
	printf '#!/bin/sh\nexec %s/scripts/notify/run "$$@"\n' "$(INSTALL_DIR)" > $(BIN_DIR)/notify
	chmod +x $(BIN_DIR)/notify
	@# goal-* wrappers
	$(foreach script,$(GOAL_SCRIPTS), \
		printf '#!/bin/sh\nexec %s/scripts/$(script)/run "$$@"\n' "$(INSTALL_DIR)" > $(BIN_DIR)/$(script); \
		chmod +x $(BIN_DIR)/$(script);)
	@echo "Installed to $(INSTALL_DIR) and $(BIN_DIR)"
