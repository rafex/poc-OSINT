AGE_KEY_FILE := $(HOME)/.age/key.txt

.PHONY: secrets-setup secrets-edit secrets-export secrets-view secrets-check secrets-pubkey

## secrets-setup      Genera clave age y crea secrets/secrets.enc.yaml cifrado
secrets-setup:
	@printf "$(CYAN)[secrets]$(RESET) Configurando age + SOPS…\n"
	$(UV) run --script $(SCRIPTS_PY_DIR)/setup_age.py

## secrets-edit       Abre vim para editar secretos (decrypt→edit→validate→encrypt)
secrets-edit:
	@printf "$(CYAN)[secrets]$(RESET) Abriendo editor de secretos…\n"
	SOPS_AGE_KEY_FILE=$(AGE_KEY_FILE) $(UV) run --script $(SCRIPTS_PY_DIR)/edit_secrets.py

## secrets-export     Exporta secretos descifrados a .env (no commitear)
secrets-export:
	@printf "$(CYAN)[secrets]$(RESET) Exportando a .env…\n"
	@SOPS_AGE_KEY_FILE=$(AGE_KEY_FILE) \
		sops --decrypt secrets/secrets.enc.yaml \
		| python3 $(SCRIPTS_PY_DIR)/export_secrets.py \
		> .env
	@printf "$(GREEN)[secrets]$(RESET) Exportado a .env (no commitear).\n"

## secrets-view       Muestra secretos descifrados en terminal (solo lectura)
secrets-view:
	SOPS_AGE_KEY_FILE=$(AGE_KEY_FILE) sops --decrypt secrets/secrets.enc.yaml

## secrets-check      Verifica que el archivo de secretos puede descifrarse
secrets-check:
	@bash $(SCRIPTS_SH_DIR)/secrets_check.sh

## secrets-pubkey     Muestra la clave pública age del sistema
secrets-pubkey:
	@bash $(SCRIPTS_SH_DIR)/secrets_pubkey.sh
