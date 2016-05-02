File.read("_taglist.txt").split("\n").each do |tag|
	File.write "tags/#{tag}.html", <<-EOF
---
layout: tagpage
tag: #{tag}
permalink: /tags/#{tag}
---
	EOF
end
