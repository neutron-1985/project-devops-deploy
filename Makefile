IMAGE_NAME ?= project-devops-deploy
APP_PORT ?= 8080
MANAGEMENT_PORT ?= 9090
APP_IMAGE_TAG ?= latest
ANSIBLE_EXTRA_VARS ?= -e app_image_tag=$(APP_IMAGE_TAG)
ANSIBLE_DEPLOY_TAGS ?= --tags deploy
ANSIBLE_PROVISION_TAGS ?= --tags provision
ANSIBLE_CONFIG ?= ansible/ansible.cfg
ANSIBLE_INVENTORY ?= ansible/inventory.ini

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

lint:
	./gradlew spotlessCheck

lint-fix:
	./gradlew spotlessApply

ansible-install:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-galaxy install -r ansible/requirements.yml

provision: ansible-provision

ansible-provision:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-playbook -i $(ANSIBLE_INVENTORY) playbook.yml $(ANSIBLE_PROVISION_TAGS)

deploy: ansible-deploy

ansible-deploy:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-playbook -i $(ANSIBLE_INVENTORY) playbook.yml $(ANSIBLE_DEPLOY_TAGS) $(ANSIBLE_EXTRA_VARS)

ansible-check:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-playbook -i $(ANSIBLE_INVENTORY) playbook.yml $(ANSIBLE_DEPLOY_TAGS) --check $(ANSIBLE_EXTRA_VARS)

ansible-dry-run:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-playbook -i $(ANSIBLE_INVENTORY) playbook.yml $(ANSIBLE_DEPLOY_TAGS) --check --diff $(ANSIBLE_EXTRA_VARS)

.PHONY: build docker-build docker-start ansible-install provision ansible-provision deploy ansible-deploy ansible-check ansible-dry-run
