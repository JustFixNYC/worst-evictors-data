This repository contains the data analysis for the
[worst evictors website](https://github.com/JustFixNYC/worst-evictors-site).

## Quick start

You will need [Python 3.7](https://python.org/) or later. You will
also need _either_ Postgres or [Docker](https://docker.com).

### Python setup

First, create a Python 3 virtual environment, enter it,
and install dependencies:

```
python3 -m venv venv
. venv/bin/activate   # Or 'venv\Scripts\activate' on Windows
pip install -r requirements.txt
```

### Database setup

#### Option 1: Docker

If you don't already have Postgres, you can set up a server
with Docker by running the following in a separate terminal:

```
docker-compose up
```

Once you're done using this project, if you want to delete
all data used by the database, you can run:

```
docker-compose down -v
```

#### Option 2: Postgres

Alternatively, if you already have a database make sure to set
the `DATABASE_URL` environment variable to point at it, e.g.:

```
export DATABASE_URL=postgres://nycdb:nycdb@localhost/nycdb
```

### Build everything

To build the final database and calculate the worst evictors
data, run:

```
python worst.py builddb
```
