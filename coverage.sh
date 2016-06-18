#!/bin/sh
# Generate test coverage statistics for Go packages.
# Usage: sh coverage.sh --xml
# default exec: go test -v -covermode=count -coverprofile=.cover/xxx.cover package_name
# Add go test other args: export GO_TEST_ARGS=-tags=embed

set -e

workdir=.cover
profile="$workdir/cover.out"
mode=count
temp_test_file_name="temp_coverage_test.go"

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
        echo "Have $1 errors, then exit!"
        exit 1
    fi
}

generate_cover_data() {
    rm -rf "$workdir"
    mkdir "$workdir"

    add_temp_test_file_to_dir `pwd`

    exit_count=0

    for pkg in "$@"; do
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

generate_html_report(){
    go get github.com/axw/gocov/gocov
	go get gopkg.in/matm/v1/gocov-html
    gocov convert "$profile" | gocov-html > coverage.html
}

generate_cover_data $(go list ./...)
    case "$1" in
        "")
           ;;
        --html )
          generate_html_report  ;;
        --xml )
          generate_xml_report  ;;
          *)
        echo >&2 "error:invalid option:$1"; exit 1;;
    esac
