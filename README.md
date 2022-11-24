# Perpx

The cairo contracts used for PerpX, a perpetual decentralized exchange hosted on Starknet.

# Testing

In order to launch the tests written in protostar, use the shell file `test.sh`. The following arguments should be provided in the following order:

-   `--protostar` flag: indicates the use of protostar for the test.
-   `max-fuzzing-examples`: the maximum amount of examples when fuzzing
-   `protostar-test-files`: the path to the test files. To check the required format, run `protostar test --help`

Example: `sh test.sh --protostar 20 'protostar-test/perpx-v1-exchange/*/owner_test.cairo'` will run all tests for the owner's functions.
