# Padro

**WARNING** This software is pre-alpha and not ready for production.

## What Padro means?

It means Pad Read Only.

## What does it do?

It downloads some pad informations and pad text from an [Etherpad](http://etherpad.org) instance.

It allows you to put Padro instead of your etherpad instance : the users will get their pad content and will be able to download text version and HTML version of their pad, but they will not be able to modify or create pads.

## License

Padro is licensed under the terms of the AGPL. See the LICENSE file.

## Installation and dependencies

See the INSTALL.md file.

## Get all the pads in one command

After intalling and lauching Padro, you can download all the pads with:

```
carton exec script/padro get_all_pads
```

Since it can take a really long time, depending on how many pads you have, the job is queued to the minion worker. To see the status of the queue, you can:

```
carton exec script/padro minion job
```
