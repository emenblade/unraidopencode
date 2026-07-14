FROM node:22-bookworm-slim

# git/ssh: opencode shells out to git; ripgrep: used by opencode's search tool;
# tini: reaps zombie processes / forwards signals correctly as PID 1
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
        openssh-client \
        ripgrep \
        tini \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai@latest && npm cache clean --force

RUN useradd --create-home --shell /bin/bash opencode \
    && mkdir -p /workspace \
    && chown -R opencode:opencode /workspace /home/opencode

WORKDIR /workspace

ENV HOME=/home/opencode

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 4096

# Starts as root so entrypoint.sh can fix bind-mount ownership, then drops
# to the non-root opencode user via runuser before actually running anything.
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
