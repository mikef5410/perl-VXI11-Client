use 5.014002;
use ExtUtils::MakeMaker;
use ExtUtils::PkgConfig;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'VXI11::Client',
    VERSION_FROM      => 'lib/VXI11/Client.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/VXI11/Client.pm', # retrieve abstract from module
       AUTHOR         => 'daniel <daniel@>') : ()),
    LIBS              => ['-lpthread -lrt ' . ExtUtils::PkgConfig->libs("gthread-2.0") . ' ' . ExtUtils::PkgConfig->libs("glib-2.0")], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.' . ExtUtils::PkgConfig->cflags_only_I("gthread-2.0") . ' ' . ExtUtils::PkgConfig->cflags_only_I("glib-2.0"), # e.g., '-I. -I/usr/include/other'
    OBJECT            => '$(O_FILES)', # link all the C files too
);
if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw());
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'VXI11::Client',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'IV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}
