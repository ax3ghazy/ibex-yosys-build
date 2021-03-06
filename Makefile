mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(patsubst %/,%,$(dir $(mkfile_path)))
TOP := top_artya7

IBEX_BUILD = ${current_dir}/ibex/build/lowrisc_ibex_top_artya7_0.1

IBEX_INCLUDE = \
        -I$(IBEX_BUILD)/src/lowrisc_prim_assert_0.1/rtl \
        -I$(IBEX_BUILD)/src/lowrisc_prim_util_memload_0/rtl \

IBEX_PKG_SOURCES = \
        $(shell \
                cat ${IBEX_BUILD}/synth-vivado/lowrisc_ibex_top_artya7_0.1.tcl | \
                grep read_verilog | cut -d' ' -f3  | grep _pkg.sv | \
                sed 's@^..@${IBEX_BUILD}@')

IBEX_SOURCES = \
        $(IBEX_PKG_SOURCES) \
        $(shell \
                cat ${IBEX_BUILD}/synth-vivado/lowrisc_ibex_top_artya7_0.1.tcl | \
                grep read_verilog | cut -d' ' -f3 | grep -v _pkg.sv | \
                sed 's@^..@${IBEX_BUILD}@')

VERILOG := ${IBEX_SOURCES}
PARTNAME := xc7a35tcsg324-1
DEVICE  := xc7a50t_test
BITSTREAM_DEVICE := artix7
PCF := ${current_dir}/arty.pcf
SDC := ${current_dir}/arty.sdc
XDC := ${current_dir}/arty.xdc
BUILDDIR := build

all: ${BUILDDIR}/${TOP}.bit

ibex/configure:
	cp prim_generic_clock_gating.sv ibex/build/lowrisc_ibex_top_artya7_0.1/src/lowrisc_prim_generic_clock_gating_0/rtl/prim_generic_clock_gating.sv

patch/symbiflow:
	cp synth /opt/symbiflow/xc7/install/bin/synth
	cp synth.tcl /opt/symbiflow/xc7/install/share/symbiflow/scripts/xc7/synth.tcl

${BUILDDIR}:
	mkdir ${BUILDDIR}

${BUILDDIR}/${TOP}.eblif: | ${BUILDDIR}
	cd ${BUILDDIR} && synth -t ${TOP} -v ${VERILOG} -d ${BITSTREAM_DEVICE} -p ${PARTNAME} -i ${IBEX_INCLUDE} -x ${XDC} -l ${current_dir}/ibex/examples/sw/led/led.vmem > /dev/null

${BUILDDIR}/${TOP}.net: ${BUILDDIR}/${TOP}.eblif
	cd ${BUILDDIR} && pack -e ${TOP}.eblif -d ${DEVICE} -s ${SDC} > /dev/null

${BUILDDIR}/${TOP}.place: ${BUILDDIR}/${TOP}.net
	cd ${BUILDDIR} && place -e ${TOP}.eblif -d ${DEVICE} -p ${PCF} -n ${TOP}.net -P ${PARTNAME} -s ${SDC} > /dev/null

${BUILDDIR}/${TOP}.route: ${BUILDDIR}/${TOP}.place
	cd ${BUILDDIR} && route -e ${TOP}.eblif -d ${DEVICE} -s ${SDC} > /dev/null

${BUILDDIR}/${TOP}.fasm: ${BUILDDIR}/${TOP}.route
	cd ${BUILDDIR} && write_fasm -e ${TOP}.eblif -d ${DEVICE} > /dev/null

${BUILDDIR}/${TOP}.bit: ${BUILDDIR}/${TOP}.fasm
	cd ${BUILDDIR} && write_bitstream -d ${BITSTREAM_DEVICE} -f ${TOP}.fasm -p ${PARTNAME} -b ${TOP}.bit

clean:
	rm -rf ${BUILDDIR}

