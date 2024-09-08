# Dockerfile reference: https://github.com/PowerShell/PowerShell-Docker/blob/master/release/7-4/alpine317/docker/Dockerfile
ARG BUILD_FROM
FROM $BUILD_FROM AS installer-env

ARG PS_VERSION=7.4.5
ARG PS_PACKAGE=powershell-${PS_VERSION}-linux-musl-x64.tar.gz
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE}
ARG PS_INSTALL_VERSION=7

# Download the Linux tar.gz and save it
ADD ${PS_PACKAGE_URL} /tmp/linux.tar.gz

# define the folder we will be installing PowerShell to
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION

# Create the install folder
RUN mkdir -p ${PS_INSTALL_FOLDER}

# Unzip the Linux tar.gz
RUN tar zxf /tmp/linux.tar.gz -C ${PS_INSTALL_FOLDER} -v

# Start a new stage so we lose all the tar.gz layers from the final image
FROM $BUILD_FROM

COPY --from=installer-env ["/opt/microsoft/powershell", "/opt/microsoft/powershell"]

# Define Args and Env needed to create links
ARG PS_INSTALL_VERSION=7
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION \
  \
  # Define ENVs for Localization/Globalization
  DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
  LC_ALL=en_US.UTF-8 \
  LANG=en_US.UTF-8 \
  # set a fixed location for the Module analysis cache
  PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache \
  POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-Alpine-3.19

# Install dotnet dependencies and ca-certificates
RUN apk add --no-cache \
  ca-certificates \
  less \
  \
  # PSReadline/console dependencies
  ncurses-terminfo-base \
  \
  # .NET Core dependencies
  krb5-libs \
  libgcc \
  libintl \
  # Apparently no longer in Alpine as of 3.18 and needs libssl3
  #libssl1.1 \
  libssl3 \
  libstdc++ \
  tzdata \
  userspace-rcu \
  zlib \
  icu-libs \
  && apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache \
  lttng-ust \
  \
  # PowerShell remoting over SSH dependencies
  openssh-client \
  \
  && apk update \
  && apk upgrade \
  # Create the pwsh symbolic link that points to powershell
  && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh \
  \
  # Give all user execute permissions and remove write permissions for others
  && chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh \
  # intialize powershell module cache
  # and disable telemetry
  && export POWERSHELL_TELEMETRY_OPTOUT=1 \
  && pwsh \
  -NoLogo \
  -NoProfile \
  -Command " \
  \$ErrorActionPreference = 'Stop' ; \
  \$ProgressPreference = 'SilentlyContinue' ; \
  while(!(Test-Path -Path \$env:PSModuleAnalysisCachePath)) {  \
  Write-Host "'Waiting for $env:PSModuleAnalysisCachePath'" ; \
  Start-Sleep -Seconds 6 ; \
  }"

COPY Run-ScriptsAsThreads.ps1 /app/
COPY Read-HassIoStdIn.ps1 /app/

ENTRYPOINT ["pwsh","-NoProfile", "-NoLogo", "-NonInteractive","-File","/app/Run-ScriptsAsThreads.ps1"]