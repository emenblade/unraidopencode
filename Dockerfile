FROM node:22-bookworm-slim

# git/ssh: opencode shells out to git; ripgrep: used by opencode's search tool;
# tini: reaps zombie processes / forwards signals correctly as PID 1;
# python3/pip/venv, p7zip, jq, unzip/zip, sqlite3, nano/less/tree, procps:
# general-purpose toolkit for agent-driven scripting/data work
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
        gnupg \
        openssh-client \
        ripgrep \
        tini \
        python3 \
        python3-pip \
        python3-venv \
        p7zip-full \
        jq \
        unzip \
        zip \
        sqlite3 \
        nano \
        less \
        tree \
        procps \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI - not in Debian's default repos, needs its own apt source
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai@latest && npm cache clean --force

RUN useradd --create-home --shell /bin/bash opencode \
    && mkdir -p /workspace \
    && install -d -o opencode -g opencode /home/opencode/.config/opencode \
    && install -d -o opencode -g opencode /home/opencode/.local/share/opencode \
    && install -d -o opencode -g opencode /home/opencode/.local/state/opencode \
    && install -d -o opencode -g opencode /home/opencode/.cache/opencode \
    && chown -R opencode:opencode /workspace /home/opencode

WORKDIR /workspace

ENV HOME=/home/opencode \
    XDG_CONFIG_HOME=/home/opencode/.config \
    XDG_DATA_HOME=/home/opencode/.local/share \
    XDG_STATE_HOME=/home/opencode/.local/state \
    XDG_CACHE_HOME=/home/opencode/.cache \
    PIP_BREAK_SYSTEM_PACKAGES=1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 4096

# Starts as root so entrypoint.sh can fix bind-mount ownership, then drops
# to the non-root opencode user via runuser before actually running anything.
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
