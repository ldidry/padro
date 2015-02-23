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

## Installation

After installing Carton :

```shell
git clone https://github.com/ldidry/padro.git
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
CREATE DATABASE padro;
GRANT ALL PRIVILEGES ON DATABASE padro to padro_user;
CREATE USER minion_user WITH PASSWORD 'minion_pwd';
CREATE DATABASE minion;
GRANT ALL PRIVILEGES ON DATABASE minion to minion_user;
```

## Starting Padro from command line

```
carton exec hypnotoad script/padro
```

## Starting the minion worker from command line

```
carton exec script/padro minion worker
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
