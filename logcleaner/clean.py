#
# clean.py
# Andrew Martin, Appgate 2024
#
# This python script takes in a zip file log bundle from both Appgate Clients and Appliances, extracts the file (recursively), and searches all files
# ending in .log or containing "syslog" for Redex matching IP (v4/6) and hostnames, and scrubs hosts with string given.
# 
# Usage:  python3 clean.py <log-zipfile>
#

import re
import os
import zipfile
import sys
import gzip
import shutil

# Grab zipfile of log bundle as parameter 1
parameters = sys.argv[1:]
if len(parameters) >= 1:
    logfile = parameters[0]
    logfile_short = os.path.splitext(os.path.basename(logfile))[0]
else:
    print("Please provide the directory path as a parameter.")
    sys.exit(1)  # Exit with error code 1


# Unzip Logfile
def unzip_logfile(logfile):
  if logfile.endswith('.zip'):
    print(f"Successfully Found: {logfile}")
    try:
      with zipfile.ZipFile(logfile, 'r') as zip_ref:
        zip_ref.extractall(logfile_short)
      print(f"Successfully extracted: {logfile}")
    except zipfile.BadZipFile:
      print(f"Error: {logfile} is not a valid zip file")
      sys.exit(1)  # Exit with error code 1
    except Exception as e:
      print(f"An error occurred while extracting {logfile}: {e}")
      sys.exit(1)  # Exit with error code 1
  else:
     print(f"Error: This not a valid zip file")
     sys.exit(1)  # Exit with error code 1
  unzip_recursive(logfile_short)

# Unzip/gzip log files contained in log bundle
def unzip_recursive(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.zip'):
                zip_file_path = os.path.join(root, file)
                unzip_directory = os.path.splitext(zip_file_path)[0]
                try:
                    with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
                        zip_ref.extractall(unzip_directory)
                        os.remove(zip_file_path)
                    print(f"Successfully extracted: {zip_file_path}")
                except zipfile.BadZipFile:
                    print(f"Error: {zip_file_path} is not a valid zip file")
                except Exception as e:
                    print(f"An error occurred while extracting {zip_file_path}: {e}")
            if file.endswith('.gz'):
                gz_file_path = os.path.join(root, file)
                unpacked_file_path = os.path.splitext(gz_file_path)[0]
                try:
                    with gzip.open(gz_file_path, 'rb') as gz_file:
                        with open(unpacked_file_path, 'wb') as unpacked_file:
                            unpacked_file.write(gz_file.read())
                            os.remove(gz_file_path)
                    print(f"Successfully unpacked: {gz_file_path}")
                except Exception as e:
                    print(f"An error occurred while unpacking {gz_file_path}: {e}")
    

# Function searches file for Regex of hostnames/ips and replaces with given string
def replace_ipv6_fqdn(file_path):
    # Regex of ipv6, and fqdn
    ipv6_pattern = r'\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b'
    fqdn_pattern = r'\b(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?\b'

    try:
        with open(file_path, 'r') as file:
            file_content = file.read()

        ipv6_content = re.sub(ipv6_pattern, "REPLACED_IPV6", file_content)
        fqdn_content = re.sub(fqdn_pattern, "REPLACED_FQDN", ipv6_content)


        with open(file_path, 'w') as file:
            file.write(fqdn_content)

        print(f"Replacement successful in {file_path}")

    except FileNotFoundError:
        print(f"File '{file_path}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")


def replace_ipv4(file_path):
    # Regular expression to match IPv4 addresses
    ipv4_pattern = re.compile(r'\b(\d{1,3}\.){1}\d{1,3}\.\d{1,3}\b')
    with open(file_path, 'r') as file:
        content = file.read()

    # Replace the first two octets of each IPv4 address with 'A.A.'
    modified_content = ipv4_pattern.sub(lambda match: 'A.A.' + match.group(0)[match.group(0).rindex('.')+1:], content)

    with open(file_path, 'w') as file:
        file.write(modified_content)

def replace_cn_in_file(file_path):
    # Define the pattern to match CN=<somestring>
    pattern = r'(CN=.{4})[^,]*'

    # Define a function to replace matched strings
    def replace(match):
        # Extract the first 4 characters after 'CN='
        first_four_chars = match.group(1)[3:7]
        # Replace the matched string with 'CN=' followed by the first four characters and a comma
        return 'CN=' + first_four_chars + ','

    # Read content from the file
    with open(file_path, 'r') as file:
        content = file.read()

    # Perform the replacement
    modified_content = re.sub(pattern, replace, content)

    # Write modified content back to the same file
    with open(file_path, 'w') as file:
        file.write(modified_content)



# Unzip logfile to temp location for processing
unzip_logfile(logfile)

# Get list of files in temp location and process them.  All files ending in .log of contain "syslog" will be searched
file_list = []
for root, _, filenames in os.walk(logfile_short):
  for filename in filenames:
    file_list.append(os.path.join(root, filename))

for file in file_list:
    if "lastlog" in file or "wtmp" in file:
        os.remove(file)
        continue
    if file.endswith('.log') or "syslog" in file:
      print ("processing file " + file)
      replace_ipv4(file)
      replace_ipv6_fqdn(file)
      replace_cn_in_file(file)


# Create new zip file of scrubed content
shutil.make_archive(logfile_short + "-clean", 'zip', logfile_short)
print("New zipfile created:  " + logfile_short + "-clean.zip")

# Cleanup/Delete temp working directory
shutil.rmtree(logfile_short)