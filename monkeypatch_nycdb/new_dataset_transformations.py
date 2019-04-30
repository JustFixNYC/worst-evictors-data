from nycdb.dataset_transformations import to_csv


def marshal_evictions_18(dataset):
    return to_csv(dataset.files[0].dest)
