File.read("_taglist.txt").split("\n").each do |tag|
	File.write "#{tag}.html", <<-EOF
---
layout: tagpage
tag: #{tag}
permalink: /tags/#{tag}
---
	EOF
end
