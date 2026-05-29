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
		| python3 -c "\
import sys; \
[print(f'{k.strip()}={v.strip().strip(chr(34)).strip(chr(39))}') \
 for line in sys.stdin \
 if ':' in line and not line.strip().startswith('#') \
 for k, _, v in [line.partition(':')]  \
 if k.strip() and not k.strip().startswith('sops')] \
" > .env
	@printf "$(GREEN)[secrets]$(RESET) Exportado a .env (no commitear).\n"

## secrets-view       Muestra secretos descifrados en terminal (solo lectura)
secrets-view:
	SOPS_AGE_KEY_FILE=$(AGE_KEY_FILE) sops --decrypt secrets/secrets.enc.yaml

## secrets-check      Verifica que el archivo de secretos puede descifrarse
secrets-check:
	@SOPS_AGE_KEY_FILE=$(AGE_KEY_FILE) \
		sops --decrypt secrets/secrets.enc.yaml > /dev/null \
		&& printf "$(GREEN)[secrets]$(RESET) ✓ Secretos verificados.\n" \
		|| printf "$(RED)[secrets]$(RESET) ✗ Error al descifrar — verifica ~/.age/key.txt\n"

## secrets-pubkey     Muestra la clave pública age del sistema
secrets-pubkey:
	@grep "# public key:" $(AGE_KEY_FILE) 2>/dev/null \
		|| printf "$(RED)[secrets]$(RESET) No encontrada. Ejecuta: make secrets-setup\n"
