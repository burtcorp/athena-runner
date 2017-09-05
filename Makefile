.PHONY: create-role create-functions deploy-functions deploy-state-machine deps

AWS_REGION ?= us-east-1
DEFAULT_NAME ?= athena-runner
STATE_MACHINE_NAME ?= $(or $(shell cat config/state-machine-arn 2>/dev/null | sed -E 's,^.+:,,'), $(DEFAULT_NAME))
ROLE_NAME ?= $(or $(shell cat config/role-arn 2>/dev/null | sed -E 's,^.+/,,'), $(STATE_MACHINE_NAME))

deps:
	npm install

create-role: update-role config/role-arn

config/role-arn:
	aws iam create-role \
		--role-name "$(ROLE_NAME)" \
		--assume-role-policy-document file://config/policies/TrustRelationship.json \
		--query 'Role.Arn' \
		--output text \
		> $@

put_role_policy = aws iam put-role-policy \
	--role-name "$(ROLE_NAME)" \
	--policy-name $(notdir $(basename $(1))) \
	--policy-document file://$(1)

update-role: policies = $(filter-out config/policies/TrustRelationship.json, $(wildcard config/policies/*.json))
update-role: config/role-arn
	$(foreach policy,$(policies),$(call put_role_policy,$(policy);))

role_arn = $(shell cat config/role-arn)
create_function = aws lambda create-function \
	--region "$(AWS_REGION)" \
	--function-name "$(STATE_MACHINE_NAME)-$(1)" \
	--runtime "nodejs6.10" \
	--role "$(role_arn)" \
	--handler "index.$(2)" \
	--description $(3) \
	--memory-size "128" \
	--zip-file fileb://$^

create-functions: dist/athena-runner.zip
	$(call create_function,start-query,startQuery,"Start an Athena query")
	$(call create_function,poll-status,pollStatus,"Check the status of an Athena query")
	$(call create_function,get-results,getResults,"Get the results from an Athena query")

update_function_code = aws lambda update-function-code \
	--region "$(AWS_REGION)" \
	--function-name "$(STATE_MACHINE_NAME)-$(1)" \
	--zip-file fileb://$^

update-functions: dist/athena-runner.zip
	$(call update_function_code,start-query)
	$(call update_function_code,poll-status)
	$(call update_function_code,get-results)

create-state-machine: config/state-machine-arn

config/state-machine-arn: role_arn = $(shell cat config/role-arn)
config/state-machine-arn: dist/state-machine.json
	aws stepfunctions create-state-machine \
		--region "$(AWS_REGION)" \
		--name "$(STATE_MACHINE_NAME)" \
		--definition fileb://$^ \
		--role-arn "$(role_arn)" \
		--query 'stateMachineArn' \
		--output text \
		> $@

dist/state-machine.json: dist state-machine.yml
	./node_modules/.bin/yaml2json --pretty $(filter-out dist, $^) > $@

delete-state-machine: state_machine_arn = $(shell aws stepfunctions list-state-machines --region $(AWS_REGION) --query "stateMachines[?name == '$(STATE_MACHINE_NAME)'].stateMachineArn" --output text)
delete-state-machine:
	aws stepfunctions delete-state-machine \
		--region "$(AWS_REGION)" \
		--state-machine-arn $(state_machine_arn)

dist:
	mkdir -p dist

dist/athena-runner.zip: dist index.js
	zip -r $@ $(filter-out dist, $^)
