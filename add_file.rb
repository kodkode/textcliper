require 'xcodeproj'

project_path = 'textcliper.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the textcliper group
group = project.main_group.find_subpath('textcliper', true)

# Add the new file
file_ref = group.new_reference('textcliper/OnboardingWindow.swift')

# Add to target
target.add_file_references([file_ref])

# Save the project
project.save

puts "✅ OnboardingWindow.swift added to project"
