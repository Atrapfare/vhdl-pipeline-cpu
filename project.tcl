proc collect_vhdl {dir pattern} {
    set results {}
    # Dateien im aktuellen Ordner
    set files [glob -nocomplain -types f -directory $dir $pattern]
    lappend results {*}$files

    # rekursiv durch Unterordner
    set subdirs [glob -nocomplain -types d -directory $dir *]
    foreach d $subdirs {
        lappend results {*}[collect_vhdl $d $pattern]
    }

    return $results
}

# Projekt erstellen
create_project ro2_abgabe ./.project -part xc7z010clg400-1 -force

# SRC-Files
set src_files [collect_vhdl "./src" "*.vhd"]

# Be explicit about the fileset to avoid accidental mis-classification.
add_files -fileset sources_1 $src_files

# Vivado sometimes ends up missing individual files when re-sourcing into an existing project.
# Ensure critical sources are present.
set must_have {
    ./src/types.vhd
    ./src/pkg/io_types_pkg.vhd
    ./src/ControlUnit/controlunit_pkg.vhd
    ./src/HazardDetection/hazard_detector.vhd
}
foreach f $must_have {
    if {[file exists $f]} {
        add_files -fileset sources_1 -norecurse $f
    }
}

# Simulation sources (testbenches + helper architectures/configurations)
# Note: some tests are not named *_tb.vhd (e.g. cpu_flush_tb.vhd), and some helper files
# (e.g. alternate InstructionMemory architectures) must also be compiled for XSim elaboration.
set sim_files [collect_vhdl "./sim" "*.vhd"]
add_files -fileset sim_1 $sim_files

# Compile Order aktualisieren
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
