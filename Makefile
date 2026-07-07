IMAGE_NAME ?= project-devops-deploy
APP_PORT ?= 8080
MANAGEMENT_PORT ?= 9090

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
	ansible-galaxy install -r ansible/requirements.yml

ansible-deploy:
	ansible-playbook -i ansible/inventory.ini playbook.yml

ansible-check:
	ansible-playbook -i ansible/inventory.ini playbook.yml --check


.PHONY: build docker-build docker-start ansible-install ansible-deploy ansible-check
