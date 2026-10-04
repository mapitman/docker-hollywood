NAME := "mapitman/hollywood-directors-cut"
# The same image is also published under its old name, so old commands keep working.
ALIAS := "mapitman/hollywood"

default: build
build:
	docker build --build-arg VCS_REF=`git rev-parse --short HEAD` --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` -t {{NAME}} -t {{ALIAS}} .
run:
	docker run -it --rm --name hollywood {{NAME}}
push:
	docker push {{NAME}}
	docker push {{ALIAS}}
