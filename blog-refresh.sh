#!/bin/sh

output() {
    echo "$1" >> index.html
}

add_header() {
    output '<h1>Blog index</h1>'
    output '<table id="linklist">'
}

add_footer() {
    html_entry "legacy" "before 2020" "Older posts"
    output '</table>'
}

html_entry() {
    output '<tr>'
    path="$1"
    time="$2"
    title="$3"
    output "<td class=\"first\"><a href=\"$path\">$title</a></td>"
    output "<td class=\"second\">$time</td></tr>"
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
    add_header
    ls -ltu src/*.md | tail -n+1 | while read f; do create_entry $f; done
    add_footer
    # Human-readable output for the cron notification
    echo 'Updated blog to:'
    git log -1
fi
