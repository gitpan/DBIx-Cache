use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

print &notice;

WriteMakefile(
    'NAME'		=> 'DBIx::Cache',
    'VERSION_FROM'	=> 'Cache.pm', # finds $VERSION
    'PREREQ_PM'		=> 
	      {
		MLDBM::Sync => 0.15,
		MLDBM       => 2.00,
		Storable    => 1.0  
	      }, # e.g., Module::Name => 1.1
);


sub notice {

 '
Notes
-----

1 - it is assumed that you have created a database, and populated table as
described in the documentation supplied with this module. Scripts are here
for this for Postgresql.

2 - if you have not, make test will fail, and that would make both of us look
bad :-)

3 - if you want to run a test that differs from the supplied one, either in
database connect string or the sql query used, then:
  a - edit the connect string in test.pl
  a1 - edit DBIx::Cache->connect with proper uname and password
  a2 - edit DBI->connect with proper uname and password
  b - move select.sql to select.old and copy your long sql statement into
      the file select.sql

     you may have to fool around with adding and remove carriage returns 
     and whitespace as well as semicolons from this file to get it read in
     depending on your database driver

 c - thats it!

';
}
