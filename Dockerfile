FROM jupyter/datascience-notebook:82b978b3ceeb

MAINTAINER Rion Dooley <deardooley@gmail.com>

# Install agave python sdk and bash kernel
# Add sshpass for importing password without displaying in console
USER root
RUN cd /usr/local && \
    wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 && \
    mv /usr/local/jq-linux64 /usr/local/bin/jq && \
    chmod +x /usr/local/bin/jq && \
    apt-get update && \
    apt-get -y install sshpass bsdmainutils libgit2-dev libssl-dev libv8-3.14-dev && \
    apt-get clean

USER jovyan

# install agavepy and bash kernel in python 3 environments
RUN pip install -e "git+https://github.com/TACC/agavepy.git#egg=agavepy" && \
    pip install bash_kernel && \
    python -m bash_kernel.install && \
    pip install --upgrade matplotlib pandas jupyterlab

# install jypter widgets for html form generation
RUN pip install ipywidgets && \
    jupyter nbextension enable --py --sys-prefix widgetsnbextension

# install agavepy in the python 2 environment
RUN pip2 install -e "git+https://github.com/TACC/agavepy.git#egg=agavepy"

USER root

# install rAgave SDK
RUN echo '\n\
    \noptions(repos = c(CRAN = "https://cran.rstudio.com/"), download.file.method = "libcurl") \
    \noptions(repos = c(CRAN="https://cran.revolutionanalytics.com/"), download.file.method = "libcurl") \
    \n\
    \n# Configure httr to perform out-of-band authentication if HTTR_LOCALHOST \
    \n# is not set since a redirect to localhost may not work depending upon \
    \n# where this Docker container is running. \
    \nif(is.na(Sys.getenv("HTTR_LOCALHOST", unset=NA))) { \
    \n  options(httr_oob_default = TRUE) \
    \n}' >> .Rprofile

RUN if [ ! -e "/bin/gtar" ]; then ln -s /bin/tar /bin/gtar; fi && \
    git clone --depth 1 https://github.com/agaveplatform/r-sdk.git src/r-sdk

RUN Rscript -e 'install.packages(c("xml2","plyr","roxygen2"))'
RUN Rscript -e 'devtools::install_github("ropensci/codemetar")'

RUN Rscript -e 'devtools::install("/home/jovyan/src/r-sdk")' \
            -e 'devtools::document("/home/jovyan/src/r-sdk")' \
            -e 'devtools::install("/home/jovyan/src/r-sdk")'
RUN echo '\n\
    \nlibrary("plyr") \
    \nlibrary("httr") \
    \nlibrary("rAgave") \
    \n\
    \n# disable ssl peer verification if requested \
    \nset_config( config( ssl_verifypeer = 0L ) ) \
    \n}' >> .Rprofile && \
    chown jovyan /home/jovyan/.Rprofile


USER jovyan
# Install agave bash cli
RUN  git clone -b develop --depth  1  https://github.com/agaveplatform/agave-cli.git src/cli
ENV PATH $PATH:/usr/local/jq/bin:$HOME/src/cli/bin
ENV AGAVE_JSON_PARSER jq
ENV AGAVE_CLI_COMPLETION_SHOW_FILES no
ENV AGAVE_CLI_COMPLETION_SHOW_FILE_PATHS no
ENV AGAVE_CLI_COMPLETION_CACHE_LIFETIME 0
RUN tenants-init -t agave.prod -v

COPY notebooks notebooks
COPY INSTALL.ipynb INSTALL.ipynb
COPY start.sh /usr/local/bin
COPY jupyter_notebook_config.py /home/jovyan/.jupyter/jupyter_notebook_config.py


ARG BUILD_DATE
ARG VERSION

LABEL org.agaveplatform.devops.architecture="x86_64"                                \
      org.agaveplatform.devops.build-date="$BUILD_DATE"                             \
      org.agaveplatform.devops.license="BSD 3-clause"                               \
      org.agaveplatform.devops.name="agaveplatform/jupyter-notebook"    \
      org.agaveplatform.devops.summary="Jupyter datascience notebook server with Agave Python SDK and CLI " \
      org.agaveplatform.devops.version="$VERSION"                                   \
      org.agaveplatform.devops.vcs-type="git"                                       \
      org.agaveplatform.devops.vcs-url="https://github.com/agaveplatform/jupyter-notebook" \
      org.agaveplatform.devops.jupyter.version="5.2.x"                              \
      org.agaveplatform.devops.environment="training"                               \
      org.agaveplatform.training="jupyter"

ENV VM_MACHINE sandbox
ENV VM_IPADDRESS 204.90.47.30
ENV USE_TUNNEL False
ENV VM_PORT 10022

USER root

COPY ./ssh/ /home/jovyan/.ssh/
COPY keygen.sh /usr/local/bin/keygen.sh
RUN chmod 700 /home/jovyan/.ssh && \
    cp /home/jovyan/.ssh/id_rsa.pub /home/jovyan/.ssh/authorized_keys && \
    chmod 600 /home/jovyan/.ssh/authorized_keys && \
    chmod 600 /home/jovyan/.ssh/id_rsa && \
    echo "Host *" > /home/jovyan/.ssh/config && \
    echo "UserKnownHostsFile      /dev/null" >> /home/jovyan/.ssh/config && \
    echo "StrictHostKeyChecking   false" >> /home/jovyan/.ssh/config && \
    chown -R jovyan:users /home/jovyan && \
    chmod 700 .jupyter && \
    chmod +x /usr/local/bin/keygen.sh


