# APSIM-eri-mahuika
Deploy APSIM on eRI and Mahuika clusters




<details>
<summary>June: Notes on how the config files were generated</summary>

* Extract SoilNames from CSV with `SoilNames <- as.vector(unlist(read.csv("SubsetSoilName.csv"))`
* R script generate the config file/s ( one config file per Soil sample  per Weather file)
  * Alsmost all of the SoilNames exist. Weather files willl change but it shouldn't be a problem as we "catch" by them by using the unique `.met` file extension
* config files should have both the soil names and weather names ( that pattern will not change) . In R scrip Soli name is `$var1`
* Config files should be on the curernt working directory. ( hard-coded on APSIM)
* The base Config file should contain the correct name of the soil library to load soils from, as well as the correct Example file containing the simulations to run on the correct soil and weather files

</details>


# 1-apptainer-build

### How to launch the apptainer build

1. Run `./updateversion-and-build.sh` and respond to prompts 
2. Once the image built was completed, execute "clean.sh"

#### What does the `updateversion-and-build.sh` do 

1. It will ask to define the APSIM Release information ( .deb version). Current release branch has the format of "2024.07.7572.0" and the prompts will request to provide information for "2024.07" in `Enter Year and Month (YYYY.MM)` followed by `Enter TAG:` which is equivalent to  `7572` in above example
2. This will auto-update the corresponding fields in **Apptainer.def** under `%arguments`, add the tag to `curl --silent -o ${APPTAINER_ROOTFS}/ApsimSetup.deb https://builds.apsim.info/api/nextgen/download/${TAG}/Linux` and complete the `%setup` on the same def file
3. Then it will ask `Would you like to submit the container build Slurm job? (Yes/No):` which we recommend answering `Yes`as it will auto update the `export APSIM_VERSION=` and   `export CACHETMPDIR=` based on the cluster of choice

#### Path to new container image. 

We are using  a relative path as defined in `build-container.def`

```bash
13	export IMAGE_PATH="../../apsim-simulations/container/"
```

[apptainer-build.webm](https://github.com/user-attachments/assets/a342fcd4-55e9-4615-896b-7eac46368e84)


# 2-apsim-module

### Generate the .lua file
`generate_lua.py` script does the following:

1. Prompts the user to enter the name of the container image.
2. Validates the image name format to ensure it follows the convention "apsim-YYYY.MM.XXXX.Y.aimg".
3. Extracts the version from the image name.
4. checks if the image file exists in the "../../container/" directory.
5. If everything is valid, it creates a new .lua file with the filename "Version.lua" (e.g., "2024.08.7572.0.lua") in the `APSIM/`directory.
6. The generated .lua file includes the correct version in the "whatis" statement.

To use this script: Run `./generate_lua.py` in the same directory where you want the .lua files to be created.

### This module file (.lua) does the following

This module file does the following:

1. Provides basic information about the module using whatis statements.
2. Adds `/usr/local/bin` and `/usr/bin` from the container to the system's `PATH`.
3. Sets the `R_LIBS_USER` environment variable to `/usr/local/lib/R/site-library`.
4. Creates aliases for executables within the container, so they can be run directly from the command line.
5. Sets an environment variable `APSIM_IMAGE` with the path to the Apptainer image.

### How to use the module:

Adjust the list of executables in the `create_exec_alias` section as needed for your specific use case.

```bash
module use APSIM/
module load APSIM/2024.08.7572.0
```
* If the version is not specified, `module load APSIM` will load the latest version



# 3-generate-config-files

## Use `generate_apsim_configs.R` to generate the Config files

### `generate_apsim_configs.py` script does the following:

1. reads soil names from the `CSV` file.
2. gets all `.met` files from the **/Weather** directory.
3. reads the base config file.
4. generates a new config file for each combination of soil name and weather file.
5. replaces the placeholders in the config with the correct soil name and weather file name.
6. saves each new config file with a name that includes both the weather file name and soil name.

.
### To use this script:

1. Make sure you have the SubsetSoilName.csv, Weather directory with .met files, and ExampleConfig.txt in the same directory as the script (or adjust the paths in the script).
2. Create a directory named `ConfigFiles` for the output (or change the output_dir in the script).
3. `./generate_apsim_configs.py`

>This script will generate a separate config file for each combination of soil name and weather file, naming each file appropriately and placing it in the specified output directory, `ConfigFiles`


# 4-create-apsimx-files

## Generate .apsimx and .db placeholder files from Config.txt files

1. Make sure to check the container image vesion (.aimg file) and double the name of the ExampleConfig file ( template has `ExampleConfig.txt` )
3. `#SBATCH --time` variable will require revision based on the number of Config files. It takes ~25seconds per file
2. Then submit the Slurm script with `sbatch create_apsimx.sl`
   - This is a serial process  due to https://github.com/DininduSenanayake/APSIM-eri-mahuika/issues/31

### Note on `if` `else` statement

`if [ -f "$file" ] && [ "$file" != "ExampleConfig.txt" ]; then:`

a. `[ -f "$file" ]`: Checks if the current `$file` is a regular file (not a directory or other special file).
b. `[ "$file" != "ExampleConfig.txt" ]`: Checks if the current `$file` is not named `"ExampleConfig.txt"`.

Both conditions must be true for the code inside the if block to execute.

# 5-slurm-array

## Auto-generate the `#SBATCH --array` variable and Submit the Slurm array 

1. Run `count_apsimxfiles_and_array.sh` script first which will generate the `#SBATCH --array` variable with the number of array tasks based on the number of Config files ( and .db placeholder files)
2. Then submit the array script with `sbatch array_create_db_files.sl`

# 6-db-file-sorter

### Sort .db files based on file size

`db-file-sort.py` does the following

1. It sets up the source directory and creates PASSED and FAILED directories if they don't exist.
2. It defines the size threshold as 20MB (converted to bytes).
3. terates through all files in the source directory.
4. For each .db file, it checks the file size:

   - If the size is greater than 20MB, it moves the file to the `PASSED` directory.
   - If the size is less than or equal to 20MB, it moves the file to the `FAILED` directory.
5. It prints a message for each file moved and a completion message at the end.


To use this script:

* Replace `source_dir = '.'` with the actual path to your directory containing the .db files.

# 7-snakemake

#### `.slurm` script in this directory and the one in `../4-slurm-array` will:

1. Process 10 config files.
2. Use 4 CPUs and 8GB of memory per job.
3. Save Slurm output files in the format %A_%a.out in the "slurmlogs" directory.
4. Save output database files in the "OutputDatabases" directory.
5. Create a file named "database_list.txt" in the "OutputDatabases" directory, containing the names of all generated database files.

To load the database files in Python later, we can use the "database_list.txt" file:

```python
with open('OutputDatabases/database_list.txt', 'r') as f:
    database_files = [line.strip() for line in f]
```

