# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'


######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use DBIx::Cache qw(MLDBM::Sync::SDBM_File);
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
use Data::Dumper;
use Carp qw(cluck);
use strict;


my $connect = 'dbi:Pg:dbname=mydb';



my $dbh = DBIx::Cache->connect($connect,'postgres');
my $pure_dbh = DBI->connect($connect,'postgres');

open  S, 'select.sql' or die 'could not open select.sql';
my $select = join '', <S>;
close(S);



sub t1_plain {
    my $sth = $pure_dbh->prepare($select);
    $sth->execute;
    my $count;    warn "rows returned, ", $sth->rows;
    while (my $row = $sth->fetchrow_arrayref) {
	last if ++$count > 10;
    }
}
sub t2_caching {
    my $sth = $dbh->prepare($select);
    $sth->execute;
    my $count;    warn "rows returned, ", $sth->rows;
    while (my $row = $sth->fetchrow_arrayref) {
	warn "cached row ", "@$row";
	last if ++$count > 10;
    }
    $sth->cache;
}
sub t3_cached {
    my $sth = $dbh->prepare($select);
    $sth->execute;
    my $count;    warn "rows returned, ", $sth->rows;
    while (my $row = $sth->fetchrow_arrayref) {
	last if ++$count > 10;
    }
}
sub select_fetch {
    my $dbh = shift;
    my $sth = $dbh->prepare($select);
    $sth->execute;
    my $count;
    while (my $row = $sth->fetchrow_arrayref) {
	last if ++$count > 10;
    }
}

use Benchmark qw(timethese cmpthese);

cmpthese timethese
  (1, 
   {
    t1_select_plain_dbi   => sub { select_fetch($pure_dbh) }, 
    t2_select_and_cache   => sub { select_fetch($dbh) }, 
    t3_use_cached_query   => sub { select_fetch($dbh) } 
   }
  );

=head1


=cut
