# Installation of Padro

## Dependencies

### Carton

Perl dependencies manager, it will get what you need, so don't bother for Perl modules dependencies (but you can read the file `cpanfile` if you want).

Best way to install Carton:

```shell
sudo cpan Carton
```

or

```shell
sudo apt-get install carton
```

NB: you may need to install `postgresql-server-dev-9.4` to install `DBD::Pg`.

## Installation

After installing Carton :

```shell
git clone https://git.framasoft.org/luc/padro.git
cd padro
carton install
cp padro.conf.template padro.conf
vi padro.conf
```

## Configuration

The `padro.conf.template` is self-documented.

## Database initialisation

Padro will initialize the databases, but you need to create them!

```
sudo su postgres
psql -d template1
```

Then

```
CREATE USER padro_user WITH PASSWORD 'padro_pwd';
CREATE DATABASE padro OWNER padro_user;
```

(Don't forget to update your `padro.conf` with the accurate database user and password)

## Starting Padro from command line

```
carton exec hypnotoad script/padro
```

## Starting the minion worker from command line

```
carton exec script/padro minion worker
```

## Init script

```
cp utilities/padro.init /etc/init.d/padro
cp utilities/padro_minion.init /etc/init.d/padro_minion
cp utilities/padro.default /etc/default/padro
# Change PDIR to match your installation
vi /etc/default/padro
update-rc.d padro defaults
update-rc.d padro_minion defaults
```

**NB** The `padro_minion.init` may fail. In that case, start minion worker from the command line

## Systemd

```
cp utilities/padro.service /etc/systemd/system/
cp utilities/padro_minion.service /etc/systemd/system/
# Change WorkingDirectory, PIDFile and the absolute path to carton to match your installation
vi /etc/systemd/system/padro.service /etc/systemd/system/padro_minion.service
systemctl enable padro.service
systemctl enable padro_minion.service
```

## Putting Padro behind a reverse proxy

Well, if you have an Etherpad instance to use with Padro, I guess you'll find a doc to put Padro behind a reverse proxy.

No time for documenting that right now.

## Update

```
git pull
carton install
carton exec hypnotoad script/padro
```

Yup, that's all (Mojolicious magic).
