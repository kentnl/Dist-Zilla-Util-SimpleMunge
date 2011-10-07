use strict;
use warnings;

package Dist::Zilla::Util::SimpleMunge;

# ABSTRACT: Make munging File::FromCode and File::InMemory easier.

use Sub::Exporter -setup => { exports => [qw[ munge_file munge_files ]], };

=head1 SYNOPSIS

  use Dist::Zilla::Util::SimpleMunge qw( munge_file munge_files );
  ...;

  sub somesub {
    ...;
    munge_file $file_from_zilla, {
      via => sub {
        my ( $file, $content ) = @_;
        ... mangle $content here ...;
        return $mangled;
      },
    };
  }

=cut

=func munge_file

  # munge_file ( $FILE , \%CONFIGURATION )

  munge_file(
    $zilla_file,
    {
      via => sub { ... },
        lazy => $laziness
    }
  );

=head4 $FILE

A L<< C<::Role::File> |Dist::Zilla::Role::File >> object to munge.

=head4 %CONFIGURATION

  {
    via => $CODEREF,
    lazy => $LAZINESS,
  }

=head4 $CODEREF

Called to munge the file itself.

Passed a reference to the L<< C<::Role::File> |Dist::Zilla::Role::File >> instance, and a scalar containing
the contents of that file.

Return new content for the file via C<return>

  sub {
    my ( $file, $content ) = @_ ;
    ...;
    return $newcontent;
  }

=head4 $LAZINESS

Specify how lazy you want the munge to be performed. Normally, what this is set to is dependent on the type of file
being munged.

  $LAZINESS = undef ;  # use default for the file type
  $LAZINESS = 0     ;  # Munge immediately
  $LAZINESS = 1     ;  # Defer munging till as late as possible.

For things that are normally backed by scalar values, such as L<< C<::File::OnDisk> |Dist::Zilla::File::OnDisk >> and
L<< C<::File::InMemory> |Dist::Zilla::File::InMemory >>, the laziness is equivalent to C< $LAZINESS = 0 >, which is not lazy at all, and
munges the file content immediately.

For things backed by code, such as L<< C<::File::FromCode> |Dist::Zilla::File::FromCode >>, munging defaults to C< $LAZINESS = 1 >, where the
actual munging sub you specify is executed as late as possible.

You can specify the C< $LAZINESS > value explicitly if you want to customize the behaviour, i.e.: Make something that
is presently a scalar type get munged as late as possible ( converting the file into a C<FromCode> file ), or make
something currently backed by code get munged "now", ( converting the file into a C<InMemory> file )

=cut

sub _native_munge {

  # mostly todo at present to allow native class based overriding of munge behaviour
  # later.
  # this specific api is not fixed yet and prone to break
  my ( $file, $config ) = @_;
  ## no critic (ProhibitPunctuationVars)
  local $@ = undef;
  my $success = 0;
  eval { $success = $file->munge($config); 1 } or $success = 0;
  return $success if $success;
  return 0;
}

sub _fromcode_munge {
  my ( $file, $config ) = @_;
  if ( defined $config->{lazy} and $config->{lazy} == 0 ) {
    __PACKAGE__->_error(
      message => 'De-Lazifying a from-code file is not yet implemented',
      id      => 'code_munge_no_downgrade',
      tags    => [qw( downgrade fromcode toscalar nonlazy )],
    );
  }
  my $coderef = $file->code();
  $file->code(
    sub {
      return $config->{via}->( $file, $coderef->($file) );
    }
  );
  return 1;
}

sub _scalar_munge {
  my ( $file, $config ) = @_;
  if ( defined $config->{lazy} and $config->{lazy} == 1 ) {
    __PACKAGE__->_error(
      message => 'Forced upgrade from scalar to coderef not yet implemented',
      id      => 'scalar_munge_no_upgrade',
      tags    => [qw( upgrade scalar tocoderef lazy )],
    );
  }
  $file->content( $config->{via}->( $file, $file->content ) );
  return 1;
}

sub munge_file {
  my ( $file, $config ) = @_;
  if ( $file->can('munge') && ( my $success = _native_munge( $file, $config ) ) ) {
    return $success;
  }
  if ( $file->can('code') ) {
    return _fromcode_munge( $file, $config );
  }
  return _scalar_munge( $file, $config );
}

=func munge_files

This is mostly a convenience utility for munging a lot of files without having to hand-code the looping logic.

It basically just proxies for L</munge_file>.

  # munge_files ( \@FILEARRAY , \%CONFIGURATION )

  munge_files( [ $zilla_file_one, $zilla_file_two, ], {
    via => sub { ... },
    lazy => $laziness,
  });

=head4 @FILEARRAY

An C<ArrayRef> of L</$FILE>

=head4 See Also

=over 4

=item * L</%CONFIGURATION>

=item * L</$CODEREF>

=item * L</$FILE>

=item * L</$LAZINESS>

=back

=cut

sub munge_files {
  my ( $array, $config ) = @_;
  for my $file ( @{$array} ) {
    return unless munge_file( $file, $config );
  }
  return 1;
}

sub _error {
  my ( $self, %config ) = @_;
  require Carp;
  return Carp::carp( $config{message} );
}

1;
