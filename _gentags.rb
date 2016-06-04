require 'yaml'
tags = []
Dir.glob('_posts/*.md').each do |file|
	begin
		yaml_s = File.read(file).split(/^---$/)[1]
		yaml_h = YAML.load(yaml_s)
		tags += yaml_h['tags']
	rescue
	end
end

tags.map(&:downcase).uniq.each do |tag|
	File.write "tags/#{tag}.html", <<-EOF
---
layout: tagpage
tag: #{tag}
permalink: /tags/#{tag}
---
	EOF
end
