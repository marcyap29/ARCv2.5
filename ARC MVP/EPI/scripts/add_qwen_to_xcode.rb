#!/usr/bin/env ruby
require 'xcodeproj'

# Path to the Xcode project
project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Runner target
runner_target = project.targets.find { |target| target.name == 'Runner' }

if runner_target.nil?
  puts "❌ Error: Could not find Runner target"
  exit 1
end

# Find the Runner group
runner_group = project.main_group.groups.find { |group| group.display_name == 'Runner' }

if runner_group.nil?
  puts "❌ Error: Could not find Runner group"
  exit 1
end

# Check if QwenBridge.swift already exists in the project
existing_file = runner_group.files.find { |file| file.display_name == 'QwenBridge.swift' }

if existing_file
  puts "⚠️  QwenBridge.swift already exists in project, skipping..."
else
  # Add QwenBridge.swift to the Runner group
  file_ref = runner_group.new_reference('ios/Runner/QwenBridge.swift')
  file_ref.last_known_file_type = 'sourcecode.swift'
  file_ref.source_tree = '<group>'

  # Add to compile sources build phase
  runner_target.source_build_phase.add_file_reference(file_ref)

  puts "✅ Added QwenBridge.swift to Runner target"
end

# Save the project
project.save

puts "✅ Xcode project updated successfully"
puts "   Next steps:"
puts "   1. Open ios/Runner.xcworkspace in Xcode"
puts "   2. Verify QwenBridge.swift appears in Runner group"
puts "   3. Clean build folder (Shift+Cmd+K)"
puts "   4. Build project"