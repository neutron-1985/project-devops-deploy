include config.mk

EDITOR ?= vi
IMAGE_NAME ?= $(DOCKER_REGISTRY)/$(DOCKER_REPOSITORY)
APP_PORT ?= 8080
MANAGEMENT_PORT ?= 9090
APP_IMAGE_TAG ?= latest
ANSIBLE = ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook

test:
	./gradlew test

start: run

run:
	./gradlew bootRun

update-gradle:
	./gradlew wrapper --gradle-version 9.2.1

update-deps:
	./gradlew refreshVersions

install:
	./gradlew dependencies

build:
	./gradlew build

docker-build:
	docker build -t $(IMAGE_NAME) .

docker-start:
	docker run --rm -p $(APP_PORT):8080 -p $(MANAGEMENT_PORT):9090 $(IMAGE_NAME)

docker-config:
	@echo "registry=$(DOCKER_REGISTRY)"
	@echo "username=$(DOCKER_USERNAME)"
	@echo "repository=$(DOCKER_REPOSITORY)"

lint:
	./gradlew spotlessCheck

lint-fix:
	./gradlew spotlessApply

ansible-install:
	ANSIBLE_CONFIG=ansible/ansible.cfg ansible-galaxy install -r ansible/requirements.yml

ansible-configure:
	$(ANSIBLE) -i localhost, -c local ansible/playbooks/render_deploy_config.yml

vault-rekey:
	install -m 700 -d ansible/.generated
	install -m 600 /dev/null ansible/.generated/vault-password.new
	$(EDITOR) ansible/.generated/vault-password.new
	ansible-vault rekey --vault-password-file ansible/.vault-password --new-vault-password-file ansible/.generated/vault-password.new ansible/vault/production.yml
	mv ansible/.generated/vault-password.new ansible/.vault-password

provision: ansible-configure
	$(ANSIBLE) playbook.yml --tags provision

deploy: ansible-configure
	$(ANSIBLE) playbook.yml --tags deploy -e app_image_repository=$(DOCKER_REGISTRY)/$(DOCKER_REPOSITORY) -e app_image_tag=$(APP_IMAGE_TAG)

ansible-check: ansible-configure
	$(ANSIBLE) playbook.yml --tags deploy --check --diff -e app_image_repository=$(DOCKER_REGISTRY)/$(DOCKER_REPOSITORY) -e app_image_tag=$(APP_IMAGE_TAG)

.PHONY: build docker-build docker-start docker-config ansible-install ansible-configure vault-rekey provision deploy ansible-check
