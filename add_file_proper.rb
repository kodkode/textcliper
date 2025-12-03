require 'xcodeproj'

project_path = 'textcliper.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'textcliper' }

# Find or create the textcliper group
group = project.main_group.groups.find { |g| g.path == 'textcliper' }

if group.nil?
  puts "❌ Could not find textcliper group"
  exit 1
end

# Check if file already exists
existing_file = group.files.find { |f| f.path == 'OnboardingWindow.swift' }

if existing_file
  puts "⚠️  OnboardingWindow.swift already exists in project"
  exit 0
end

# Add the new file reference
file_ref = group.new_file('OnboardingWindow.swift')

# Add to target's source build phase
target.source_build_phase.add_file_reference(file_ref)

# Save the project
project.save

puts "✅ OnboardingWindow.swift added to project successfully"
