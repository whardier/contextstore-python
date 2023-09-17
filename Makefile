#!/usr/bin/make -f

PYTHON_VERSION ?= 3.10
PYTHON := python$(PYTHON_VERSION)

PIP_CACHE_PATH ?= $(PWD)/.cache/pip
VIRTUAL_ENV_PATH ?= $(PWD)/.venv
VIRTUAL_ENV_EXPORTS ?= VIRTUAL_ENV=$(VIRTUAL_ENV_PATH) PATH=$(VIRTUAL_ENV_PATH)/bin:$(PATH)

VIRTUAL_ENV_PYTHON := $(VIRTUAL_ENV_EXPORTS) $(PYTHON)
VIRTUAL_ENV_PYTHON_M_BUILD := $(VIRTUAL_ENV_EXPORTS) $(PYTHON) -m build
VIRTUAL_ENV_PYTHON_M_PIP := $(VIRTUAL_ENV_EXPORTS) $(PYTHON) -m pip
VIRTUAL_ENV_PYTHON_M_PIP_TOOLS := $(VIRTUAL_ENV_EXPORTS) $(PYTHON) -m piptools
VIRTUAL_ENV_PYTHON_M_PRE_COMMIT := $(VIRTUAL_ENV_EXPORTS) $(PYTHON) -m pre_commit
VIRTUAL_ENV_PYTHON_M_TOX := $(VIRTUAL_ENV_EXPORTS) $(PYTHON) -m tox
VIRTUAL_ENV_TOML_SORT := $(VIRTUAL_ENV_EXPORTS) toml-sort

all: \
	development \
	build \
	image

noop:

virtual-env: $(VIRTUAL_ENV_PATH)/bin/activate

$(VIRTUAL_ENV_PATH)/bin/activate:
	test -d $(VIRTUAL_ENV_PATH) || $(PYTHON) -m venv $(VIRTUAL_ENV_PATH) --prompt $(notdir $(PWD))

development-upgrade-virtual-env: virtual-env
	mkdir -p $(PIP_CACHE_PATH)
	$(VIRTUAL_ENV_PYTHON_M_PIP) install --force-reinstall --no-deps --find-links=$(PIP_CACHE_PATH) \
		-r requirements/bootstrap.txt
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) sync --find-links=$(PIP_CACHE_PATH) \
		requirements/deployment.txt \
		requirements/development.txt \
		requirements/production.txt

development-install-editable-package: virtual-env
	$(VIRTUAL_ENV_PYTHON_M_PIP) install --no-deps -e ./

development-install-pre-commit: virtual-env
	$(VIRTUAL_ENV_PYTHON_M_PRE_COMMIT) install \
		--hook-type pre-commit \
		--hook-type commit-msg \
		--hook-type pre-push

development-upgrade-pre-commit: virtual-env
	$(VIRTUAL_ENV_PYTHON_M_PRE_COMMIT) autoupdate

development: \
	development-upgrade-virtual-env \
	development-install-editable-package \
	development-install-pre-commit \
	development-upgrade-pre-commit \
	noop

production-upgrade-virtual-env: virtual-env
	mkdir -p $(PIP_CACHE_PATH)
	$(VIRTUAL_ENV_PYTHON_M_PIP) install --force-reinstall --no-deps --find-links=$(PIP_CACHE_PATH) \
		-r requirements/bootstrap.txt
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) sync --find-links=$(PIP_CACHE_PATH) \
		requirements/production.txt

production-install-editable-package: virtual-env
	$(VIRTUAL_ENV_PYTHON_M_PIP) install --no-deps -e ./

production: \
	production-upgrade-virtual-env \
	production-install-editable-package \
	noop

requirements:
	mkdir -p $(PIP_CACHE_PATH)

	# Clean this out so that we are always drawing from `constraints.txt`.
	rm -f requirements/bootstrap.txt
	rm -f requirements/development.txt
	rm -f requirements/production.txt
	rm -f requirements/deployment.txt

	# Compile the constraints from all of the input files.
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) compile \
		--verbose \
		--allow-unsafe \
		--generate-hashes \
		--no-emit-index-url \
		--no-emit-options \
		--no-emit-trusted-host \
		--no-reuse-hashes \
		--output-file=requirements/constraints.txt \
		--resolver=backtracking \
		--strip-extras \
		--find-links=$(PIP_CACHE_PATH) \
	    --upgrade \
		requirements/*.in

	# Fill in all the hashes.. sigh..
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) compile \
		--verbose \
		--allow-unsafe \
		--generate-hashes \
		--no-emit-index-url \
		--no-emit-options \
		--no-emit-trusted-host \
		--no-reuse-hashes \
		--output-file=requirements/constraints.txt \
		--resolver=backtracking \
		--strip-extras \
		--find-links=$(PIP_CACHE_PATH) \
		requirements/*.in

	# Compile the bootstrap requirements.
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) compile \
		--verbose \
		--allow-unsafe \
		--generate-hashes \
		--no-emit-index-url \
		--no-emit-options \
		--no-emit-trusted-host \
		--no-reuse-hashes \
		--output-file=requirements/bootstrap.txt \
		--resolver=backtracking \
		--strip-extras \
		--find-links=$(PIP_CACHE_PATH) \
		requirements/constraints.in.inc \
		requirements/bootstrap.in

	# Compile the deployment requirements.
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) compile \
		--verbose \
		--allow-unsafe \
		--generate-hashes \
		--no-emit-index-url \
		--no-emit-options \
		--no-emit-trusted-host \
		--no-reuse-hashes \
		--output-file=requirements/deployment.txt \
		--resolver=backtracking \
		--strip-extras \
		--find-links=$(PIP_CACHE_PATH) \
		requirements/constraints.in.inc \
		requirements/deployment.in

	# Compile the development requirements.
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) compile \
		--verbose \
		--allow-unsafe \
		--generate-hashes \
		--no-emit-index-url \
		--no-emit-options \
		--no-emit-trusted-host \
		--no-reuse-hashes \
		--output-file=requirements/development.txt \
		--resolver=backtracking \
		--strip-extras \
		--find-links=$(PIP_CACHE_PATH) \
		requirements/constraints.in.inc \
		requirements/development.in

	# Compile the production requirements.
	$(VIRTUAL_ENV_PYTHON_M_PIP_TOOLS) compile \
		--verbose \
		--allow-unsafe \
		--generate-hashes \
		--no-emit-index-url \
		--no-emit-options \
		--no-emit-trusted-host \
		--no-reuse-hashes \
		--output-file=requirements/production.txt \
		--resolver=backtracking \
		--strip-extras \
		--find-links=$(PIP_CACHE_PATH) \
		requirements/constraints.in.inc \
		requirements/production.in

pyproject: pyproject.toml

pyproject.toml:
	# Sort the pyproject.toml file.
	$(VIRTUAL_ENV_TOML_SORT) \
		--in-place \
		--sort-inline-arrays \
		--sort-inline-tables \
		--sort-table-keys \
		--spaces-indent-inline-array 4 \
		--trailing-comma-inline-array \
		$@

test: development
	$(VIRTUAL_ENV_PYTHON_M_TOX)

build:
	$(VIRTUAL_ENV_PYTHON_M_BUILD)

.PHONY: \
	build \
	development \
	development-install-editable-package \
	development-install-pre-commit \
	development-upgrade-pre-commit \
	development-upgrade-virtual-env \
	metify.code-workspace \
	production \
	production-upgrade-virtual-env \
	pyproject.toml \
	requirements \
	test \
	noop
