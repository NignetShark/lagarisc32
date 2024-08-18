#!/bin/bash

PY_VENV_ACTIVATE=../../../.venv/bin/activate

# Check if python venv activate script exists
if [ ! -f $PY_VENV_ACTIVATE ]; then
    echo "Python virtual environnement was not created. Abort"
    exit -1
fi

# If not yet in a virtual env, then activate it.
# Note: cocotb & riscof must be installed with pip.
if [[ "$VIRTUAL_ENV" = "" ]]
then
    . $PY_VENV_ACTIVATE
fi

# Run riscof
riscof --verbose info run --config ./config.ini --suite ./riscv-arch-test/riscv-test-suite/rv32i_m --env ./riscv-arch-test/riscv-test-suite/env

