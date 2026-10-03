# Recovery

## GPG + pass

Mount the encrypted backup drive and locate `recovery/pass/`.

Restore GPG:

    gpg --pinentry-mode loopback --import gpg-private.asc
    gpg --import-ownertrust gpg-ownertrust.txt

Restore pass:

    cp -a password-store ~/.password-store

Verify:

    pass
