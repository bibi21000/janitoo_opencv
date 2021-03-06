# Makefile for janitoo
#

# You can set these variables from the command line.
ARCHBASE      = archive
BUILDDIR      = build
DISTDIR       = dists
NOSE          = $(shell which nosetests)
NOSEOPTS      = --verbosity=2
PYLINT        = $(shell which pylint)
PYLINTOPTS    = --max-line-length=140 --max-args=9 --extension-pkg-whitelist=zmq --ignored-classes=zmq --min-public-methods=0

ifndef PYTHON_EXEC
PYTHON_EXEC=python
endif

ifndef message
message="Auto-commit"
endif

ifdef VIRTUAL_ENV
python_version_full := $(wordlist 2,4,$(subst ., ,$(shell ${VIRTUAL_ENV}/bin/${PYTHON_EXEC} --version 2>&1)))
else
python_version_full := $(wordlist 2,4,$(subst ., ,$(shell ${PYTHON_EXEC} --version 2>&1)))
endif

python_version_major = $(word 1,${python_version_full})
python_version_minor = $(word 2,${python_version_full})
python_version_patch = $(word 3,${python_version_full})

PIP_EXEC=pip
ifeq (${python_version_major},3)
	PIP_EXEC=pip3
endif

MODULENAME   = $(shell basename `pwd`)
DOCKERNAME   = $(shell echo ${MODULENAME}|sed -e "s|janitoo_||g")
DOCKERVOLS   =
DOCKERPORT   =

NOSECOVER     = --cover-package=janitoo,janitoo_db,${MODULENAME} --cover-min-percentage= --with-coverage --cover-inclusive --cover-html --cover-html-dir=${BUILDDIR}/docs/html/tools/coverage --with-html --html-file=${BUILDDIR}/docs/html/tools/nosetests/index.html

DEBIANDEPS := $(shell [ -f debian.deps ] && cat debian.deps)
BOWERDEPS := $(shell [ -f bower.deps ] && cat bower.deps)

TAGGED := $(shell git tag | grep -c v${janitoo_version} )

distro = $(shell lsb_release -a 2>/dev/null|grep Distributor|cut -f2 -d ":"|sed -e "s/\t//g" )
release = $(shell lsb_release -a 2>/dev/null|grep Release|cut -f2 -d ":"|sed -e "s/\t//g" )
codename = $(shell lsb_release -a 2>/dev/null|grep Codename|cut -f2 -d ":"|sed -e "s/\t//g" )

OPENCV_VERSION = 3.2.0

-include Makefile.local

.PHONY: help check-tag clean all build develop install uninstall clean-doc doc certification tests pylint deps docker-tests

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  build           : build the module"
	@echo "  develop         : install for developpers"
	@echo "  install         : install for users"
	@echo "  uninstall       : uninstall the module"
	@echo "  deps            : install dependencies for users"
	@echo "  doc   	    	 : make documentation"
	@echo "  tests           : launch tests"
	@echo "  clean           : clean the development directory"

clean-dist:
	-rm -rf $(DISTDIR)

clean: clean-doc
	-rm -rf $(ARCHBASE)
	-rm -rf $(BUILDDIR)
	-rm -rf build_cv/opencv-${OPENCV_VERSION}/_build
	-rm -rf build_cv/opencv_contrib-${OPENCV_VERSION}/_build
	-rm -f generated_doc
	-rm -f janidoc
	-@find . -name \*.pyc -delete

check:
	-ls -Rlira /opt/python/2.7.12/

uninstall:
	-yes | ${PIP_EXEC} uninstall ${MODULENAME}
	-${PYTHON_EXEC} setup.py develop --uninstall
	-@find . -name \*.egg-info -type d -exec rm -rf "{}" \;

build_cv/opencv-${OPENCV_VERSION}:
	-mkdir -p build_cv
	cd  build_cv && wget -O opencv.zip https://heanet.dl.sourceforge.net/project/opencvlibrary/opencv-unix/${OPENCV_VERSION}/opencv-${OPENCV_VERSION}.zip
	cd  build_cv && unzip opencv.zip

build_cv/opencv_contrib-${OPENCV_VERSION}:
	-mkdir -p build_cv
	cd  build_cv && wget -O opencv-contrib.zip https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip
	cd  build_cv && unzip opencv-contrib.zip

deps: build_cv/opencv-${OPENCV_VERSION} build_cv/opencv_contrib-${OPENCV_VERSION}
	#sudo apt-get remove ffmpeg libswscale-ffmpeg3 libswresample-ffmpeg1 libpostproc-ffmpeg53 libavutil-ffmpeg54 libavresample-ffmpeg2 libavformat-ffmpeg56 libavfilter-ffmpeg5 libavdevice-ffmpeg56 libavcodec-ffmpeg56
	#-sudo apt-get remove -y python-opencv libopencv-calib3d2.4v5 libopencv-core2.4v5 libopencv-features2d2.4v5 libopencv-flann2.4v5 libopencv-imgproc2.4v5 libopencv-ml2.4v5 libopencv-photo2.4v5 libopencv-video2.4v5
	#-sudo apt-get remove -y python-opencv libopencv-calib3d2.4 libopencv-contrib2.4 libopencv-core2.4 libopencv-features2d2.4 libopencv-flann2.4 libopencv-highgui2.4 libopencv-imgproc2.4 libopencv-legacy2.4 libopencv-ml2.4 libopencv-objdetect2.4 libopencv-photo2.4 libopencv-video2.4
ifneq ('${DEBIANDEPS}','')
	sudo apt-get install -y ${DEBIANDEPS}
endif
	-sudo apt-get install -y libtbb-dev
	@echo
	@echo "Dependencies for ${MODULENAME} finished."

clean-doc:
	-rm -Rf ${BUILDDIR}/docs
	-rm -Rf ${BUILDDIR}/janidoc
	-rm -f objects.inv
	-rm -f generated_doc
	-rm -f janidoc

janidoc:
	-ln -s /opt/janitoo/src/janitoo_sphinx janidoc

apidoc:
	-rm -rf ${BUILDDIR}/janidoc/source/api
	-mkdir -p ${BUILDDIR}/janidoc/source/api
	cp -Rf janidoc/* ${BUILDDIR}/janidoc/
	cd ${BUILDDIR}/janidoc/source/api && sphinx-apidoc --force --no-toc -o . ../../../../src/
	cd ${BUILDDIR}/janidoc/source/api && mv ${MODULENAME}.rst index.rst

doc: janidoc apidoc
	- [ -f transitions_graph.py ] && python transitions_graph.py
	-cp -Rf rst/* ${BUILDDIR}/janidoc/source
	sed -i -e "s/MODULE_NAME/${MODULENAME}/g" ${BUILDDIR}/janidoc/source/tools/index.rst
	make -C ${BUILDDIR}/janidoc html
	cp ${BUILDDIR}/janidoc/source/README.rst README.rst
	-ln -s $(BUILDDIR)/docs/html generated_doc
	@echo
	@echo "Documentation finished."

github.io:
	git checkout --orphan gh-pages
	git rm -rf .
	touch .nojekyll
	git add .nojekyll
	git commit -m "Initial import" -a
	git push origin gh-pages
	git checkout master
	@echo
	@echo "github.io branch initialised."

doc-full: tests pylint doc-commit

doc-commit: doc
	git checkout gh-pages
	cp -Rf build/docs/html/* .
	git add *.html
	git add *.js
	git add tools/
	git add api/
	-git add _images/
	-git add _modules/
	-git add _sources/
	-git add _static/
	git commit -m "Auto-commit documentation" -a
	git push origin gh-pages
	git checkout master
	@echo
	@echo "Documentation published to github.io."

pylint:
	-mkdir -p ${BUILDDIR}/docs/html/tools/pylint
	$(PYLINT) --output-format=html $(PYLINTOPTS) src/${MODULENAME} >${BUILDDIR}/docs/html/tools/pylint/index.html

install: develop
	@echo
	@echo "Installation of ${MODULENAME} finished."

develop: build
	@echo
	@echo "Installation for developpers of ${MODULENAME} finished."
	@echo "Install opencv for $(distro):$(codename)."
	cd build_cv/opencv-${OPENCV_VERSION}/_build && \
		sudo make install
	sudo ldconfig
	@echo
	@echo "Dependencies for ${MODULENAME} finished."

directories:
	-sudo mkdir /opt/janitoo
	-sudo chown -Rf ${USER}:${USER} /opt/janitoo
	-for dir in cache cache/janitoo_manager home log run etc init; do mkdir /opt/janitoo/$$dir; done

travis-deps: deps
	sudo apt-get -y install wget curl python-numpy
	@echo
	@echo "Travis dependencies for ${MODULENAME} installed."

docker-tests:
	@echo
	@echo "Docker tests for ${MODULENAME} start."
	[ -f tests/test_docker.py ] && $(NOSE) $(NOSEOPTS) $(NOSEDOCKER) tests/test_docker.py
	@echo
	@echo "Docker tests for ${MODULENAME} finished."

docker-local-pull:
	@echo
	@echo "Pull local docker for ${MODULENAME}."
	docker pull bibi21000/${MODULENAME}
	@echo
	@echo "Docker local for ${MODULENAME} pulled."

docker-local-store: docker-local-pull
	@echo
	@echo "Create docker local store for ${MODULENAME}."
	docker create -v /root/.ssh/ -v /opt/janitoo/etc/ ${DOCKERVOLS} --name ${DOCKERNAME}_store bibi21000/${MODULENAME} /bin/true
	@echo
	@echo "Docker local store for ${MODULENAME} created."

docker-local-running: docker-local-pull
	@echo
	@echo "Update local docker for ${MODULENAME}."
	-docker stop ${DOCKERNAME}_running
	-docker rm ${DOCKERNAME}_running
	docker create --volumes-from ${DOCKERNAME}_store -p ${DOCKERPORT}:22 --name ${DOCKERNAME}_running bibi21000/${MODULENAME}
	docker ps -a|grep ${DOCKERNAME}_running
	docker start ${DOCKERNAME}_running
	docker ps|grep ${DOCKERNAME}_running
	@echo
	@echo "Docker local for ${MODULENAME} updated."

docker-deps:
	-cp -rf docker/config/* /opt/janitoo/etc/
	-cp -rf docker/supervisor.conf.d/* /etc/supervisor/janitoo.conf.d/
	-cp -rf docker/supervisor-tests.conf.d/* /etc/supervisor/janitoo-tests.conf.d/
	-cp -rf docker/nginx/* /etc/nginx/conf.d/
	true
	@echo
	@echo "Docker dependencies for ${MODULENAME} installed."

tests:
	python -c "import cv2; print cv2.__version__"
	@echo
	@echo "Tests for ${MODULENAME} finished."

certification:
	$(NOSE) --verbosity=2 --with-xunit --xunit-file=certification/result.xml certification
	@echo
	@echo "Certification for ${MODULENAME} finished."

build_cv/opencv-3.2.0/_build/lib/cv2.so:
	@echo
	@echo "Installation for developpers of ${MODULENAME} finished."
	@echo "Install opencv for $(distro):$(codename)."
	-mkdir -p build_cv/opencv-${OPENCV_VERSION}/_build
	cd build_cv/opencv-${OPENCV_VERSION}/_build && \
		cmake -D CMAKE_BUILD_TYPE=RELEASE \
		-D CMAKE_INSTALL_PREFIX=/usr/local \
		-D BUILD_opencv_freetype=OFF \
		-D INSTALL_C_EXAMPLES=OFF \
		-D INSTALL_PYTHON_EXAMPLES=OFF \
		-D WITH_V4L=ON \
		-D WITH_OPENGL=ON \
		-D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-${OPENCV_VERSION}/modules \
		-D BUILD_EXAMPLES=OFF ..
	#cat build_cv/opencv-3.2.0/_build/CMakeCache.txt
	#cat build_cv/opencv-3.2.0/_build/CMakeVars.txt
	cd build_cv/opencv-${OPENCV_VERSION}/_build && \
		make -j$$(nproc)

build: build_cv/opencv-3.2.0/_build/lib/cv2.so
	@echo
	@echo "Dependencies for ${MODULENAME} finished."

travis-build:
	@echo
	@echo "Installation for travis of ${MODULENAME} finished."
	@echo "Install opencv for $(distro):$(codename)."
	-mkdir -p build_cv/opencv-${OPENCV_VERSION}/_build
	cd build_cv/opencv-${OPENCV_VERSION}/_build && \
		cmake -D CMAKE_BUILD_TYPE=RELEASE \
		-D CMAKE_INSTALL_PREFIX=/usr/local \
		-D PYTHON2_LIBRARIES=/opt/python/2.7.12/lib/libpython2.7.so \
		-D PYTHON2_LIBRARY=/opt/python/2.7.12/lib/libpython2.7.so \
		-D PYTHON2_INCLUDE_DIR=/opt/python/2.7.12/include/python2.7 \
		-D PYTHON2_INCLUDE_PATH=/opt/python/2.7.12/include/python2.7 \
		-D PYTHON2LIBS_VERSION_STRING=2.7.12 \
		-D BUILD_opencv_freetype=OFF \
		-D INSTALL_C_EXAMPLES=OFF \
		-D WITH_V4L=ON \
		-D WITH_OPENGL=ON \
		-D INSTALL_PYTHON_EXAMPLES=OFF \
		-D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-${OPENCV_VERSION}/modules \
		-D BUILD_EXAMPLES=OFF ..
	#cat build_cv/opencv-3.2.0/_build/CMakeCache.txt
	#cat build_cv/opencv-3.2.0/_build/CMakeVars.txt
	cd build_cv/opencv-${OPENCV_VERSION}/_build && \
		make -j4
	cd build_cv/opencv-${OPENCV_VERSION}/_build && \
		sudo make install
	sudo ldconfig
	cp -a /usr/local/lib/python2.7/site-packages/cv2.so /home/travis/virtualenv/python2.7.12/lib/python2.7/site-packages/

egg:
	-mkdir -p $(BUILDDIR)
	-mkdir -p $(DISTDIR)
	${PYTHON_EXEC} setup.py bdist_egg --bdist-dir $(BUILDDIR) --dist-dir $(DISTDIR)

tar:
	-mkdir -p $(DISTDIR)
	tar cvjf $(DISTDIR)/${MODULENAME}-${janitoo_version}.tar.bz2 -h --exclude=\*.pyc --exclude=\*.egg-info --exclude=janidoc --exclude=.git* --exclude=$(BUILDDIR) --exclude=$(DISTDIR) --exclude=$(ARCHBASE) .
	@echo
	@echo "Archive for ${MODULENAME} version ${janitoo_version} created"

commit:
	-git add rst/
	-cp rst/README.rst .
	-git add README.rst
	git commit -m "$(message)" -a && git push
	@echo
	@echo "Commits for branch master pushed on github."

pull:
	git pull
	@echo
	@echo "Commits from branch master pulled from github."

status:
	git status

tag: check-tag commit
	git tag v${janitoo_version}
	git push origin v${janitoo_version}
	@echo
	@echo "Tag pushed on github."

check-tag:
ifneq ('${TAGGED}','0')
	echo "Already tagged with version ${janitoo_version}"
	@/bin/false
endif

new-version: tag clean tar
	@echo
	@echo "New version ${janitoo_version} created and published"

debch:
	dch --newversion ${janitoo_version} --maintmaint "Automatic release from upstream"

deb:
	dpkg-buildpackage
