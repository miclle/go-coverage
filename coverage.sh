#!/bin/sh
# Generate test coverage statistics for Go packages.
# Usage: sh coverage.sh --xml --html
# default exec: go test -v -covermode=count -coverprofile=.cover/xxx.cover package_name
# Add go test other args: export GO_TEST_ARGS=-tags=embed
# Except packages like this: export EXCEPT_PKGS="github.com/miclle/pkgs"

set -e

workdir=.cover
profile="$workdir/cover.out"
mode=count
temp_test_file_name="temp_coverage_test.go"

dividing(){
    i=1; while [ $i -le 80 ]; do printf "-"; i=$((i+1)); done
    printf "\n"
}

add_temp_test_file_to_dir() {
    for file in `find $1 -name "*.go"`; do
        pkgname=$(cat $file | grep "^package " | awk 'NR==1{print $2}')
        path=$(dirname "$file")
        echo "package $pkgname" > $path/$temp_test_file_name
    done
}

clean_and_check_exit(){
    find `pwd` -name "*$temp_test_file_name" | xargs rm
    if [ $1 != 0 ]; then
        rm -rf "$workdir"
        dividing
        echo "Have $1 errors, then exit!"
        dividing
        exit 1
    fi
}

generate_cover_data() {
    rm -rf "$workdir"
    mkdir "$workdir"

    add_temp_test_file_to_dir `pwd`

    exit_count=0

    for pkg in "$@"; do
        dividing
        f="$workdir/$(echo $pkg | tr / -).cover"
        if !(go test $GO_TEST_ARGS -covermode="$mode" -coverprofile="$f" "$pkg"); then
            exit_count=`expr $exit_count + 1`
        fi
    done

    clean_and_check_exit $exit_count

    echo "mode: $mode" > "$profile"
    if grep -h -v "^mode:" "$workdir"/*.cover >> "$profile"; then
        exit_count=0
    fi

    clean_and_check_exit $exit_count
}

generate_xml_report(){
    go get github.com/axw/gocov/gocov
	go get github.com/AlekSi/gocov-xml
    gocov convert "$profile" | gocov-xml > coverage.xml
}

stats_coverage() {
  printf "\n%-17s Code Coverage Stats\n"
  dividing
  cat coverage.html | grep "^<tr id=\"s_pkg_" | awk -F '[><]' '{printf "%-40s %-10s %-10s \n", $9, $19, $27}'
  dividing
  cat coverage.html | grep "^<tr><td><code>Report Total</code>" | awk -F '["><"]' '{printf "%-40s %-10s %-10s \n", "Report Total", $17, $27}'
}

generate_html_report(){
    go get github.com/axw/gocov/gocov
	go get gopkg.in/matm/v1/gocov-html
    gocov convert "$profile" | gocov-html > coverage.html
    stats_coverage
}

generate_coverage(){
    if [ -n "$EXCEPT_PKGS" ]; then
        echo "except packages:" $EXCEPT_PKGS
        generate_cover_data $(go list ./... | grep -Ev $EXCEPT_PKGS)
    else
        generate_cover_data $(go list ./...)
    fi

    for arg in "$@"; do
        case "$arg" in
            "")
               ;;
            --html )
              generate_html_report  ;;
            --xml )
              generate_xml_report  ;;
              *)
            echo >&2 "error:invalid option:$1"; exit 1;;
        esac
    done
}

generate_coverage $@
