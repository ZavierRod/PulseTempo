require 'xcodeproj'

project_path = 'PulseTempo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find targets
main_target = project.targets.find { |t| t.name == 'PulseTempo' }
widget_target = project.targets.find { |t| t.name == 'PulseTempoWidgetExtension' || t.name == 'PulseTempoWidget' }

if main_target.nil? || widget_target.nil?
  puts "Could not find targets: Main: #{main_target&.name}, Widget: #{widget_target&.name}"
  exit 1
end

# Find the file in the project
group = project.main_group.find_subpath(File.join('PulseTempo', 'Models'), true)
file_path = 'PulseTempo/Models/PulseTempoWidgetAttributes.swift'

# Add file reference if it doesn't exist
file_ref = group.files.find { |f| f.path == 'PulseTempoWidgetAttributes.swift' }
if file_ref.nil?
  file_ref = group.new_file('PulseTempoWidgetAttributes.swift')
end

# Add to main target
unless main_target.source_build_phase.files_references.include?(file_ref)
  main_target.add_file_references([file_ref])
  puts "Added to main target"
end

# Add to widget target
unless widget_target.source_build_phase.files_references.include?(file_ref)
  widget_target.add_file_references([file_ref])
  puts "Added to widget target"
end

project.save
puts "Successfully added shared file to both targets"
