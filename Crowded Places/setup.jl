using Conda

Conda.add("earthengine-api"; channel = "conda-forge")

ssl = pyimport("ssl")

# workaround to prevent issues with the python package certifi
ssl._create_default_https_context = ssl._create_unverified_context

ee = pyimport("ee")

# you must first create a Google Cloud project
# see https://developers.google.com/earth-engine/guides/access
ee.Authenticate()