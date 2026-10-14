#!/bin/sh
# Wakes Novatek NT36672C DDIC and takes panel out of blank/sleep

echo "0 1 05 01 00 00 00 00 02 11 00" > /proc/mipi_reg # Exit Sleep Mode
usleep 120000
echo "0 1 05 01 00 00 00 00 02 29 00" > /proc/mipi_reg # Set Display ON
echo "0 1 05 01 00 00 00 00 02 13 00" > /proc/mipi_reg # Normal Display Mode
echo "0 1 15 01 00 00 00 00 02 51 FF" > /proc/mipi_reg # Brightness Max
echo "0 1 15 01 00 00 00 00 02 53 2C" > /proc/mipi_reg # Display Control
echo "0 1 15 01 00 00 00 00 02 55 00" > /proc/mipi_reg # CABC OFF
