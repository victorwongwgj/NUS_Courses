"""Validate Docker networking and one causal majority read/write round trip."""

import os
import socket
import uuid

from pymongo import MongoClient
from pymongo.errors import PyMongoError
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern

# First verify that the replication-network aliases resolve inside the client
# container. A DNS failure here indicates a Docker networking problem rather
# than a MongoDB consistency or replica-set problem.
for host in ("mongo1-rs", "mongo2-rs", "mongo3-rs"):
    print(f"{host} -> {socket.gethostbyname(host)}")

# Next connect through the replica-set URI and wait for PyMongo to discover the
# current primary and secondaries. The test then performs one majority write
# followed by one majority read in the same causal session.
try:
    with MongoClient(
        os.environ["MONGO_URI"],
        serverSelectionTimeoutMS=10000,
        connectTimeoutMS=5000,
        socketTimeoutMS=10000,
    ) as client:
        print("Ping:", client.admin.command("ping"))
        print("Primary:", client.primary)
        print("Secondaries:", client.secondaries)

        collection = client["lab"].get_collection(
            "connection_test",
            read_concern=ReadConcern("majority"),
            write_concern=WriteConcern(
                w="majority",
                wtimeout=5000,
            ),
        )

        # Use a unique document ID so repeated smoke tests never overwrite or
        # depend on data created by an earlier invocation.
        document_id = str(uuid.uuid4())

        with client.start_session(causal_consistency=True) as session:
            result = collection.insert_one(
                {"_id": document_id, "value": 1},
                session=session,
            )

            document = collection.find_one(
                {"_id": document_id},
                session=session,
            )

        print("Write acknowledged:", result.acknowledged)
        print("Read result:", document)

        assert document is not None and document["value"] == 1
        print("Connection and basic read/write test passed.")

except PyMongoError as error:
    print(f"{type(error).__name__}: {error}")
    raise SystemExit(1)
