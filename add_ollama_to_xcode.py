import re
import uuid
import sys

# File config
file_name = "OllamaService.swift"
file_type = "sourcecode.swift"

# Read the project file
try:
    with open('textclipper.xcodeproj/project.pbxproj', 'r') as f:
        content = f.read()
except FileNotFoundError:
    # Try the alternate naming if the first one fails
    with open('textcliper.xcodeproj/project.pbxproj', 'r') as f:
        content = f.read()

# Check if file already exists
if f"/* {file_name} */" in content:
    print(f"⚠️  {file_name} already exists in project")
    sys.exit(0)

# Generate UUIDs for the new file
file_ref_uuid = uuid.uuid4().hex[:24].upper()
build_file_uuid = uuid.uuid4().hex[:24].upper()

# Find the PBXFileReference section and add our file reference
file_ref_pattern = r'(\/\* Begin PBXFileReference section \*\/)'
file_ref_entry = f'\t\t{file_ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {file_name}; sourceTree = "<group>"; }};\n'

content = re.sub(file_ref_pattern, r'\1\n' + file_ref_entry, content)

# Find the PBXBuildFile section and add our build file entry
build_file_pattern = r'(\/\* Begin PBXBuildFile section \*\/)'
build_file_entry = f'\t\t{build_file_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};\n'

content = re.sub(build_file_pattern, r'\1\n' + build_file_entry, content)

# Find the textclipper group (folder) and add our file to it
# Look for the group defined by /* textclipper */ 
match = re.search(r'\/\* textcliper \*\/ = {[^}]+children = \(([^)]+)\);', content, re.DOTALL)

if match:
    children_section = match.group(1)
    # Add our file reference to the children
    new_children = children_section.rstrip() + f'\n\t\t\t\t{file_ref_uuid} /* {file_name} */,'
    content = content.replace(children_section, new_children)
else:
    print("❌ Could not find textclipper group")
    sys.exit(1)

# Find the Sources build phase and add our file
sources_pattern = r'(\/\* Sources \*\/ = {[^}]+files = \()([^)]+)(\);)'
match = re.search(sources_pattern, content, re.DOTALL)

if match:
    files_section = match.group(2)
    new_files = files_section.rstrip() + f'\n\t\t\t\t{build_file_uuid} /* {file_name} in Sources */,'
    content = content.replace(files_section, new_files)
else:
    print("❌ Could not find Sources build phase")
    sys.exit(1)

# Write back the modified project file
try:
    with open('textclipper.xcodeproj/project.pbxproj', 'w') as f:
        f.write(content)
except FileNotFoundError:
    with open('textcliper.xcodeproj/project.pbxproj', 'w') as f:
        f.write(content)

print(f"✅ Added {file_name} to project")
