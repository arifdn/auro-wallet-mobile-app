# auro wallet

auro wallet built with Flutter for mina protocol



### Introduction

auro wallet provide one-stop management for mina protocol, convenient staking, and the private key is self-owned.


auro wallet is aiming to provide a more convenient entrance of the mina network.

- Friendly UI.
- Secure local accounts storage.
- Intuitive Assets management.
- Simplified staking.
- Available for both IOS and Android.

### Building

#### Dependencies

- `Flutter 2.0.4 statble`
- `Dart 2.12.2`

#### Install Flutter 
`auro wallet` is built with [Flutter](https://flutter.dev/), you need to have `Flutter` dev tools
installed on your computer to compile the project. check [Flutter Documentation](https://flutter.dev/docs)
 to learn how to install `Flutter` and initialize a Flutter App.

#### mina sdk
we use flutter ffi and mina c file to derive public key and sign transactions.


#### run auro App
```
flutter run --no-sound-null-safety
```
some packages has not migrate to null safety, so we have to add --no-sound-null-safety arguments.