#!/bin/bash

# Prompt for Year and Month
read -p "Enter Year and Month (YYYY.MM): " year_month

# Validate Year and Month format
if ! [[ $year_month =~ ^[0-9]{4}\.[0-9]{2}$ ]]; then
    echo "Invalid format for Year and Month. Please use YYYY.MM (e.g., 2024.08)"
    exit 1
fi

# Prompt for TAG
read -p "Enter TAG: " tag

# Update the Apptainer.def file
sed -i -e "s/export YEAR\.MONTH=.*/export YEAR.MONTH=${year_month}/" \
       -e "s/year_month=.*/year_month=${year_month}/" \
       -e "s/export TAG=.*/export TAG=${tag}/" Apptainer.def

# Confirm the updates
if (grep -q "YEAR\.MONTH=${year_month}" Apptainer.def || grep -q "year_month=${year_month}" Apptainer.def) && \
   grep -q "TAG=${tag}" Apptainer.def; then
    echo "Successfully updated YEAR.MONTH to ${year_month} and TAG to ${tag} in Apptainer.def"
else
    echo "Failed to update Apptainer.def"
    exit 1
fi


# Echo the VERSION variable
#echo "VERSION=${year_month}.${tag}.0"

# Construct the VERSION string
VERSION="${year_month}.${tag}.0"
echo "VERSION=${VERSION}"

# Update the build-container.slurm file
sed -i "s/export APSIM_VERSION=\".*\"/export APSIM_VERSION=\"${VERSION}\"/" build-container.slurm

# Confirm the update in build-container.slurm
if grep -q "export APSIM_VERSION=\"${VERSION}\"" build-container.slurm; then
    echo "Successfully updated APSIM_VERSION to \"${VERSION}\" in build-container.slurm"
else
    echo "Failed to update build-container.slurm"
    exit 1
fi

# Prompt for job submission
read -p "Would you like to submit the container build Slurm job? (Yes/No): " submit_job

if [[ ${submit_job,,} == "yes" ]]; then
    sbatch build-container.slurm
    echo "Container build job submitted."
else
    echo "No problem, will leave it with you to submit the build script."
fi

echo "Script execution complete."
