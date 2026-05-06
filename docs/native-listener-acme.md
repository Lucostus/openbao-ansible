# Native Listener ACME

Bootstrap listener TLS is the default path for this repository, with OpenBao
Agent available later for renewal. Native listener ACME is retained as an
advanced fallback for environments that explicitly need OpenBao's ACME listener
behavior.

Enable it explicitly:

```yaml
openbao_certificate_mode: native_acme
openbao_pki_enabled: true
openbao_native_acme_challenge: tls-alpn-01
openbao_native_acme_cache_nfs_src: nfs-server.example.com:/exports/openbao-acme
openbao_native_acme_tls_alpn_routed: true
```

Native ACME requires a PKI signing source. Bootstrap mode intentionally skips
PKI setup, so add `openbao_root_ca_cert_pem` and `openbao_root_ca_key_pem` in
the selected environment vault, or provide another supported signing source
before switching to `native_acme`.

Supported challenges:

- `http-01`
- `tls-alpn-01`

Native ACME requires a shared cache, either mounted by Ansible with NFS or
pre-mounted by the operator:

```yaml
openbao_native_acme_cache_mode: nfs
openbao_native_acme_cache_mode: pre_mounted
```

Routing confirmation variables are intentionally explicit:

```yaml
openbao_native_acme_http_routed: true
openbao_native_acme_tls_alpn_routed: true
```

The PKI configuration keeps:

- `eab_policy=always-required`
- role-qualified EAB token generation from
  `pki_openbao/roles/openbao-listener/acme/new-eab`
- response headers `Replay-Nonce`, `Link`, `Location`, and `Last-Modified`

Generated EAB artifacts are stored under the selected environment's
`secure-artifacts/` directory on the controller.
