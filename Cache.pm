package DBIx::Cache;

use DBI;
use Carp;

require 5.005_62;
use strict;
use warnings;

use Data::Dumper;
use Storable;

our $VERSION = sprintf("%s", q$Revision: 1.6 $ =~ /Revision:\s+([^\s]+)/);
our @ISA = qw(DBI);

__PACKAGE__->init_rootclass;


our $AUTOLOAD;

our $select;
our $execute;


use vars qw(%cache $dbm);


sub import {

  use MLDBM::Sync;
  use Fcntl;

  shift;

#  eval "use $_" for @_;

  my $eval = "use MLDBM qw(@_)" ;

#  warn "EVAL: $eval";

  eval $eval;


  $dbm = tie %cache, 'MLDBM::Sync', 'testmldbm', O_CREAT|O_RDWR, 0640 or die $!;
  $dbm->SyncKeysChecksum(1);

}

sub trim {  
  $_[0] =~ s/^\s+//;
  $_[0] =~ s/\s+$//;
  $_[0];
}

sub key_gen {
  my ($statement, $attr) = @_;
  my @attr_keys = ($attr) ? sort keys %$attr : ();
  my $key = ($attr) 
    ? join("~~", $statement, @attr_keys, @{$attr}{@attr_keys}) : $statement;
}

1;

package DBI::Cache::db;
use strict;

our @ISA = qw(DBI::db);

use Data::Dumper;

sub store_select {
    my ($SQL, $sth, @arg) = @_;

    if ($SQL =~ /^select/i) {
      $sth->{private_select_key} = DBI::Cache::key_gen(@arg);
      undef $sth->{private_execute_key};
    }
}

sub prepare {
    my ($self, @rest) = @_;

    my $sth = $self->SUPER::prepare(@rest);

    $sth->clear_private;

    store_select($rest[0], $sth, @rest);

    $sth;
}

sub prepare_cached {
  my($self,@rest) = @_;

  my $sth = $self->SUPER::prepare_cached(@rest);

  $sth->clear_private;

  store_select($rest[0], $sth, @rest);
  
  $sth;
}

1;

package DBIx::Cache::st;

our @ISA = qw(DBI::st);

use Data::Dumper;
use Storable;
use Carp qw(cluck);


#    my ($caller) = ((caller(1))[3] =~ /.*::(.*)/);

sub clear_private {
    return;
    my $sth = shift;
    for my $key (keys %$sth) {
	if ($key =~ /^private/) {
	    undef $sth->{$key};
	}
    }
}

sub dump { warn "STH_DUMP: ", Dumper(shift) }

sub execute {
    my ($sth, @arg) = @_;

    if ($sth->{private_select_key}) {
	my $key = DBI::Cache::key_gen(@arg);

	$sth->{private_execute_key} = $key ? $key : 'no execute args';
    }

    if (my $cached_data = $sth->cached) {
	$sth->{private_execute_results} = $cached_data;
    } else {
	$sth->SUPER::execute(@arg);
    }
    
}

sub cacheable { 
    my $sth = shift;
    
    my $bool_a = $sth->{private_select_key};
    my $bool_b = $sth->{private_execute_key};
#    warn "A: $bool_a B: $bool_b";
    return $bool_a and $bool_b;
}

sub fetch {
    my ($sth, @arg) = @_;

    my $row;
    
    if (defined($sth->{private_execute_results})) {
#	warn "retrieving row from cache...";
	$row = shift @{$sth->{private_execute_results}};
    } else {
	$row = $sth->SUPER::fetch(@arg);
#	warn "row retrieved: $row";
	if ($sth->cacheable and defined($row)) {
#	    warn "CACHEABLE";
	    push @{$sth->{private_cache}}, Storable::dclone $row;
	} 
    }
    $row;
}

sub fetchrow_arrayref { goto &fetch }

sub key {
    my $sth = shift;
    my $key = sprintf "%s + %s", 
    $sth->{private_select_key}, $sth->{private_execute_key};
#    warn "KEY<$key>";
    $key;
}

sub flush {
  my $sth = shift;

#  warn "private_cache", Dumper($sth->{private_cache});

  my $x = $sth->{private_cache};

  $DBIx::Cache::cache{$sth->key} = Storable::dclone($x);
}

sub cached {
    my $sth = shift;

#    warn "Checking for ", $sth->key;

#    warn "its keys ", Dumper(\%DBI::Cache::cache);

    $DBIx::Cache::cache{$sth->key};
}

sub retrieve { 
 
    my ($sth) = @_;
#    warn "retrieve seeks",  $sth->key;
    $DBIx::Cache::cache{$sth->key};

}


sub cache {

    my $sth = shift;

    unless (ref $sth->{private_cache} eq 'ARRAY' and
	    scalar @{$sth->{private_cache}}) {
	warn "no data to write to cache.. sth is ", Dumper($sth);
	return undef;
    }

    $sth->flush;
    $sth->clear_private;
}

sub rows {
    my $sth = shift;

    defined($sth->{private_execute_results}) 
	and return scalar @{$sth->{private_execute_results}};

    $sth->SUPER::rows;
}

sub select_error_msg {
  sprintf
    '
ERROR: select, selectall, etc are $dbh, not $sth methods. 
perldoc DBI for details

', $_[1];
}

sub selectall_arrayref { cluck select_error_msg }


1;


__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

DBIx::Cache - transparent SQL SELECT caching in DBI programs via MLDBM::Sync

=head1 SYNOPSIS

 use DBIx::Cache qw(MLDM::Sync::SDBM_File); # or however you want to use MLDBM
 use DBIx::Cache qw(DB_File Storable); # or however you want to use MLDBM

 my $connect = 'dbi:Pg:dbname=mydb';

 my $dbh = DBIx::Cache->connect($connect,'postgres');

 { 
 
     my $sth = $dbh->prepare('select * from weather LIMIT 10');

     $sth->execute;

     while (my $row = $sth->fetchrow_arrayref) {
	 ;
     } 

     $sth->cache;

  }

 # later queries of the same execute and select will retrieve cached results
 
 $dbh->disconnect;


=head1 DESCRIPTION

This module is available only for exploratory usage only. It was developed as 
something to discuss caching execute results for the dbi-dev@perl.org list.

As stated in the DBI docs, DBI usage is quite stereotyped:

         prepare,
           execute, fetch, fetch, ...
           execute, fetch, fetch, ...
           execute, fetch, fetch, ...

What C<DBIx::Cache> adds is this

         prepare,
           execute, fetch, fetch, ...  cache
           execute, fetch (from cache or db), fetch, ...  (cache if not cached)
           execute, fetch (from cache or db), fetch, ...  (cache if not cached)

Now, the only problem is that plain DBI outstrips my module in every case I 
could create where it shouldn't... 

It seems that pulling things off a Berkeley DB file is as slow as having the 
database formulate the query.
   
=head1 USAGE

The first step is to C<use DBIx::Cache ($cache_type)>. This will automatically
load in DBI and it will also load in MLDBM::Sync with the $cache_type that 
you specify. E.g:

  use DBIx::Cache qw(MLDM::Sync::SDBM_File);

the argument to the use is anything which MLDBM::Sync takes.

Next you just use DBI as normal and via various DBI::Cache 
$sth and $dbh subclasses, your prepared SQL selects and fetches are
automatically stored. Actual caching to store is done via an explicit
C<$sth->cache> statement.

=head1 TRYING IT OUT

There are two options, use the enclosed scripts to create a dummy table or 
drop in your sql statement and alter the connect strings.

=head2 using the enclosed scripts

=over 4

=item 1 create a database.

The file C<postgresql.sh> contains a Postgresql command to do this

=item 2 create a table

The file C<postgresql.sql> contains SQL to do this

=item 3 populate the table

The file C<i.pl> contains a Perl/DBI program to do this on a Postgresql 
database. It creates a whole bunch of dummy data for the table.

=head2 dropping in your own heavy SQL

in this case, follow the instructions in Makefile.PL. It's easy to do
this as well.  

=back




=head1 AUTHOR

T. M. Brannon, <tbone@cpan.org>

=head1 TO DO

Make it run faster than plain DBI so that it is of use. The only way I
might outdo DBI is if the database were overloaded or if the database
did not cache query results.

=head1 SEE ALSO

dbi-dev@perl.org

=cut
