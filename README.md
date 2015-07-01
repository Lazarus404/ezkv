Ezkv
====

This application shows a simple key / value storage server application.  The application is an umbrella structure containing three inner applications:

   - ez_proto: Provides packet processors for RESP (Redis format) and a custom format based on a modified STUN structure. Packets are polymorphosed for interoperability.
   - ez_queue: In memory key / value store using OTP processes to maintain HashDicts (known here as buckets). Processes are identified by name, so packets can be stored and retrieved in a chosen bucket.
   - ez_server: Containing application providing TCP, UDP and a RESTful interface for data storage and retrieval. Full buffering of TCP is supported but not exhaustively tested.

