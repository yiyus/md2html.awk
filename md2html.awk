#!/bin/awk -f

# md2html.awk
# by: Jesus Galan (yiyus) <yiyu.jgl@gmail>, May 2009
# Usage:
# 	md2html file.md > file.html
# Options: -v esc=false to not escape html

function newblock(nblock){
	if(text)
		print "<" block ">" text "</" block ">";
	text = "";
	block = nblock ? nblock : "p";
}

function subinline(tgl, inl){
	while(match($0, tgl)){
		if (inline[ni] == inl)
			ni -= sub(tgl, "</" inl ">");
		else if (sub(tgl, "<" inl ">"))
			inline[++ni] = inl;
	}
}

function dolink(href, lnk){
	# Undo escaped html in uris
	gsub(/&amp;/, "\\&", href);
	gsub(/&lt;/, "<", href);
	gsub(/&gt;/, ">", href);
	# & can be tricky, and not standard:
	gsub(/&/, "\\\\\\&", href);
	gsub(/&/, "\\\\\\&", lnk);
	return "<a href=\"" href "\">" lnk "</a>";
}

BEGIN {
	ni = 0;	# inlines
	nl = 0;	# nested lists
	text = "";
	block = "p";
}

# Escape html
esc != "false" {
	gsub("&", "\\&amp;")
	gsub("<", "\\&lt;")
	gsub(">", "\\&gt;")
}

# Horizontal rules (_ is not in markdown)
/^[ 	]*([-*_] ?)+[ 	]*$/ && text == "" {
	print "<hr>";
	next;
}

# Tables (not in markdown)
# Syntax:
# 		Right Align| 	Center Align	|Left Align
/([ 	]\|)|(\|[ 	])/ {
	if(block != "table")
		newblock("table");
	nc = split($0, cells, "|");
	$0 = "<tr>\n";
	for(i = 1; i <= nc; i++){
		align = "left";
		if(sub(/^[ 	]+/, "", cells[i])){
			if(sub(/[ 	]+$/, "", cells[i]))
				align = "center";
			else
				align = "right";
		}
		sub(/[ 	]+$/,"", cells[i]);
		$0 = $0 "<td align=\"" align "\">" cells[i] "</td>\n";
	}
	$0 = $0 "</tr>";
}

# Ordered and unordered (possibly nested) lists
/^[ 	]*([*+-]|(([0-9]+[\.-]?)+))[ 	]/ {
	newblock("li");
	nnl = 1;
	while(match($0, /^[ 	]/)){
		sub(/^[ 	]/,"");
		nnl++;
	}
	while(nl > nnl)
		print "</" list[nl--] ">";
	while(nl < nnl){
		list[++nl] = "ol";
		if(match($0, /^[*+-]/))
			list[nl] = "ul";
		print "<" list[nl] ">";
	}
	sub(/^([*+-]|(([0-9]+[\.-]?)+))[ 	]/,"");
}

# Multi line list items
block == "li" {
	sub(/^( *)|(	*)/,"");
}

# Code blocks
/^(    |	)/ {
	if(block != "pre")
		newblock("pre");
	sub(/^(    |	)/, "");
	text = text $0 "\n";
	next;
}

# Paragraph
/^$/ {
	newblock();
	while(nl > 0)
		print "</" list[nl--] ">";
}

# Setex-style Headers
# (Plus h3 with underscores.)
/^=+$/ {
	block = "h" 1;
	next;
}

/^-+$/ {
	block = "h" 2;
	next;
}

/^_+$/ {
	block = "h" 3;
	next;
}

# Atx-style headers
/^#/ {
	newblock();
	match($0, /#+/);
	n = RLENGTH;
	if(n > 6)
		n = 6;
	text = substr($0, RLENGTH + 1);
	block = "h" n;
	next;
}

// {
	# Images
	while(match($0, /!\[[^\]]+\]\([^\)]+\)/)){
		split(substr($0, RSTART + 2, RLENGTH - 3), a, /\]\(/);
		sub(/!\[[^\]]+\]\([^\)]+\)/, "<img src=\"" a[2] "\" alt=\"" a[1] "\">");
	}
	# Links
	while(match($0, /\[[^\]]+\]\([^\)]+\)/)){
		split(substr($0, RSTART + 1, RLENGTH - 2), a, /\]\(/);
		sub(/\[[^\]]+\]\([^\)]+\)/, dolink(a[2], a[1]));
	}
	# Auto links (uri matching is poor)
	na = split($0, a, /(^\()|[ 	]|([,\.\)]([ 	]|$))/);
	for(i = 1; i <= na; i++)
		if(match(a[i], /^(((https?|ftp|file|news|irc):\/\/)|(mailto:)).+$/))
			sub(a[i], dolink(a[i], a[i]));
	# Inline
	subinline("(\\*\\*)|(__)", "strong");
	subinline("\\*", "em");
	subinline("`", "code");
	text = text (text ? " " : "") $0;
}

END {
	while(ni > 0)
		text = text "</" inline[ni--] ">";
	newblock();
	while(nl > 0)
		print "</" list[nl--] ">";
}
