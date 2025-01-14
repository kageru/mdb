#!/bin/sh

blog_domain='https://blog.kageru.moe/'

output() {
    echo "$1" >> index.html
}

output_rss() {
    echo "$1" >> rss.xml
}

add_header() {
    output '<h1>Blog index</h1><table id="linklist">'
    output_rss '<?xml version="1.0" encoding="UTF-8" ?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
  <author><name>kageru</name></author>
  <title>kageru’s blog</title>'
    output_rss "  <link href=\"$blog_domain\" rel=\"self\" type=\"application/atom+xml\"/>
  <description>kageru’s blog</description>"
}

add_footer() {
    html_entry "legacy" "before 2020" "Older posts"
    output '</table>'
    output_rss '</feed>'
}

html_entry() {
    output '<tr>'
    path="$1"
    time="$2"
    title="$3"
    output "<td class=\"first\"><a href=\"$path\">$title</a></td>"
    output "<td class=\"second\">$time</td></tr>"
}

rss_entry() {
    # The content is the output minus the first line
    # (which would otherwise be a redundant title in most rss readers)
    # and with escaped html.
    # The sed expression is stolen from https://stackoverflow.com/questions/12873682/12873723#12873723
    output_rss "  <entry>
    <title>$1</title>
    <link>$blog_domain$2</link>
    <link href=\"$blog_domain$2\" type=\"text/html\" title=\"$1\"/>
    <content type=\"html\" xml:base=\"$blog_domain$2\">
      $(tail -n+2 "$2" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    </content>
  </entry>"
}

create_entry() {
    path="$9"
    outpath="content/$(basename "$path" .md).html"
    # convert new markdown posts to html
    pandoc "$path" -t html -f markdown -o "$outpath"
    # then add it to the index
    title="$(rg 'h1' "$outpath" | head -n1 | rg -o '(?<=>).*(?=<)' --pcre2)"
    created=$(git log --follow --format=%as "$path" | tail -1)
    html_entry "$outpath" "created on $created" "$title"
    rss_entry "$title" "$outpath"
}

has_updates() {
    git fetch &> /dev/null
    diff="$(git diff master origin/master)"
    if [ "$diff" ]; then
        return 0
    else
        return 1
    fi
}

cd /home/nginx/html/blog
if has_updates; then
    git pull &> /dev/null
    rm -f index.html
    rm -f rss.xml
    add_header
    ls -ltu src/*.md | tail -n+1 | while read f; do create_entry $f; done
    add_footer
    # Human-readable output for the cron notification
    echo 'Updated blog to:'
    git log -1
fi
