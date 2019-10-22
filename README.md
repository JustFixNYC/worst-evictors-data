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

To build the database tables needed to calculate the worst evictors
data, run:

```
python worst.py builddb
```

Then, to generate a CSV of worst evictors in RTC zipcodes, run:

```
python worst.py list:rtc > evictors-rtc.csv
```

Or to generate a CSV of worst evictors city-wide, run:

```
python worst.py list:citywide > evictors-citywide.csv
```

## Notes on the Analysis

A description of the methodology for this project can be found on the website's [About Page](https://www.worstevictorsnyc.org/about).

### Grouping HPD Head Officers together

Our methodology for making the worst evictors list combined data analysis from publicly available data with a community research-driven approach, using on-the-ground knowledge of tenants and tenant organizers. We found it important to use a variety of tools and strategies when generating this list as an effort to make the most comprehensive survey of who is evicting New Yorkers, as well as to provide a list that would help and encourage New Yorkers to organize.

We conducted our own research using the [Who Owns What tool](https://whoownswhat.justfix.nyc/) to group HPD Head Officers together that shared a common business address, and also relied on first-person accounts of shared business affiliation from tenant organizers in our network.

Here are landlords from the RTC Worst Evictors List that we found to be associated with a group of Head Officer names registered with HPD: 

* "ARETE MANAGEMENT" — JULIUS LAMAR, DAVID MATEO, RAFAL MARKWAT

* "LABE TWERSKI" — LABE TWERSKI, IABE TWERSKI

* "LARRY GLUCK" — LAURENCE GLUCK, LAWRENCE GLUCK, SMAJLJE SRDANOVIC

* "E&M ASSOCIATES" — JOEL GOLDSTEIN, IRVING LANGER, IRIVING LANGER, LEIBAL LEDERMAN, AVI DAIVES, AVI DAVIES, HENRY SPITZER, LOUIS LANGER, NAFTALI LEINER, NAFTOLI LEINER

* "PINNACLE" — RASIM TOSKIC, DAVID RADONCIC, ABIDIN RADONCIC, JOEL WEINER, EDWARD SUAZO, EDDIE LJESNJANIN, MARC BARHORIN, DAVID ROSE

* "STEVEN FINKELSTEIN" — STEVEN FINKELSTEIN, STEVE FINKELSTEIN 

* "MATTHEW BECKER" — MATTHEW BECKER, MATHEW BECKER, MARC FLYNN

* "MORGAN GROUP" — SCOTT MORGAN, RYAN MORGAN, BROOKE MORGAN, STUART MORGAN

* "HAGER MANAGEMENT" — JACOB HAGER, NAFTALI HAGER, NATALI HAGER

* "MOSHE PILLER" — MOSHE PILLER, MOSHE PILLLE, SAM ROSEN, SAMUEL BRETTLER 

* "MICHAEL NIAMONITAKIS" — MICHEAL NIAMONITAKIS, MICHAEL NIAMONITAKIS, MIKE NIAMONITAKIS, ANNMARIE BARKER, ANTHONY SIRIGOS, DESPINA SIDERATOS, EFTHIMIOS DIMITRIADIS, JAMES D. DIMITRIADES, JAMES DIMITRIADES, MICHAEL NEAMONITAKIS

* "BRG MANAGEMENT" — ELY SINGER, JONAH ROSENBERG, SCOTT MITTEL, ANDY FALKIN, ARI BENEDICT, FAUSTO DIAZ, AVNER SKOCZYLAS, BARRY SENDROVIC, JONAH ROSENBERG, ARI BENEDICT, DANIEL BENEDICT

* "A&E REAL ESTATE" — DONALD HASTINGS, MAGGIE MCCORMICK, DOUGLAS EISENBERG

* "UFARATZTA LLC" — 1635 CARROLL LLC,2509 ATLANTIC REALTY LLC,312 EZ REALTY LLC, 437 BMW LLC, 491 EQUITIES LLC, 682 MONTGOMERY LLC, DEAN PARK LLC, DRAM LLC, GAN EAST LLC, M WILHELM, MAUNTAUK PARK LLC, MENDY WILHELM, MMS REALTY LLC, PRESIDENT PLAZA LLC, UFARATZTA LLC, YANKY RODMAN

**Are we missing anybody?** If you think that there are other Head Officers related to the companies we are featuring in our RTC Worst Evictors List, or if you think we made a mistake somewhere, send us a suggestion via our [Feedback Form](https://docs.google.com/forms/d/e/1FAIpQLSfOwTTtRuCSb06_gYR7Zjjm-c0BWXzJlriJHRl8JwDVEnc-0g/viewform?usp=sf_link). 


