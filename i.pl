=head1

Randomly populate a 5-column table with dummy data

=cut
 

use DBI;
use strict;

sub letter {
('A'..'Z','a'..'z')[rand(52)]
}

sub city   {
  my $chars = 10 + int rand 20;
  my $city;

  $city .= letter for (1..$chars);

  $city;
}

sub temp {
  my $low = int rand 40;
  my $hi  = $low + int rand 40;
  ($low, $hi);
}

sub prcp { rand 1 }

sub date {
  my $year = 1994 + int rand 7;
  my $mon  = sprintf "%02d", 1 + int rand 12;
  my $day  = sprintf "%02d", 1 + int rand 31;
  "$year-$mon-$day";
}


my $connect = 'dbi:Pg:dbname=mydb';

my $dbh = DBI->connect($connect,'postgres');


my $insert = 
  'insert into weather(city,temp_lo,temp_hi,prcp,date) values(?,?,?,?,?)';
my $sth = $dbh->prepare($insert);

my $count;
my $records = 100000;
{
  my @insert = (city,temp,prcp,date);
  warn "@insert";
  $sth->execute(@insert);

  redo unless ++$count > $records;
}
  

