#!/bin/sh
#
# Copyright (C) 2006 Martin Waitz <tali@admingilde.org>
#

test_description='test transitive info/alternate entries'
. ./test-lib.sh

test_expect_success 'preparing first repository' '
	test_create_repo A && (
		cd A &&
		echo "Hello World" > file1 &&
		git add file1 &&
		git commit -m "Initial commit" file1 &&
		git repack -a -d &&
		git prune
	)
'

test_expect_success 'preparing second repository' '
	git clone -l -s A B && (
		cd B &&
		echo "foo bar" > file2 &&
		git add file2 &&
		git commit -m "next commit" file2 &&
		git repack -a -d -l &&
		git prune
	)
'

test_expect_success 'preparing third repository' '
	git clone -l -s B C && (
		cd C &&
		echo "Goodbye, cruel world" > file3 &&
		git add file3 &&
		git commit -m "one more" file3 &&
		git repack -a -d -l &&
		git prune
	)
'

# Note: These tests depend on the hard-coded value of 5 as the maximum depth
# we will follow recursion. We start the depth at 0 and count links, not
# repositories. This means that in a chain like:
#
#   A --> B --> C --> D --> E --> F --> G --> H
#      0     1     2     3     4     5     6
#
# we are OK at "G", but break at "H", even though "H" is actually the 8th
# repository, not the 6th, which you might expect. Counting the links allows
# N+1 repositories, and counting from 0 to 5 inclusive allows 6 links.
#
# Note also that we must use "--bare -l" to make the link to H. The "-l"
# ensures we do not do a connectivity check, and the "--bare" makes sure
# we do not try to checkout the result (which needs objects), either of
# which would cause the clone to fail.
test_expect_success 'creating too deep nesting' '
	git clone -l -s C D &&
	git clone -l -s D E &&
	git clone -l -s E F &&
	git clone -l -s F G &&
	git clone --bare -l -s G H
'

test_expect_success 'validity of seventh repository' '
	git -C G fsck
'

test_expect_success 'invalidity of eighth repository' '
	test_must_fail git -C H fsck
'

test_expect_success 'breaking of loops' '
	echo "$(pwd)"/B/.git/objects >>A/.git/objects/info/alternates &&
	git -C C fsck
'

test_expect_success 'that info/alternates is necessary' '
	rm -f C/.git/objects/info/alternates &&
	test_must_fail git -C C fsck
'

test_expect_success 'that relative alternate is possible for current dir' '
	echo "../../../B/.git/objects" >C/.git/objects/info/alternates &&
	git fsck
'

test_expect_success 'that relative alternate is only possible for current dir' '
	test_must_fail git -C D fsck
'

test_done
