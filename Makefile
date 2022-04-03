NIXADDR ?= localhost
NIXPORT ?= 22
NIXUSER ?= ddd
NIXBLOCKDEVICE ?= nvme0n1
NIXCONFIG ?= ddd-kontist

SSH_CMD=ssh -o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p$(NIXPORT)

vm/bootstrap:
	$(MAKE) vm/copy
	$(MAKE) vm/install

vm/copy:
	rsync -av -e '$(SSH_CMD)' \
		--exclude='.git/' \
		${CURDIR}/ root@$(NIXADDR):/nix-config

vm/install:
	$(SSH_CMD) root@$(NIXADDR) " \
		sudo nix-shell \
			--argstr blockDevice $(NIXBLOCKDEVICE) \
			--argstr systemName $(NIXCONFIG) \
			/nix-config/vm/bootstrap.nix \
	"

vm/secrets:
	rsync -av -e '$(SSH_CMD)' \
		$(HOME)/.ssh/ $(NIXUSER)@$(NIXADDR):/home/$(NIXUSER)/.ssh
