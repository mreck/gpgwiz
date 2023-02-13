# GPG WIZard

An opinionated wizard for GPG.

## Download

```
wget https://raw.githubusercontent.com/mreck/gpgwiz/master/gpgwiz.sh
```

## Usage

### 1. Generation full set of keys with removed master key

This command will generate a master GPG key and a full set of
sub-keys (for signing, authenticating, and encrypting).

It will also export all of those for safe keeping, while only
reimporting the sub-keys. This way, you can keep you master key
safe somewhere else. Minimizing the change of it being compromised
along side your sub-keys - making revocation less painful, if the
need ever arises.

You will have to input your password a few times during the
generation, because it's never stored by the script and always
entered directly into GPG. On the plus side, it's good practice
for remembering it.

If everything went well, this should be the output you see in
the end:

```
$ gpg --list-secret-keys --keyid-format=long alice@example.com

sec#  rsa4096/E1B7ECFB5DC3C621 2023-02-12 [SC]
      FE92B22AF62358E68F319A2FE1B7ECFB5DC3C621
uid                 [ultimate] Alice Doe <alice@example.com>
ssb   rsa4096/5AAD2B1E0351557C 2023-02-12 [S] [expires: 2024-02-12]
ssb   rsa4096/9C2AD0177CA5E87A 2023-02-12 [A] [expires: 2024-02-12]
ssb   rsa4096/6D22D0FC376103BC 2023-02-12 [E] [expires: 2024-02-12]
```

### 2. List all keys

Simply lists all keys. Pretty self explanatory.

## TODO

Thing I still want to add:

- [ ] Automatically create a paperkey as well.
