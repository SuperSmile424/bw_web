# Compile the web vault using docker
# Usage:
#    docker build -t web_vault_build .
#    image_id=$(docker create web_vault_build)
#    docker cp $image_id:/bw_web_vault.tar.gz .
#    docker rm $image_id
#
#    Note: you can use --build-arg to specify the version to build:
#    docker build -t web_vault_build --build-arg VAULT_VERSION=master .

FROM node:13.8.0-stretch as build

# Prepare the folder to enable non-root, otherwise npm will refuse to run the postinstall
RUN mkdir /vault
RUN chown node:node /vault
USER node

# Can be a tag, release, but prefer a commit hash because it's not changeable
# https://github.com/bitwarden/web/commit/$VAULT_VERSION
ARG VAULT_VERSION=7e95e44f1d8e4a85c68afa0418163eac215be559

RUN git clone https://github.com/bitwarden/web.git /vault
WORKDIR /vault

RUN git checkout "$VAULT_VERSION"

COPY --chown=node:node patches /patches
COPY --chown=node:node apply_patches.sh /apply_patches.sh

RUN bash /apply_patches.sh

# Build
RUN npm install
RUN npm audit fix
RUN npm run dist

# Delete debugging map files, optional
# RUN find build -name "*.map" -delete

# Prepare the final archives
RUN mv build web-vault
RUN tar -czvf "bw_web_vault.tar.gz" web-vault --owner=0 --group=0

# We copy the final result as a separate image so there's no need to download all the intermediate steps
FROM scratch
COPY --from=build /vault/bw_web_vault.tar.gz /bw_web_vault.tar.gz
# Added so docker create works
CMD ["bash"]
