import re
import uuid

# Read the project file
with open('textcliper.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate UUIDs for the new file
file_ref_uuid = uuid.uuid4().hex[:24].upper()
build_file_uuid = uuid.uuid4().hex[:24].upper()

# Find the PBXFileReference section and add our file reference
file_ref_pattern = r'(\/\* Begin PBXFileReference section \*\/)'
file_ref_entry = f'\t\t{file_ref_uuid} /* OnboardingWindow.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OnboardingWindow.swift; sourceTree = "<group>"; }};\n'

content = re.sub(file_ref_pattern, r'\1\n' + file_ref_entry, content)

# Find the PBXBuildFile section and add our build file entry
build_file_pattern = r'(\/\* Begin PBXBuildFile section \*\/)'
build_file_entry = f'\t\t{build_file_uuid} /* OnboardingWindow.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* OnboardingWindow.swift */; }};\n'

content = re.sub(build_file_pattern, r'\1\n' + build_file_entry, content)

# Find the textcliper group (folder) and add our file to it
# Look for the pattern where AppDelegate.swift is listed
group_pattern = r'(.*AppDelegate\.swift in Resources.*?\n.*?children = \()(.*?)(\);)'
match = re.search(r'\/\* textcliper \*\/ = {[^}]+children = \(([^)]+)\);', content, re.DOTALL)

if match:
    children_section = match.group(1)
    # Add our file reference to the children
    new_children = children_section.rstrip() + f'\n\t\t\t\t{file_ref_uuid} /* OnboardingWindow.swift */,'
    content = content.replace(children_section, new_children)

# Find the Sources build phase and add our file
sources_pattern = r'(\/\* Sources \*\/ = {[^}]+files = \()([^)]+)(\);)'
match = re.search(sources_pattern, content, re.DOTALL)

if match:
    files_section = match.group(2)
    new_files = files_section.rstrip() + f'\n\t\t\t\t{build_file_uuid} /* OnboardingWindow.swift in Sources */,'
    content = content.replace(files_section, new_files)

# Write back the modified project file
with open('textcliper.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print(f"✅ Added OnboardingWindow.swift to project")
print(f"   File ref UUID: {file_ref_uuid}")
print(f"   Build file UUID: {build_file_uuid}")
