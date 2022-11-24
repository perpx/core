#!/bin/sh
# Usage: run sh test.sh with --hardhat [...hardhat-test-files] --protostar [max-fuzzing-examples, ...protostar-test-files]

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
			echo "max-examples: ${1}" > config.yml
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
	esac
done


