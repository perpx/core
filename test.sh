#!/bin/sh
# Usage: run sh test.sh with --hardhat [...hardhat-test-files] --protostar [...protostar-test-files] --protostar-complex [...protostar-test-files]
# complex protostar files run with 500 iterations


for var in 1 2; do
	case "$1" in
		--hardhat)
			if ! ps aux | grep '[s]tarknet-devnet' > /dev/null; then
				starknet-devnet  > /dev/null 2>&1 &
			fi
			shift
			for var in "$@"; do
				if grep -e "protostar" <<< "$1"; then
					break
				fi
				npx hardhat test "$1"
				shift
			done
			kill %1
			;;
		--protostar)
			shift
			for var in "$@"
			do
				if grep -e "hardhat" <<< "$1"; then
					break
				fi
				protostar test "$var"
				shift
			done
			;;
		--protostar-complex)
			shift
			for var in "$@"
			do
				if grep -e "hardhat" <<< "$1"; then
					break
				fi
				protostar test --fuzz-max-examples 500 "$var"
				shift
			done
			;;
	esac
done


