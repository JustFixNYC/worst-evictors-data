from nycdb.dataset_transformations import to_csv


def marshal_evictions_18(dataset):
    return to_csv(dataset.files[0].dest)


def hpd_head_officers(dataset):
    return to_csv(dataset.files[0].dest)


def eviction_filings_1315(dataset):
    return to_csv(dataset.files[0].dest)


def hpd_contacts_dec_18(dataset):
    return to_csv(dataset.files[0].dest)


def hpd_registrations_grouped_by_bbl_dec_18(dataset):
    return to_csv(dataset.files[0].dest)


def hpd_contacts_dec_19(dataset):
    return to_csv(dataset.files[0].dest)


def hpd_registrations_grouped_by_bbl_dec_19(dataset):
    return to_csv(dataset.files[0].dest)
