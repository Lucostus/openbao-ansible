FROM registry.access.redhat.com/ubi10/ubi-init:latest

ENV QEMU_CPU=max

RUN dnf -y install \
      findutils \
      hostname \
      iproute \
      openssh-server \
      openssl \
      procps-ng \
      python3 \
      python3-cryptography \
      shadow-utils \
      sudo \
      util-linux-core \
    && dnf clean all

RUN groupadd --gid 10001 openbao \
    && useradd --uid 10001 --gid openbao --home-dir /var/lib/openbao --shell /sbin/nologin --no-create-home openbao \
    && useradd --create-home --shell /bin/bash ansible \
    && install -d -m 0755 /etc/ssh/authorized_keys \
    && install -d -m 0755 /etc/sudoers.d \
    && printf 'ansible ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/ansible \
    && chmod 0440 /etc/sudoers.d/ansible \
    && ssh-keygen -A \
    && sed -ri 's|^AuthorizedKeysFile[[:space:]]+.*|AuthorizedKeysFile /etc/ssh/authorized_keys/%u .ssh/authorized_keys|' /etc/ssh/sshd_config \
    && sed -ri 's|^#?PasswordAuthentication[[:space:]]+.*|PasswordAuthentication no|' /etc/ssh/sshd_config \
    && sed -ri 's|^#?PermitRootLogin[[:space:]]+.*|PermitRootLogin no|' /etc/ssh/sshd_config \
    && systemctl enable sshd

VOLUME ["/sys/fs/cgroup", "/var/lib/openbao", "/var/lib/openbao/certmagic"]
CMD ["/usr/sbin/init"]
