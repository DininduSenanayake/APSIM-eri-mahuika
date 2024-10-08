import os

# Directory containing config files
CONFIG_DIR = "ConfigFiles"
# Directory for output database files
OUTPUT_DIR = "OutputDatabases"

# Get list of config files (limit to 10 for testing)
CONFIG_FILES = [f for f in os.listdir(CONFIG_DIR) if f.endswith('.txt')][:10]

# Apptainer settings
APPTAINER_IMAGE = "/agr/persist/projects/2024_apsim_improvements/apsim-simulations/container/apsim-2024.08.7572.0.aimg"

rule all:
    input:
        expand(os.path.join(OUTPUT_DIR, "{config}.db"), config=[os.path.splitext(f)[0] for f in CONFIG_FILES]),
        os.path.join(OUTPUT_DIR, "database_list.txt")

rule run_apsim:
    input:
        config = os.path.join(CONFIG_DIR, "{config}.txt")
    output:
        db = os.path.join(OUTPUT_DIR, "{config}.db")
    resources:
        mem_mb = 8000,
        cpus = 4
    shell:
        """
        module load Apptainer
        export APPTAINER_BIND="/agr/scratch,/agr/persist"
        apptainer exec {APPTAINER_IMAGE} Models --apply {input.config}
        mv {wildcards.config}.db {output.db}
        echo "{wildcards.config}.db" >> {OUTPUT_DIR}/database_list.txt
        """

rule create_db_list:
    input:
        expand(os.path.join(OUTPUT_DIR, "{config}.db"), config=[os.path.splitext(f)[0] for f in CONFIG_FILES])
    output:
        os.path.join(OUTPUT_DIR, "database_list.txt")
    run:
        with open(output[0], 'w') as f:
            for db in input:
                f.write(f"{os.path.basename(db)}\n")
