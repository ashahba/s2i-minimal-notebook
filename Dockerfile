# This image provides a Python 3.7 environment you can use to run your Python
# applications.

ARG IMAGE_NAME=registry.access.redhat.com/ubi8/s2i-core
ARG IMAGE_TAG=latest

FROM ${IMAGE_NAME}:${IMAGE_TAG}

USER root

EXPOSE 8080

# TODO(Spryor): ensure these are right, add Anaconda versions
ENV PYTHON_VERSION=3.7 \
    PATH=$HOME/.local/bin/:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    PIP_NO_CACHE_DIR=off \
    APP_ROOT=/opt/app-root \
    CONDA_ROOT=/opt/miniconda3

# RHEL7 base images automatically set these envvars to run scl_enable. RHEl8
# images, however, don't as most images don't need SCLs any more. But we want
# to run it even on RHEL8, because we set the virtualenv environment as part of
# that script
#ENV BASH_ENV=${APP_ROOT}/etc/scl_enable \
#    ENV=${APP_ROOT}/etc/scl_enable \
#    PROMPT_COMMAND=". ${APP_ROOT}/etc/scl_enable"

# Ensure we're enabling Anaconda by forcing the activation script in the shell
ENV BASH_ENV="${CONDA_ROOT}/bin/activate ${APP_ROOT}" \
    ENV="${CONDA_ROOT}/bin/activate ${APP_ROOT}" \
    PROMPT_COMMAND=". ${CONDA_ROOT}/bin/activate ${APP_ROOT}"

ENV SUMMARY="" \
    DESCRIPTION=""

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Anaconda Python 3.7" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,python,python37,python-37,miniconda-python37" \
      com.redhat.component="python-37-container" \
      name="ubi8/miniconda-37" \
      version="1" \
      usage="" \
      maintainer="Probably Anaconda"

RUN yum -y module enable httpd:2.4 && \
    INSTALL_PKGS="atlas-devel \
    enchant \
    gcc-gfortran \
    httpd \
    httpd-devel \
    libffi-devel \
    libtool-ltdl \
    mod_auth_gssapi \
    mod_ldap \
    mod_session \
    mod_ssl \
    nss_wrapper" && \
    yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all --enablerepo='*'

# TODO(Spryor): What extra files exactly...?
# Copy extra files to the image.
# COPY ./root/ /

# - Create a Python virtual environment for use by any application to avoid
#   potential conflicts with Python packages preinstalled in the main Python
#   installation.
# - In order to drop the root user, we have to make some directories world
#   writable as OpenShift default security model is to run the container
#   under random UID.

ARG CONDA_VERSION=py37_4.9.2
RUN curl https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh > Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh && \
    chmod +x Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh && \
    ./Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh -b -p ${CONDA_ROOT} && \
    rm ./Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh

RUN \
    ${CONDA_ROOT}/bin/conda create -y --prefix ${APP_ROOT} python=${PYTHON_VERSION} && \
    chown -R 1001:0 ${APP_ROOT} && \
    fix-permissions ${APP_ROOT} -P && \
    fix-permissions ${CONDA_ROOT} -P && \
    rpm-file-permissions

COPY . /tmp/src

RUN ${CONDA_ROOT}/bin/conda env create -f /tmp/src/environment.yml

RUN rm -rf /tmp/src/.git* && \
    chown -R 1001 /tmp/src && \
    chgrp -R 0 /tmp/src && \
    chmod -R g+w /tmp/src && \
    rm -rf /tmp/scripts && \
    mv /tmp/src/.s2i/bin /tmp/scripts

RUN /tmp/scripts/assemble

RUN ${CONDA_ROOT}/bin/conda clean -y --all

USER 1001

CMD [ "/opt/app-root/builder/run" ]
