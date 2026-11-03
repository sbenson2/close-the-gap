# Security

This demo's friend transport validates the host's pinned certificate, authenticates an expiring private invite over DTLS, and gates gameplay RPCs until authentication completes. The host is authoritative. It is intended for invited friends, and does not provide competitive anti-cheat or historical hit rewind. Advanced LAN/direct-IP mode is a separate testing path.

For a vulnerability, use [GitHub private vulnerability reporting](https://github.com/sbenson2/close-the-gap/security/advisories/new). Include the version, reproduction steps and relevant redacted logs. Do not post live invites, private keys, credentials or another person's network details in a public issue. If private reporting is unavailable, use GitHub's private security contact mechanisms rather than disclosing a working secret publicly.

The latest demo is the supported version. The free Noray community service is operated by its maintainers, independently of this repository. Do not test against that public service without authorization; local fixtures and two-client tests are provided.
