ARG ALPINE_VER="3.21"
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# build args
ARG RELEASE

# install fetch packages
RUN \
	apk add --no-cache \
		bash \
		curl \
		git \
		jq

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch source
RUN \
	if [ -z ${RELEASE+x} ]; then \
	RELEASE=$(curl -u "${SECRETUSER}:${SECRETPASS}" -sX GET "https://api.github.com/repos/Fallenbagel/jellyseerr/releases/latest" \
	| jq -r ".tag_name");	fi \
	&& set -ex \
	&& mkdir -p \
		/opt/jellyseerr \
	&& curl -o \
	/tmp/jellyseerr.tar.gz -L \
	"https://github.com/Fallenbagel/jellyseerr/archive/refs/tags/${RELEASE}.tar.gz" \
	&& tar xf \
	/tmp/jellyseerr.tar.gz -C \
	/opt/jellyseerr --strip-components=1

FROM alpine:${ALPINE_VER} as build-stage

############## build stage ##############

# copy artifacts from fetch stage
COPY --from=fetch-stage /opt/jellyseerr /opt/jellyseerr

# set workdir
WORKDIR /opt/jellyseerr

# install build packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		g++ \
		git \
		make \
		nodejs \
		pnpm \
		python3 \
		sqlite \
		yarn

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# build package
RUN \
	CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile \
	&& pnpm build

FROM sparklyballs/alpine-test:${ALPINE_VER}

############## runtine stage ##############

# add artifacts from build stage
COPY --from=build-stage /opt/jellyseerr /opt/jellyseerr

# set workdir
WORKDIR /opt/jellyseerr

# install runtime packages
RUN \
	set -ex \
	&& apk add --no-cache \
		nodejs \
		pnpm \
		sqlite
		
# add local files
COPY root/ /

EXPOSE 5055
VOLUME /config
